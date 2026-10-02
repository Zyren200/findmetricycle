const bookingModel = require("../models/booking.model");
const bookingService = require("../services/booking.service");
const fareModel = require("../models/fare.model");
const notificationModel = require("../models/notification.model");
const sosService = require("../services/sos.service");
const passengerAccountService = require("../services/passenger-account.service");
const { decorateBookingRecord } = require("../utils/ride-progress");
const { getIO } = require("../sockets");
const sanitizeUser = require("../utils/sanitize-user");

async function findRide(req, res, next) {
  try {
    const result = await bookingService.createBookingAndFindDriver({
      passengerId: req.user.id,
      pickupAddress: req.body.pickupAddress,
      pickupLat: req.body.pickupLat,
      pickupLng: req.body.pickupLng,
      dropoffAddress: req.body.dropoffAddress,
      dropoffLat: req.body.dropoffLat,
      dropoffLng: req.body.dropoffLng,
      passengerCount: req.body.passengerCount,
      autoAssign: req.body.autoAssign !== false,
    });

    if (result.matchedDriver) {
      getIO().to(`driver:${result.matchedDriver.id}`).emit("driver:booking_request", {
        booking: result.booking,
      });
    }

    res.status(201).json({
      success: true,
      message: result.message,
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

async function cancelRide(req, res, next) {
  try {
    const booking = await bookingService.cancelRide({
      bookingId: Number(req.params.bookingId),
      passengerId: req.user.id,
    });

    if (booking?.driver_id) {
      getIO().to(`driver:${booking.driver_id}`).emit("driver:booking_cancelled", {
        bookingId: booking.id,
      });
    }

    res.json({
      success: true,
      message: "Booking cancelled.",
      data: booking,
    });
  } catch (error) {
    next(error);
  }
}

async function rateRide(req, res, next) {
  try {
    const rating = await bookingService.rateCompletedRide({
      bookingId: Number(req.params.bookingId),
      passengerId: req.user.id,
      stars: Number(req.body.stars),
      feedback: req.body.feedback,
    });

    res.status(201).json({
      success: true,
      message: "Rating submitted.",
      data: rating,
    });
  } catch (error) {
    next(error);
  }
}

async function getBooking(req, res, next) {
  try {
    const booking = await bookingModel.findById(Number(req.params.bookingId));
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: "Booking not found.",
      });
    }

    if (booking && Number(booking.passenger_id) !== Number(req.user.id)) {
      return res.status(403).json({
        success: false,
        message: "You can only view your own bookings.",
      });
    }

    res.json({
      success: true,
      data: {
        ...decorateBookingRecord(booking),
        // Only ever sent to the booking's own passenger (checked above).
        pickupPin: await bookingModel.getPickupPinForPassenger(booking.id, req.user.id),
      },
    });
  } catch (error) {
    next(error);
  }
}

async function chooseDriver(req, res, next) {
  try {
    const { driverUserId, ...result } = await bookingService.passengerChooseDriver({
      bookingId: Number(req.params.bookingId),
      passengerId: req.user.id,
      driverId: Number(req.body.driverId),
    });

    // Also target the rider's user room: a socket only joins `driver:<id>`
    // if the account already had driver access when it connected.
    getIO()
      .to(`driver:${result.driver.id}`)
      .to(`user:${driverUserId}`)
      .emit("driver:booking_request", { booking: result.booking });

    res.json({
      success: true,
      message: "Request sent to the rider. Waiting for them to accept.",
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

async function getActiveBooking(req, res, next) {
  try {
    const data = await bookingService.getActiveBookingForPassenger(req.user.id);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getNearbyDrivers(req, res, next) {
  try {
    const result = await bookingService.listNearbyDriversForBooking({
      bookingId: Number(req.params.bookingId),
      passengerId: req.user.id,
    });
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
}

async function getBookingHistory(req, res, next) {
  try {
    // Clamp paging input — it goes straight into LIMIT/OFFSET.
    const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 20, 1), 100);
    const offset = Math.max(Number.parseInt(req.query.offset, 10) || 0, 0);
    const [rides, stats] = await Promise.all([
      bookingModel.listByPassenger(req.user.id, limit, offset),
      bookingModel.getPassengerRideStats(req.user.id),
    ]);
    res.json({
      success: true,
      data: rides,
      meta: { ...stats, limit, offset, hasMore: offset + rides.length < stats.total },
    });
  } catch (error) {
    next(error);
  }
}

async function getFare(req, res, next) {
  try {
    const fare = await fareModel.getCurrentFareSettings();
    res.json({
      success: true,
      data: fare,
    });
  } catch (error) {
    next(error);
  }
}

async function updateProfile(req, res, next) {
  try {
    const payload = {};
    if (Object.prototype.hasOwnProperty.call(req.body, "fullName")) payload.fullName = req.body.fullName;
    if (Object.prototype.hasOwnProperty.call(req.body, "phone")) payload.phone = req.body.phone;
    if (Object.prototype.hasOwnProperty.call(req.body, "email")) payload.email = req.body.email;
    if (Object.prototype.hasOwnProperty.call(req.body, "address")) payload.address = req.body.address;
    if (req.file) payload.profileImageUrl = `/uploads/profile-images/${req.file.filename}`;

    const updated = await passengerAccountService.updateProfile(req.user.id, payload);

    res.json({
      success: true,
      message: "Profile updated.",
      data: sanitizeUser(updated),
    });
  } catch (error) {
    next(error);
  }
}

async function deleteAccount(req, res, next) {
  try {
    await passengerAccountService.deleteAccount(req.user.id, req.body.password);
    // Close any live connection too — sockets only check the account when
    // they connect.
    try {
      getIO().in(`user:${req.user.id}`).disconnectSockets(true);
    } catch (_) {
      // Socket layer not initialized (tests/scripts).
    }
    res.json({ success: true, message: "Account deleted." });
  } catch (error) {
    next(error);
  }
}

async function triggerSos(req, res, next) {
  try {
    const alert = await sosService.createSosAlert({
      passengerId: req.user.id,
      bookingId: req.body.bookingId ? Number(req.body.bookingId) : null,
      lat: req.body.lat,
      lng: req.body.lng,
      message: req.body.message,
    });
    res.status(201).json({
      success: true,
      message: "SOS alert sent to admin.",
      data: alert,
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
      notificationModel.listForUser(req.user.id, { limit, offset, role: "passenger" }),
      notificationModel.countUnreadForUser(req.user.id, "passenger"),
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
    await notificationModel.markReadForUser(req.user.id, "passenger", ids);
    const unread = await notificationModel.countUnreadForUser(req.user.id, "passenger");
    res.json({ success: true, meta: { unread } });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  findRide,
  cancelRide,
  rateRide,
  getBooking,
  chooseDriver,
  getNearbyDrivers,
  getActiveBooking,
  getBookingHistory,
  getFare,
  getNotifications,
  markNotificationsRead,
  triggerSos,
  updateProfile,
  deleteAccount,
};
