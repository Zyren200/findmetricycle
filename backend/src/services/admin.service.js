const bookingModel = require("../models/booking.model");
const driverModel = require("../models/driver.model");
const driverApplicationModel = require("../models/driver-application.model");
const userModel = require("../models/user.model");
const fareModel = require("../models/fare.model");
const complaintModel = require("../models/complaint.model");
const notificationService = require("./notification.service");
const sosService = require("./sos.service");
const mailService = require("./mail.service");
const statusHistoryModel = require("../models/application-status-history.model");
const db = require("../config/db");
const ApiError = require("../utils/api-error");

async function listPendingDrivers() {
  return driverApplicationModel.listPendingApplications();
}

// NOTE: the "driverId" the Admin Dashboard sends here is actually the
// driver_applications.id (see listPendingApplications, which returns
// application rows). Applications submitted through the v2 apply-driver
// flow have driver_id = NULL — no `drivers` row exists until the admin
// approves. Keying these functions by applicationId (not driverId) is
// what makes approve/reject/request-correction actually work for them.
async function approveDriver(applicationId, adminUserId) {
  const outcome = await db.withTransaction(async (client) => {
    const application = await driverApplicationModel.findById(applicationId, client);
    if (!application) {
      throw new ApiError(404, "Driver application not found.");
    }
    if (application.status !== "pending") {
      throw new ApiError(400, `Application is already ${application.status}.`);
    }

    let driver = application.driver_id ? await driverModel.findById(application.driver_id, client) : null;

    if (!driver) {
      driver = await driverModel.createDriverProfile(
        {
          userId: application.user_id,
          tricycleNumber: application.plate_number,
          licenseImageUrl: application.license_image_url,
          businessPermitImageUrl: application.business_permit_image_url,
          licenseExpiresAt: application.license_expires_at,
          licenseNumber: application.license_number,
          licenseHolderName: application.license_holder_name,
        },
        client
      );
      await client.query("UPDATE driver_applications SET driver_id = ? WHERE id = ?", [driver.id, application.id]);
    }

    const updatedDriver = await driverModel.approveDriver(driver.id, adminUserId, client);
    const updatedApplication = await driverApplicationModel.markApproved(application.id, adminUserId, client);

    await client.query(
      "UPDATE users SET driver_approval_status = 'approved', is_driver_account = 1 WHERE id = ?",
      [application.user_id]
    );

    await statusHistoryModel.logStatus(application.id, "approved", null, adminUserId, client);

    return {
      driver: updatedDriver,
      application: updatedApplication,
      recipientUserId: application.user_id,
    };
  });

  if (outcome?.recipientUserId) {
    await notificationService.createNotification({
      type: "driver_approval",
      title: "Driver application approved",
      body: "Your driver application was approved. You can now go online.",
      userId: outcome.recipientUserId,
      recipientRole: "driver",
      sentBy: adminUserId,
      metadataJson: { applicationId, driverId: outcome.driver?.id || null, status: "approved" },
    });

    if (outcome.application?.email) {
      mailService
        .sendDriverApprovalEmail(outcome.application.email, outcome.application.full_name)
        .catch(() => {});
    }
  }

  return outcome;
}

async function rejectDriver(applicationId, adminUserId, reason) {
  const outcome = await db.withTransaction(async (client) => {
    const application = await driverApplicationModel.findById(applicationId, client);
    if (!application) {
      throw new ApiError(404, "Driver application not found.");
    }
    if (application.status !== "pending") {
      throw new ApiError(400, `Application is already ${application.status}.`);
    }

    const updatedDriver = application.driver_id
      ? await driverModel.rejectDriver(application.driver_id, adminUserId, reason, client)
      : null;
    const updatedApplication = await driverApplicationModel.markRejected(application.id, adminUserId, reason, client);

    await client.query("UPDATE users SET driver_approval_status = 'rejected' WHERE id = ?", [application.user_id]);

    await statusHistoryModel.logStatus(application.id, "rejected", reason || null, adminUserId, client);

    return {
      driver: updatedDriver,
      application: updatedApplication,
      recipientUserId: application.user_id,
    };
  });

  if (outcome?.recipientUserId) {
    await notificationService.createNotification({
      type: "driver_rejection",
      title: "Driver application rejected",
      body: reason ? `Your driver application was rejected: ${reason}` : "Your driver application was rejected.",
      userId: outcome.recipientUserId,
      recipientRole: "driver",
      sentBy: adminUserId,
      metadataJson: { applicationId, driverId: outcome.driver?.id || null, status: "rejected", reason: reason || null },
    });

    if (outcome.application?.email) {
      mailService
        .sendDriverRejectionEmail(outcome.application.email, outcome.application.full_name, reason)
        .catch(() => {});
    }
  }

  return outcome;
}

async function requestCorrection(applicationId, adminUserId, note) {
  const outcome = await db.withTransaction(async (client) => {
    const application = await driverApplicationModel.findById(applicationId, client);
    if (!application) {
      throw new ApiError(404, "Driver application not found.");
    }
    if (application.status !== "pending") {
      throw new ApiError(400, `Application is already ${application.status}.`);
    }

    const updatedApplication = await driverApplicationModel.markNeedsCorrection(application.id, adminUserId, note, client);

    await statusHistoryModel.logStatus(application.id, "needs_correction", note || null, adminUserId, client);

    return {
      application: updatedApplication,
      recipientUserId: application.user_id,
    };
  });

  if (outcome?.recipientUserId) {
    await notificationService.createNotification({
      type: "driver_correction_requested",
      title: "Driver application needs correction",
      body: note ? `Please update your documents: ${note}` : "Please update your documents and resubmit.",
      userId: outcome.recipientUserId,
      recipientRole: "driver",
      sentBy: adminUserId,
      metadataJson: { applicationId, status: "needs_correction", note: note || null },
    });

    if (outcome.application?.email) {
      mailService
        .sendDriverCorrectionEmail(outcome.application.email, outcome.application.full_name, note)
        .catch(() => {});
    }
  }

  return outcome;
}

async function getDriverApplication(applicationId) {
  const application = await driverApplicationModel.findById(applicationId);
  if (!application) {
    throw new ApiError(404, "Driver application not found.");
  }

  const reviewer = application.reviewed_by ? await userModel.findById(application.reviewed_by) : null;

  return {
    id: application.id,
    applicationId: application.id,
    driverId: application.driver_id || null,
    userId: application.user_id,
    fullName: application.full_name,
    phone: application.phone,
    email: application.email,
    address: application.address || null,
    emergencyContactName: application.emergency_contact_name || null,
    emergencyContactPhone: application.emergency_contact_phone || null,
    tricycleNumber: application.plate_number,
    franchiseNumber: application.franchise_number || null,
    approvalStatus: application.status,
    licenseImageUrl: application.license_image_url,
    businessPermitImageUrl: application.business_permit_image_url,
    selfieImageUrl: application.selfie_image_url || null,
    licenseNumber: application.license_number || null,
    licenseType: application.license_type || null,
    licenseHolderName: application.license_holder_name || null,
    licenseBirthDate: application.license_birth_date || null,
    licenseExpiresAt: application.license_expires_at || null,
    ocrStatus: application.ocr_status || null,
    ocrFailureReason: application.ocr_failure_reason || null,
    livenessStatus: application.liveness_status || null,
    rejectionReason: application.rejection_reason || null,
    correctionNote: application.correction_note || null,
    userStatus: application.user_status,
    reviewedBy: application.reviewed_by || null,
    reviewedByName: reviewer?.full_name || null,
    reviewedAt: application.reviewed_at || null,
    createdAt: application.created_at,
  };
}

async function getDriverApplicationTimeline(applicationId) {
  const application = await driverApplicationModel.findById(applicationId);
  if (!application) {
    throw new ApiError(404, "Driver application not found.");
  }
  return statusHistoryModel.listForApplication(applicationId);
}

async function getFareSettings() {
  return fareModel.getCurrentFareSettings();
}

async function updateFareSettings(
  baseFare,
  perKmRate,
  minimumFare,
  nightFee,
  additionalPassengerFee,
  adminUserId
) {
  if (
    Number(baseFare) < 0 ||
    Number(perKmRate) < 0 ||
    Number(minimumFare) < 0 ||
    Number(nightFee) < 0 ||
    Number(additionalPassengerFee) < 0
  ) {
    throw new ApiError(400, "Fare values must be zero or higher.");
  }

  return fareModel.updateFareSettings({
    baseFare: Number(baseFare),
    perKmRate: Number(perKmRate),
    minimumFare: Number(minimumFare),
    nightFee: Number(nightFee),
    additionalPassengerFee: Number(additionalPassengerFee || 0),
    updatedBy: adminUserId,
  });
}

async function getLiveMapData() {
  const [drivers, rides] = await Promise.all([
    driverModel.listOnlineDriversForAdmin(),
    bookingModel.listActiveRidesForAdmin(),
  ]);

  return {
    onlineDrivers: drivers,
    activeRides: rides,
  };
}

async function getDashboardSummary() {
  const [counts, onlineDrivers, allDrivers, rideHistory, passengers, pendingDrivers, licenses, recentApplications, sosAlerts] =
    await Promise.all([
      bookingModel.getDashboardCounts(),
      driverModel.listOnlineDriversForAdmin(),
      driverModel.listAllForAdmin(),
      bookingModel.listRideHistory(20),
      userModel.listPassengersForAdmin(),
      driverApplicationModel.listPendingApplications(),
      driverModel.listDriversWithExpiringLicenses(30),
      driverApplicationModel.listRecent(5),
      listSosAlerts(),
    ]);

  const statusOf = (ride) => String(ride.status || "").toLowerCase();

  return {
    totalRides: counts.totalRides,
    dailyEarnings: counts.dailyEarnings,
    activeDrivers: onlineDrivers.length,
    onlineDrivers: onlineDrivers.length,
    totalDrivers: allDrivers.length,
    approvedDrivers: allDrivers.filter((d) => d.approval_status === "approved").length,
    totalPassengers: passengers.length,
    pendingApplications: pendingDrivers.length,
    ongoingRides: rideHistory.filter((ride) => ["pending", "accepted", "ongoing"].includes(statusOf(ride))).length,
    completedRidesToday: counts.completedRidesToday,
    cancelledRidesToday: counts.cancelledRidesToday,
    todaysBookings: counts.todaysBookings,
    sosAlerts: sosAlerts.filter((alert) => alert.status === "active").length,
    rideHistory,
    recentBookings: rideHistory.slice(0, 5),
    recentDriverRegistrations: recentApplications,
    licenseExpiringSoon: licenses.length,
  };
}

async function getRideActivity(days = 7) {
  const rows = await bookingModel.getRideActivity(days);
  return rows.map((row) => ({
    date: row.date,
    total: Number(row.total || 0),
    completed: Number(row.completed || 0),
    cancelled: Number(row.cancelled || 0),
    earnings: Number(row.earnings || 0),
  }));
}

async function listAllDrivers() {
  return driverModel.listAllForAdmin();
}

async function suspendDriver(driverId, adminUserId) {
  const driver = await driverModel.findById(driverId);
  if (!driver) throw new ApiError(404, "Driver not found.");
  await driverModel.suspendDriver(driverId, adminUserId);
  return driverModel.findById(driverId);
}

async function reinstateDriver(driverId, adminUserId) {
  const driver = await driverModel.findById(driverId);
  if (!driver) throw new ApiError(404, "Driver not found.");
  await driverModel.reinstateDriver(driverId, adminUserId);
  return driverModel.findById(driverId);
}

async function listDriversExpiringWithin(days = 30) {
  const rows = await driverModel.listDriversWithExpiringLicenses(days);
  return rows.map((r) => ({ id: r.id, name: r.full_name, phone: r.phone, license_expires_at: r.license_expires_at }));
}

async function listAllPassengers() {
  return userModel.listPassengersForAdmin();
}

async function suspendPassenger(passengerId) {
  const user = await userModel.findById(passengerId);
  if (!user || user.role !== "passenger") throw new ApiError(404, "Passenger not found.");
  return userModel.suspendUser(passengerId);
}

async function reinstatePassenger(passengerId) {
  const user = await userModel.findById(passengerId);
  if (!user || user.role !== "passenger") throw new ApiError(404, "Passenger not found.");
  return userModel.reinstateUser(passengerId);
}

async function getRideHistory(limit = 50) {
  const rides = await bookingModel.listRideHistory(limit);
  return rides.map((ride) => ({
    id: ride.id,
    status: ride.status,
    passengerName: ride.passenger_name,
    driverName: ride.driver_name,
    pickupAddress: ride.pickup_address || "N/A",
    dropoffAddress: ride.dropoff_address || "N/A",
    distanceKm: parseFloat(ride.distance_km) || 0,
    fare: parseFloat(ride.final_fare || ride.estimated_fare) || 0,
    requestedAt: ride.requested_at,
    completedAt: ride.completed_at,
  }));
}

async function getPendingApprovals() {
  const pending = await driverApplicationModel.listPendingApplications();
  return pending.map((driver) => ({
    id: driver.id,
    name: driver.full_name,
    phone: driver.phone,
    email: driver.email,
    appliedDate: driver.submitted_at,
    status: driver.status,
    documents: "Pending review",
    plateNumber: driver.plate_number,
    licenseExpiresAt: driver.license_expires_at,
    ocrStatus: driver.ocr_status,
  }));
}

async function listBookings(limit = 100) {
  const rides = await bookingModel.listRideHistory(limit);
  return rides.map((ride) => ({
    id: ride.id,
    status: ride.status,
    passengerName: ride.passenger_name,
    driverName: ride.driver_name,
    pickupAddress: ride.pickup_address || "N/A",
    dropoffAddress: ride.dropoff_address || "N/A",
    distanceKm: parseFloat(ride.distance_km) || 0,
    estimatedFare: parseFloat(ride.estimated_fare) || 0,
    finalFare: parseFloat(ride.final_fare) || 0,
    requestedAt: ride.requested_at,
    completedAt: ride.completed_at,
  }));
}

async function getBookingDetail(bookingId) {
  const booking = await bookingModel.findById(bookingId);
  if (!booking) {
    throw new ApiError(404, "Booking not found.");
  }

  return {
    id: booking.id,
    status: booking.status,
    passengerName: booking.passenger_name,
    passengerPhone: booking.passenger_phone,
    driverName: booking.driver_name,
    driverPhone: booking.driver_phone,
    tricycleNumber: booking.tricycle_number,
    pickupAddress: booking.pickup_address,
    dropoffAddress: booking.dropoff_address,
    pickupLat: booking.pickup_lat,
    pickupLng: booking.pickup_lng,
    dropoffLat: booking.dropoff_lat,
    dropoffLng: booking.dropoff_lng,
    distanceKm: booking.distance_km,
    estimatedFare: booking.estimated_fare,
    finalFare: booking.final_fare,
    requestedAt: booking.requested_at,
    acceptedAt: booking.accepted_at,
    startedAt: booking.started_at,
    completedAt: booking.completed_at,
    cancelledAt: booking.cancelled_at,
    cancelledBy: booking.cancelled_by,
    declineReason: booking.decline_reason,
    paymentMethod: "cash",
  };
}

async function listComplaints() {
  const rows = await complaintModel.listForAdmin({ limit: 100, offset: 0 });
  return rows.map((row) => ({
    id: row.id,
    reporter: row.reporter_name || "Unknown",
    reportedUser: row.reported_user_name || "-",
    rideId: row.booking_id,
    category: row.category,
    description: row.description,
    status: row.status,
    createdAt: row.created_at,
  }));
}

async function resolveComplaint(complaintId, adminUserId) {
  const row = await complaintModel.resolveComplaint(complaintId, adminUserId, { status: "resolved" });
  if (!row) {
    throw new ApiError(404, "Complaint not found.");
  }
  return row;
}

async function listSosAlerts() {
  return sosService.listForAdmin();
}

async function resolveSosAlert(sosId, adminUserId) {
  return sosService.resolveForAdmin(sosId, adminUserId);
}

async function getActivityLogs(limit = 100, offset = 0) {
  const query = `
    SELECT al.id, al.created_at, u.full_name as admin_name, al.action, al.target_type, al.target_id, al.metadata_json
    FROM activity_logs al
    LEFT JOIN users u ON al.admin_id = u.id
    ORDER BY al.created_at DESC
    LIMIT ? OFFSET ?
  `;
  const rows = await db.query(query, [limit, offset]);
  return rows.map((row) => ({
    id: row.id,
    timestamp: row.created_at,
    adminName: row.admin_name || "System",
    action: row.action,
    targetType: row.target_type || "-",
    targetId: row.target_id,
    metadata: row.metadata_json ? JSON.parse(row.metadata_json) : null,
  }));
}

async function listBarangays() {
  const query = `SELECT id, name, is_enabled FROM barangays ORDER BY name ASC`;
  return await db.query(query);
}

async function updateBarangay(barangayId, isEnabled, adminUserId) {
  const query = `UPDATE barangays SET is_enabled = ? WHERE id = ?`;
  await db.query(query, [isEnabled ? 1 : 0, barangayId]);
  
  // Log activity
  const rows = await db.query(`SELECT name FROM barangays WHERE id = ?`, [barangayId]);
  const barangay = rows[0];
  const action = isEnabled ? "Barangay Enabled" : "Barangay Disabled";
  await db.query(
    `INSERT INTO activity_logs (admin_id, action, target_type, target_id, metadata_json) 
     VALUES (?, ?, ?, ?, ?)`,
    [adminUserId, action, "barangay", barangayId, JSON.stringify({ barangayId, isEnabled, barangayName: barangay?.name })]
  );

  return { id: barangayId, name: barangay?.name, is_enabled: isEnabled };
}

async function getSystemSettings() {
  const query = `
    SELECT setting_key, setting_value, value_type 
    FROM system_settings 
    WHERE deleted_at IS NULL
  `;
  const rows = await db.query(query);
  
  // Convert from key-value rows to object
  const settings = {};
  rows.forEach((row) => {
    let value = row.setting_value;
    if (row.value_type === "number") {
      value = parseFloat(value);
    } else if (row.value_type === "boolean") {
      value = value === "true" || value === "1";
    } else if (row.value_type === "json") {
      try {
        value = JSON.parse(value);
      } catch (_e) {
        // keep the raw string when it isn't valid JSON
      }
    }
    settings[row.setting_key] = value;
  });

  // Return with defaults if missing
  return {
    appName: settings.appName || "FindMeTricycle",
    supportEmail: settings.supportEmail || "support@findme.local",
    contactNumber: settings.contactNumber || "+63 9XX XXX XXXX",
    operatingHours: settings.operatingHours || "5:00 AM - 10:00 PM",
  };
}

async function updateSystemSettings(settings, adminUserId) {
  const { appName, supportEmail, contactNumber, operatingHours } = settings;
  
  // Update each setting individually using INSERT...ON DUPLICATE KEY UPDATE
  const settingsToUpdate = [
    { key: "appName", value: appName, type: "string" },
    { key: "supportEmail", value: supportEmail, type: "string" },
    { key: "contactNumber", value: contactNumber, type: "string" },
    { key: "operatingHours", value: operatingHours, type: "string" },
  ];

  for (const setting of settingsToUpdate) {
    await db.query(
      `INSERT INTO system_settings (setting_key, setting_value, value_type, updated_by)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         setting_value = VALUES(setting_value),
         updated_by = VALUES(updated_by),
         updated_at = NOW()`,
      [setting.key, String(setting.value), setting.type, adminUserId]
    );
  }
  
  // Log activity
  await db.query(
    `INSERT INTO activity_logs (admin_id, action, target_type, metadata_json) 
     VALUES (?, ?, ?, ?)`,
    [adminUserId, "System Settings Updated", "settings", JSON.stringify(settings)]
  );

  return { appName, supportEmail, contactNumber, operatingHours };
}

module.exports = {
  listPendingDrivers,
  getDriverApplication,
  getDriverApplicationTimeline,
  approveDriver,
  rejectDriver,
  requestCorrection,
  getFareSettings,
  updateFareSettings,
  getLiveMapData,
  getDashboardSummary,
  getRideActivity,
  listAllDrivers,
  suspendDriver,
  reinstateDriver,
  listDriversExpiringWithin,
  listAllPassengers,
  suspendPassenger,
  reinstatePassenger,
  getRideHistory,
  getPendingApprovals,
  listBookings,
  getBookingDetail,
  listComplaints,
  resolveComplaint,
  listSosAlerts,
  resolveSosAlert,
  getActivityLogs,
  listBarangays,
  updateBarangay,
  getSystemSettings,
  updateSystemSettings,
};
