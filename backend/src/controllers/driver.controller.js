const bookingService = require("../services/booking.service");
const driverService = require("../services/driver.service");
const notificationModel = require("../models/notification.model");
const sosService = require("../services/sos.service");
const complaintService = require("../services/complaint.service");
const { decorateBookingRecord } = require("../utils/ride-progress");
const { getIO } = require("../sockets");

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

      getIO().to("role:admin").emit("admin:driver_location", {
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
      .emit("passenger:booking_update", {
        booking: result.booking,
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

    getIO()
      .to(`passenger:${booking.passenger_id}`)
      .emit("passenger:driver_arrived", {
        bookingId: booking.id,
        booking,
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

async function startRide(req, res, next) {
  try {
    const driver = await driverService.getDriverByUserIdOrFail(req.user.id);
    const booking = await bookingService.startRide({
      bookingId: Number(req.params.bookingId),
      driverId: driver.id,
      pin: req.body.pin,
    });

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

async function getNotifications(req, res, next) {
  try {
    const limit = req.query.limit ? Number(req.query.limit) : 50;
    const offset = req.query.offset ? Number(req.query.offset) : 0;
    const notifications = await notificationModel.listForUser(req.user.id, {
      limit,
      offset,
      role: "driver",
    });
    res.json({
      success: true,
      data: notifications,
    });
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
  setOnlineStatus,
  updateLocation,
  respondBooking,
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
  getPerformance,
  triggerSos,
  reportIssue,
};
