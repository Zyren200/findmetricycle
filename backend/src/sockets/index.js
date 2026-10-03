const { Server } = require("socket.io");
const jwt = require("jsonwebtoken");
const env = require("../config/env");
const roles = require("../constants/roles");
const bookingService = require("../services/booking.service");
const driverService = require("../services/driver.service");
const userModel = require("../models/user.model");
const { decorateBookingRecord } = require("../utils/ride-progress");
const { hasDriverAccess } = require("../utils/driver-access");
const { isRateLimited } = require("../utils/socket-rate-limiter");
const ApiError = require("../utils/api-error");
const { isAllowedOrigin } = require("../utils/cors-origin");
const { PERMISSIONS, permissionRoom } = require("../constants/admin-permissions");
const { loadAdminContext } = require("../services/admin-access.service");

let io = null;

function safeAck(ack, payload) {
  if (typeof ack === "function") {
    ack(payload);
  }
}

async function socketAuthMiddleware(socket, next) {
  try {
    const authToken = socket.handshake.auth?.token;
    const headerToken = socket.handshake.headers.authorization?.replace("Bearer ", "");
    const token = authToken || headerToken;

    if (!token) {
      return next(new Error("Socket authentication token is required."));
    }

    const payload = jwt.verify(token, env.jwt.secret);
    if (payload.type && payload.type !== "access") {
      return next(new Error("Invalid token type."));
    }

    const user = await userModel.findById(payload.userId);
    if (!user) {
      return next(new Error("Invalid socket user."));
    }

    if (user.status !== "active") {
      return next(new Error("Inactive account."));
    }

    // Admins: their own account status and permissions, read fresh — a
    // disabled admin can't connect, and the rooms joined below decide which
    // admin events reach them.
    let admin = null;
    if (user.role === roles.ADMIN) {
      admin = await loadAdminContext(user.id);
      if (!admin || admin.status !== "active") {
        return next(new Error("Inactive account."));
      }
    }

    socket.user = {
      id: user.id,
      role: user.role,
      fullName: user.full_name,
      isDriverAccount: Boolean(user.is_driver_account),
      driverApprovalStatus: user.driver_approval_status || "none",
      adminPermissions: admin ? admin.permissions : [],
    };
    return next();
  } catch (error) {
    return next(new Error("Unauthorized socket connection."));
  }
}

async function onSocketConnection(socket) {
  const user = socket.user;
  socket.join(`user:${user.id}`);
  socket.join(`role:${user.role}`);
  for (const permission of user.adminPermissions) {
    socket.join(permissionRoom(permission));
  }

  if (user.role === roles.PASSENGER) {
    socket.join(`passenger:${user.id}`);
  }

  if (hasDriverAccess(user)) {
    const driver = await driverService.getDriverByUserIdOrFail(user.id).catch(() => null);
    if (driver) {
      socket.join(`driver:${driver.id}`);
    }
  }

  socket.on("driver:set_online", async (payload, ack) => {
    try {
      if (!hasDriverAccess(user)) {
        throw new ApiError(403, "Only drivers can set online status.");
      }

      const driver = await driverService.updateOnlineStatus(user.id, payload?.isOnline);
      safeAck(ack, { success: true, data: driver });
    } catch (error) {
      safeAck(ack, { success: false, message: error.message });
    }
  });

  socket.on("driver:location_update", async (payload, ack) => {
    try {
      if (!hasDriverAccess(user)) {
        throw new ApiError(403, "Only drivers can update location.");
      }
      if (isRateLimited(`driver:location_update:${user.id}`, { windowMs: 1000, max: 2 })) {
        throw new ApiError(429, "Location updates are being sent too frequently.");
      }

      const driver = await driverService.updateLocation(user.id, payload?.lat, payload?.lng);
      const activeBooking = await driverService.getActiveBooking(user.id);
      const activeBookingView = activeBooking
        ? decorateBookingRecord({
            ...activeBooking,
            current_lat: driver.current_lat,
            current_lng: driver.current_lng,
          })
        : null;

      // Skip the broadcast (not the DB write) when the driver barely
      // moved — avoids flooding passengers/admin with noise while stopped.
      if (driver.movedSignificantly) {
        if (activeBooking) {
          io.to(`passenger:${activeBooking.passenger_id}`).emit("passenger:driver_location", {
            bookingId: activeBooking.id,
            driverId: driver.id,
            lat: Number(driver.current_lat),
            lng: Number(driver.current_lng),
            updatedAt: driver.last_location_update,
            rideState: activeBookingView?.rideState || null,
            rideStateLabel: activeBookingView?.rideStateLabel || null,
            rideProgress: activeBookingView?.rideProgress || null,
          });
        }

        io.to(permissionRoom(PERMISSIONS.LIVE_MAP_VIEW)).emit("admin:driver_location", {
          driverId: driver.id,
          lat: Number(driver.current_lat),
          lng: Number(driver.current_lng),
          updatedAt: driver.last_location_update,
          bookingId: activeBookingView?.id || null,
          rideState: activeBookingView?.rideState || null,
          rideStateLabel: activeBookingView?.rideStateLabel || null,
          rideProgress: activeBookingView?.rideProgress || null,
        });

        if (driver.is_online) {
          io.to("role:passenger").emit("passenger:driver_ping", {
            driverId: driver.id,
            fullName: driver.full_name,
            tricycleNumber: driver.tricycle_number,
            rating: Number(driver.rating_avg || 0),
            lat: Number(driver.current_lat),
            lng: Number(driver.current_lng),
            updatedAt: driver.last_location_update,
          });
        }
      }

      safeAck(ack, { success: true, data: driver });
    } catch (error) {
      safeAck(ack, { success: false, message: error.message });
    }
  });

  socket.on("passenger:find_ride", async (payload, ack) => {
    try {
      if (user.role !== roles.PASSENGER) {
        throw new ApiError(403, "Only passengers can create bookings.");
      }
      if (isRateLimited(`passenger:find_ride:${user.id}`, { windowMs: 60000, max: 10 })) {
        throw new ApiError(429, "Too many booking attempts. Please wait a moment.");
      }

      const result = await bookingService.createBookingAndFindDriver({
        passengerId: user.id,
        pickupAddress: payload?.pickupAddress,
        pickupLat: payload?.pickupLat,
        pickupLng: payload?.pickupLng,
        dropoffAddress: payload?.dropoffAddress,
        dropoffLat: payload?.dropoffLat,
        dropoffLng: payload?.dropoffLng,
      });

      if (result.matchedDriver) {
        io.to(`driver:${result.matchedDriver.id}`).emit("driver:booking_request", {
          booking: result.booking,
        });
      }

      safeAck(ack, { success: true, data: result });
    } catch (error) {
      safeAck(ack, { success: false, message: error.message });
    }
  });

  socket.on("driver:booking_response", async (payload, ack) => {
    try {
      if (!hasDriverAccess(user)) {
        throw new ApiError(403, "Only drivers can respond to bookings.");
      }

      const driver = await driverService.getDriverByUserIdOrFail(user.id);
      const result = await bookingService.driverRespond({
        bookingId: Number(payload?.bookingId),
        driverId: driver.id,
        action: payload?.action,
        reason: payload?.reason,
      });

      io.to(`passenger:${result.booking.passenger_id}`)
        .to(`user:${result.booking.passenger_id}`)
        .emit("passenger:booking_update", {
          booking: result.booking,
          nearbyDrivers: result.nearbyDrivers || [],
          reason: result.reason || null,
        });

      if (result.reassignedDriver) {
        io.to(`driver:${result.reassignedDriver.id}`).emit("driver:booking_request", {
          booking: result.booking,
        });
      }

      safeAck(ack, { success: true, data: result });
    } catch (error) {
      safeAck(ack, { success: false, message: error.message });
    }
  });
}

function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: {
      origin: (origin, callback) => {
        if (isAllowedOrigin(origin)) {
          callback(null, true);
          return;
        }
        callback(new Error("Socket origin not allowed."));
      },
      credentials: true,
    },
  });

  io.use(socketAuthMiddleware);
  io.on("connection", onSocketConnection);
  return io;
}

function getIO() {
  if (!io) {
    throw new Error("Socket.io is not initialized.");
  }
  return io;
}

module.exports = {
  initSocket,
  getIO,
  // Exported for tests.
  socketAuthMiddleware,
  onSocketConnection,
};
