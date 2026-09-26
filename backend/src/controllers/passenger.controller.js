const bookingModel = require("../models/booking.model");
const bookingService = require("../services/booking.service");
const fareModel = require("../models/fare.model");
const notificationModel = require("../models/notification.model");
const sosService = require("../services/sos.service");
const userModel = require("../models/user.model");
const { decorateBookingRecord } = require("../utils/ride-progress");
const { getIO } = require("../sockets");
const ApiError = require("../utils/api-error");
const bcrypt = require("bcryptjs");
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
      data: decorateBookingRecord(booking),
    });
  } catch (error) {
    next(error);
  }
}

async function chooseDriver(req, res, next) {
  try {
    const result = await bookingService.passengerChooseDriver({
      bookingId: Number(req.params.bookingId),
      passengerId: req.user.id,
      driverId: Number(req.body.driverId),
    });

    getIO().to(`driver:${result.driver.id}`).emit("driver:booking_request", {
      booking: result.booking,
    });

    res.json({
      success: true,
      message: "Driver selected.",
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

async function getBookingHistory(req, res, next) {
  try {
    const limit = req.query.limit ? Number(req.query.limit) : 50;
    const rides = await bookingModel.listByPassenger(req.user.id, limit);
    res.json({
      success: true,
      data: rides,
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

    const updated = await userModel.updateProfile(req.user.id, payload);

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
    const user = await userModel.findById(req.user.id);
    if (!user) {
      throw new ApiError(404, "Account not found.");
    }

    const valid = await bcrypt.compare(req.body.password, user.password_hash);
    if (!valid) {
      throw new ApiError(400, "Password is incorrect.");
    }

    await userModel.archiveUser(req.user.id);
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
    const limit = req.query.limit ? Number(req.query.limit) : 50;
    const offset = req.query.offset ? Number(req.query.offset) : 0;
    const notifications = await notificationModel.listForUser(req.user.id, { limit, offset });
    res.json({
      success: true,
      data: notifications,
    });
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
  getBookingHistory,
  getFare,
  getNotifications,
  triggerSos,
  updateProfile,
  deleteAccount,
};
