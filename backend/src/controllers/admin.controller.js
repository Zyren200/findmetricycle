const adminService = require("../services/admin.service");
const { getIO } = require("../sockets");
const notificationService = require("../services/notification.service");

async function getPendingDrivers(req, res, next) {
  try {
    const { applications, counts } = await adminService.listPendingDrivers(String(req.query.status || "pending"));
    res.json({ success: true, data: applications, meta: { counts } });
  } catch (error) {
    next(error);
  }
}

async function postRequestCorrection(req, res, next) {
  try {
    const applicationId = Number(req.params.driverId);
    const outcome = await adminService.requestCorrection(applicationId, req.user.id, req.body.note);
    if (outcome.recipientUserId) {
      getIO().to(`user:${outcome.recipientUserId}`).emit("driver:approval_status", {
        status: "needs_correction",
        message: "Please update your documents and resubmit.",
        note: outcome.application?.correction_note || null,
      });
    }
    res.json({ success: true, message: "Correction requested.", data: outcome });
  } catch (error) {
    next(error);
  }
}

async function getDriverApplication(req, res, next) {
  try {
    const data = await adminService.getDriverApplication(Number(req.params.driverId));
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getDriverApplicationTimeline(req, res, next) {
  try {
    const data = await adminService.getDriverApplicationTimeline(Number(req.params.driverId));
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function approveDriver(req, res, next) {
  try {
    const outcome = await adminService.approveDriver(Number(req.params.driverId), req.user.id, {
      acknowledgeDocumentWarnings: req.body?.acknowledgeDocumentWarnings === true,
    });
    if (outcome.recipientUserId) {
      getIO().to(`user:${outcome.recipientUserId}`).emit("driver:approval_status", {
        status: "approved",
        message: "Your account is approved. You can now go online.",
      });
    }
    res.json({ success: true, message: "Driver approved.", data: outcome });
  } catch (error) {
    next(error);
  }
}

async function rejectDriver(req, res, next) {
  try {
    const outcome = await adminService.rejectDriver(Number(req.params.driverId), req.user.id, req.body.reason);
    if (outcome.recipientUserId) {
      getIO().to(`user:${outcome.recipientUserId}`).emit("driver:approval_status", {
        status: "rejected",
        message: "Your account was rejected.",
        reason: outcome.application?.rejection_reason || outcome.driver?.rejection_reason || null,
      });
    }
    res.json({ success: true, message: "Driver rejected.", data: outcome });
  } catch (error) {
    next(error);
  }
}

async function getFare(req, res, next) {
  try {
    const fare = await adminService.getFareSettings();
    res.json({ success: true, data: fare });
  } catch (error) {
    next(error);
  }
}

async function setFare(req, res, next) {
  try {
    const fare = await adminService.updateFareSettings(
      req.body.baseFare,
      req.body.perKmRate,
      req.body.minimumFare,
      req.body.nightFee,
      req.body.additionalPassengerFee,
      req.user.id
    );

    try {
      getIO().to("role:passenger").emit("passenger:fare_updated", fare);
    } catch (err) {
      // Socket.io not initialized (e.g. unit tests) — the save still succeeds.
    }

    res.json({ success: true, message: "Fare settings updated.", data: fare });
  } catch (error) {
    next(error);
  }
}

async function getLiveMap(req, res, next) {
  try {
    const data = await adminService.getLiveMapData();
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getDashboard(req, res, next) {
  try {
    const data = await adminService.getDashboardSummary();
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getRideActivity(req, res, next) {
  try {
    const days = req.query.days ? Number(req.query.days) : 7;
    const data = await adminService.getRideActivity(days);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getNotifications(req, res, next) {
  try {
    const [data, unread] = await Promise.all([
      notificationService.listNotifications({
        search: req.query.search,
        limit: Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 100, 1), 200),
        offset: Math.max(Number.parseInt(req.query.offset, 10) || 0, 0),
      }),
      notificationService.countUnreadForAdmin(),
    ]);
    res.json({ success: true, data, meta: { unread } });
  } catch (error) {
    next(error);
  }
}

async function postMarkNotificationRead(req, res, next) {
  try {
    const id = Number(req.params.id);
    const data = await notificationService.markRead(id);
    if (!data) {
      return res.status(404).json({ success: false, message: "Notification not found." });
    }
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function postMarkAllNotificationsRead(req, res, next) {
  try {
    await notificationService.markAllRead();
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
}

async function revokeDriverApproval(req, res, next) {
  try {
    const outcome = await adminService.revokeDriverApproval(
      Number(req.params.driverId),
      req.user.id,
      req.body?.note
    );
    if (outcome.recipientUserId) {
      const io = getIO();
      // Driver app drops out of driver mode and shows why.
      io.to(`user:${outcome.recipientUserId}`).emit("driver:approval_status", {
        status: "needs_correction",
        message: "Your driver approval was revoked. Please resubmit your documents.",
        note: outcome.reason,
      });
      io.to(`driver:${outcome.driver.id}`).emit("driver:status_changed", { status: "revoked" });
      // Sockets cache the user's driver access from when they connected;
      // make them reconnect (after the messages above are delivered) so
      // the revoked access takes effect there too.
      setTimeout(() => {
        io.in(`user:${outcome.recipientUserId}`).disconnectSockets(true);
      }, 1500).unref();
    }
    res.json({ success: true, message: "Driver approval revoked.", data: outcome });
  } catch (error) {
    next(error);
  }
}

async function getAllDrivers(req, res, next) {
  try {
    const drivers = await adminService.listAllDrivers();
    res.json({ success: true, data: drivers });
  } catch (error) {
    next(error);
  }
}

async function getAllPassengers(req, res, next) {
  try {
    const passengers = await adminService.listAllPassengers();
    res.json({ success: true, data: passengers });
  } catch (error) {
    next(error);
  }
}

async function postSuspendPassenger(req, res, next) {
  try {
    const passengerId = Number(req.params.passengerId);
    const passenger = await adminService.suspendPassenger(passengerId);
    // Close their live connection too — sockets only check the account
    // when they connect, and reconnecting now fails for a suspended user.
    getIO().in(`user:${passengerId}`).disconnectSockets(true);
    res.json({ success: true, message: "Passenger suspended.", data: passenger });
  } catch (error) {
    next(error);
  }
}

async function postReinstatePassenger(req, res, next) {
  try {
    const passengerId = Number(req.params.passengerId);
    const passenger = await adminService.reinstatePassenger(passengerId);
    res.json({ success: true, message: "Passenger reinstated.", data: passenger });
  } catch (error) {
    next(error);
  }
}

async function getRideHistory(req, res, next) {
  try {
    const limit = req.query.limit ? Number(req.query.limit) : 50;
    const rides = await adminService.getRideHistory(limit);
    res.json({ success: true, data: rides });
  } catch (error) {
    next(error);
  }
}

async function getPendingApprovals(req, res, next) {
  try {
    const pending = await adminService.getPendingApprovals();
    res.json({ success: true, data: pending });
  } catch (error) {
    next(error);
  }
}

async function postSuspendDriver(req, res, next) {
  try {
    const driverId = Number(req.params.driverId);
    const driver = await adminService.suspendDriver(driverId, req.user.id);
    getIO().to(`driver:${driver.id}`).emit("driver:status_changed", { status: "suspended" });
    res.json({ success: true, message: "Driver suspended.", data: driver });
  } catch (error) {
    next(error);
  }
}

async function postReinstateDriver(req, res, next) {
  try {
    const driverId = Number(req.params.driverId);
    const driver = await adminService.reinstateDriver(driverId, req.user.id);
    getIO().to(`driver:${driver.id}`).emit("driver:status_changed", { status: "active" });
    res.json({ success: true, message: "Driver reinstated.", data: driver });
  } catch (error) {
    next(error);
  }
}

async function getDriverLicenseExpirations(req, res, next) {
  try {
    const days = req.query.days ? Number(req.query.days) : 30;
    const data = await adminService.listDriversExpiringWithin(days);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getBookings(req, res, next) {
  try {
    const limit = req.query.limit ? Number(req.query.limit) : 100;
    const data = await adminService.listBookings(limit);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getBookingDetail(req, res, next) {
  try {
    const data = await adminService.getBookingDetail(Number(req.params.bookingId));
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getComplaints(req, res, next) {
  try {
    const data = await adminService.listComplaints();
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function resolveComplaint(req, res, next) {
  try {
    const data = await adminService.resolveComplaint(Number(req.params.id), req.user.id);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getSosAlerts(req, res, next) {
  try {
    const data = await adminService.listSosAlerts();
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function resolveSosAlert(req, res, next) {
  try {
    const data = await adminService.resolveSosAlert(Number(req.params.id), req.user.id);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getActivityLogs(req, res, next) {
  try {
    const limit = req.query.limit ? Number(req.query.limit) : 100;
    const offset = req.query.offset ? Number(req.query.offset) : 0;
    const data = await adminService.getActivityLogs(limit, offset);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function getBarangays(req, res, next) {
  try {
    const data = await adminService.listBarangays();
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function putBarangay(req, res, next) {
  try {
    const barangayId = Number(req.params.barangayId);
    const data = await adminService.updateBarangay(barangayId, req.body.is_enabled, req.user.id);
    res.json({ success: true, message: "Barangay updated.", data });
  } catch (error) {
    next(error);
  }
}

async function getSystemSettings(req, res, next) {
  try {
    const data = await adminService.getSystemSettings();
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

async function putSystemSettings(req, res, next) {
  try {
    const data = await adminService.updateSystemSettings(req.body, req.user.id);
    res.json({ success: true, message: "Settings updated.", data });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getPendingDrivers,
  getDriverApplication,
  getDriverApplicationTimeline,
  approveDriver,
  rejectDriver,
  postRequestCorrection,
  getFare,
  setFare,
  getLiveMap,
  getDashboard,
  getRideActivity,
  getNotifications,
  postMarkNotificationRead,
  postMarkAllNotificationsRead,
  getAllDrivers,
  revokeDriverApproval,
  postSuspendDriver,
  postReinstateDriver,
  getDriverLicenseExpirations,
  getAllPassengers,
  postSuspendPassenger,
  postReinstatePassenger,
  getRideHistory,
  getPendingApprovals,
  getBookings,
  getBookingDetail,
  getComplaints,
  getSosAlerts,
  resolveComplaint,
  resolveSosAlert,
  getActivityLogs,
  getBarangays,
  putBarangay,
  getSystemSettings,
  putSystemSettings,
};
