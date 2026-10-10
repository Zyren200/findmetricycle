const bookingService = require("../services/booking.service");
const driverService = require("../services/driver.service");
const bookingModel = require("../models/booking.model");
const bookingRouteModel = require("../models/booking-route.model");
const bookingRouteService = require("../services/booking-route.service");
const notificationModel = require("../models/notification.model");
const sosService = require("../services/sos.service");
const complaintService = require("../services/complaint.service");
const { decorateBookingRecord } = require("../utils/ride-progress");
const { getIO } = require("../sockets");
const { PERMISSIONS, permissionRoom } = require("../constants/admin-permissions");

async function recordRoutePointSafely(bookingId, driver) {
  const lat = Number(driver.current_lat);
  const lng = Number(driver.current_lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
  try {
    await bookingRouteService.recordPoint({ bookingId, lat, lng });
  } catch (error) {
    // Route history is supplementary: never make a valid ride transition
    // look unsuccessful because one GPS-point write failed.
    console.warn("Could not record booking route point:", error.message);
  }
}

async function setOnlineStatus(req, res, next) {
  try {
    const driver = await driverService.updateOnlineStatus(req.user.id, req.body.isOnline);
    res.json({
      success: true,
      message: "Driver online status updated.",
      data: driver,
    });
  } catch (error) {
    next(error);
  }
}

async function updateLocation(req, res, next) {
  try {
    const driver = await driverService.updateLocation(
      req.user.id,
      Number(req.body.lat),
      Number(req.body.lng)
    );

    const activeBooking = await driverService.getActiveBooking(req.user.id);
    const activeBookingView = activeBooking
      ? decorateBookingRecord({
          ...activeBooking,
          current_lat: driver.current_lat,
          current_lng: driver.current_lng,
        })
      : null;

    // Skip the broadcast (not the DB write) when the driver barely moved —
    // avoids flooding passengers/admin with noise while stopped.
    if (driver.movedSignificantly) {
      if (activeBooking) {
        getIO().to(`passenger:${activeBooking.passenger_id}`).emit("passenger:driver_location", {
          bookingId: activeBooking.id,
          driverId: driver.id,
          lat: Number(driver.current_lat),
          lng: Number(driver.current_lng),
          rideState: activeBookingView?.rideState || null,
          rideStateLabel: activeBookingView?.rideStateLabel || null,
          rideProgress: activeBookingView?.rideProgress || null,
        });
      }

      getIO().to(permissionRoom(PERMISSIONS.LIVE_MAP_VIEW)).emit("admin:driver_location", {
        driverId: driver.id,
        lat: Number(driver.current_lat),
        lng: Number(driver.current_lng),
        updatedAt: driver.last_location_update,
        bookingId: activeBookingView?.id || null,
        rideState: activeBookingView?.rideState || null,
        rideStateLabel: activeBookingView?.rideStateLabel || null,
        rideProgress: activeBookingView?.rideProgress || null,
      });
    }

    res.json({
      success: true,
      message: "Driver location updated.",
      data: driver,
    });
  } catch (error) {
    next(error);
  }
}

// Polled by the driver app while online, so a ride request still shows up
// even if the realtime "driver:booking_request" event was missed.
async function getIncomingBooking(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const booking = await bookingService.getIncomingOfferForDriver(driver.id);
    res.json({ success: true, data: booking });
  } catch (error) {
    next(error);
  }
}

// The ride the driver is on, so a restarted app can reopen it (null when
// there isn't one — e.g. it was closed while the phone was off).
async function getActiveBooking(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const booking = await bookingService.getActiveRideForDriver(driver.id);
    res.json({ success: true, data: booking });
  } catch (error) {
    next(error);
  }
}

async function getBookingRoute(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const booking = await bookingModel.findById(Number(req.params.bookingId));
    if (!booking) {
      return res.status(404).json({ success: false, message: "Booking not found." });
    }
    if (Number(booking.driver_id) !== Number(driver.id)) {
      return res.status(403).json({ success: false, message: "You can only view your own booking route." });
    }

    const points = await bookingRouteModel.listForBooking(booking.id);
    res.json({ success: true, data: { bookingId: booking.id, points } });
  } catch (error) {
    next(error);
  }
}

async function respondBooking(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);

    const result = await bookingService.driverRespond({
      bookingId: Number(req.params.bookingId),
      driverId: driver.id,
      action: req.body.action,
      reason: req.body.reason,
    });

    getIO()
      .to(`passenger:${result.booking.passenger_id}`)
      .to(`user:${result.booking.passenger_id}`)
      .emit("passenger:booking_update", {
        booking: result.booking,
        // On a decline the passenger gets a fresh list to choose again.
        nearbyDrivers: result.nearbyDrivers || [],
        reason: result.reason || null,
      });

    if (result.reassignedDriver) {
      getIO().to(`driver:${result.reassignedDriver.id}`).emit("driver:booking_request", {
        booking: result.booking,
      });
    }

    res.json({
      success: true,
      message: "Booking response saved.",
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

async function arriveAtPickup(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const booking = await bookingService.arriveAtPickup({
      bookingId: Number(req.params.bookingId),
      driverId: driver.id,
    });

    // The rider is about to ask for the PIN — resend it to the passenger
    // (their rooms only) in case their app lost it.
    const pickupPin = await bookingModel.getPickupPinForPassenger(booking.id, booking.passenger_id);
    getIO()
      .to(`passenger:${booking.passenger_id}`)
      .to(`user:${booking.passenger_id}`)
      .emit("passenger:driver_arrived", {
        bookingId: booking.id,
        booking,
        pickupPin,
        rideState: booking.rideState,
        rideStateLabel: booking.rideStateLabel,
        rideProgress: booking.rideProgress,
      });

    res.json({
      success: true,
      message: "Marked as arrived.",
      data: booking,
    });
  } catch (error) {
    next(error);
  }
}

async function markNoShow(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const booking = await bookingService.markNoShow({
      bookingId: Number(req.params.bookingId),
      driverId: driver.id,
      note: req.body.note,
    });

    getIO().to(`passenger:${booking.passenger_id}`).emit("passenger:booking_update", {
      booking,
    });

    res.json({
      success: true,
      message: "Marked as no-show.",
      data: booking,
    });
  } catch (error) {
    next(error);
  }
}

// Driver backs out before the trip starts; the passenger is handed a fresh
// rider list to choose from (same event as a decline).
async function cancelRide(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const result = await bookingService.driverCancelRide({
      bookingId: Number(req.params.bookingId),
      driverId: driver.id,
      reason: req.body.reason,
    });

    getIO()
      .to(`passenger:${result.booking.passenger_id}`)
      .to(`user:${result.booking.passenger_id}`)
      .emit("passenger:booking_update", {
        booking: result.booking,
        nearbyDrivers: result.nearbyDrivers,
        reason: result.reason,
      });

    res.json({
      success: true,
      message: "Ride cancelled. The passenger will choose another rider.",
      data: result.booking,
    });
  } catch (error) {
    next(error);
  }
}

async function startRide(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const booking = await bookingService.startRide({
      bookingId: Number(req.params.bookingId),
      driverId: driver.id,
      pin: req.body.pin,
    });

    // Preserve the first known trip coordinate even if the next background
    // GPS heartbeat arrives after the passenger's ride has already started.
    await recordRoutePointSafely(booking.id, driver);

    getIO()
      .to(`passenger:${booking.passenger_id}`)
      .emit("passenger:ride_started", {
        bookingId: booking.id,
        booking,
        rideState: booking.rideState,
        rideStateLabel: booking.rideStateLabel,
        rideProgress: booking.rideProgress,
      });

    res.json({
      success: true,
      message: "Ride started.",
      data: booking,
    });
  } catch (error) {
    next(error);
  }
}

async function completeRide(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const booking = await bookingService.completeRide({
      bookingId: Number(req.params.bookingId),
      driverId: driver.id,
      actualDistanceKm: req.body.actualDistanceKm,
    });

    // `completeRide` changes the status out of ongoing, so save the last
    // known coordinate explicitly before later location updates stop being
    // recorded for this booking.
    await recordRoutePointSafely(booking.id, driver);

    getIO()
      .to(`passenger:${booking.passenger_id}`)
      .emit("passenger:ride_completed", {
        bookingId: booking.id,
        finalFare: booking.final_fare,
        booking,
        rideState: booking.rideState,
        rideStateLabel: booking.rideStateLabel,
        rideProgress: booking.rideProgress,
      });

    res.json({
      success: true,
      message: "Ride completed.",
      data: booking,
    });
  } catch (error) {
    next(error);
  }
}

async function getEarnings(req, res, next) {
  try {
    const summary = await driverService.getDriverEarnings(req.user.id);
    res.json({
      success: true,
      data: summary,
    });
  } catch (error) {
    next(error);
  }
}

async function getPerformance(req, res, next) {
  try {
    const stats = await driverService.getDriverPerformance(req.user.id);
    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    next(error);
  }
}

async function getProfile(req, res, next) {
  try {
    const profile = await driverService.getDriverProfile(req.user.id);
    res.json({
      success: true,
      data: profile,
    });
  } catch (error) {
    next(error);
  }
}

async function updateProfile(req, res, next) {
  try {
    const profileImageUrl = req.file
      ? `/uploads/profile-images/${req.file.filename}`
      : undefined;

    const profile = await driverService.updateDriverProfile(req.user.id, {
      fullName: req.body.fullName,
      phone: req.body.phone,
      email: Object.prototype.hasOwnProperty.call(req.body, "email") ? req.body.email : undefined,
      tricycleNumber: req.body.tricycleNumber,
      profileImageUrl,
    });

    res.json({
      success: true,
      message: "Driver profile updated.",
      data: profile,
    });
  } catch (error) {
    next(error);
  }
}

async function getRatings(req, res, next) {
  try {
    const ratings = await driverService.getDriverRatings(req.user.id);
    res.json({
      success: true,
      data: ratings,
    });
  } catch (error) {
    next(error);
  }
}

async function getCompletedHistory(req, res, next) {
  try {
    const rides = await driverService.getCompletedHistory(req.user.id);
    res.json({
      success: true,
      data: rides,
    });
  } catch (error) {
    next(error);
  }
}

async function getRideHistory(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    // Clamp paging input — it goes straight into LIMIT/OFFSET.
    const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 20, 1), 100);
    const offset = Math.max(Number.parseInt(req.query.offset, 10) || 0, 0);
    const status = ["completed", "cancelled"].includes(req.query.status) ? req.query.status : null;

    const [rides, stats] = await Promise.all([
      bookingModel.listHistoryByDriver(driver.id, { limit, offset, status }),
      bookingModel.getDriverRideStats(driver.id),
    ]);
    const total = status === "completed" ? stats.completed
      : status === "cancelled" ? stats.cancelled
      : stats.completed + stats.cancelled;
    res.json({
      success: true,
      data: rides,
      meta: { ...stats, limit, offset, hasMore: offset + rides.length < total },
    });
  } catch (error) {
    next(error);
  }
}

async function getNotifications(req, res, next) {
  try {
    const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 50, 1), 100);
    const offset = Math.max(Number.parseInt(req.query.offset, 10) || 0, 0);
    const [notifications, unread] = await Promise.all([
      notificationModel.listForUser(req.user.id, { limit, offset, role: "driver" }),
      notificationModel.countUnreadForUser(req.user.id, "driver"),
    ]);
    res.json({
      success: true,
      data: notifications.map(({ metadata_json: metadata, ...row }) => ({
        ...row,
        metadata: metadata ? JSON.parse(metadata) : null,
      })),
      meta: { unread },
    });
  } catch (error) {
    next(error);
  }
}

// Marks the given notifications (or all when no ids) as read — only the
// caller's own.
async function markNotificationsRead(req, res, next) {
  try {
    const ids = Array.isArray(req.body?.ids)
      ? req.body.ids.map(Number).filter((id) => Number.isInteger(id) && id > 0).slice(0, 200)
      : null;
    await notificationModel.markReadForUser(req.user.id, "driver", ids);
    const unread = await notificationModel.countUnreadForUser(req.user.id, "driver");
    res.json({ success: true, meta: { unread } });
  } catch (error) {
    next(error);
  }
}

async function triggerSos(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const alert = await sosService.createDriverSosAlert({
      driverId: driver.id,
      bookingId: req.body.bookingId,
      lat: req.body.lat,
      lng: req.body.lng,
      message: req.body.message,
    });
    res.status(201).json({
      success: true,
      message: "SOS alert sent. Admin has been notified.",
      data: alert,
    });
  } catch (error) {
    next(error);
  }
}

async function reportIssue(req, res, next) {
  try {
    const complaint = await complaintService.createComplaint({
      reporterId: req.user.id,
      bookingId: req.body.bookingId,
      category: req.body.category,
      description: req.body.description,
    });
    res.status(201).json({
      success: true,
      message: "Report submitted. Admin will review it.",
      data: complaint,
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  cancelRide,
  setOnlineStatus,
  updateLocation,
  respondBooking,
  getIncomingBooking,
  getActiveBooking,
  getBookingRoute,
  getRideHistory,
  arriveAtPickup,
  startRide,
  markNoShow,
  completeRide,
  getEarnings,
  getProfile,
  updateProfile,
  getRatings,
  getCompletedHistory,
  getNotifications,
  markNotificationsRead,
  getPerformance,
  triggerSos,
  reportIssue,
};
