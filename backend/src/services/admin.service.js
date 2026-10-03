const bookingModel = require("../models/booking.model");
const driverModel = require("../models/driver.model");
const driverApplicationModel = require("../models/driver-application.model");
const userModel = require("../models/user.model");
const refreshTokenModel = require("../models/refresh-token.model");
const fareModel = require("../models/fare.model");
const complaintModel = require("../models/complaint.model");
const notificationService = require("./notification.service");
const sosService = require("./sos.service");
const mailService = require("./mail.service");
const statusHistoryModel = require("../models/application-status-history.model");
const db = require("../config/db");
const ApiError = require("../utils/api-error");
const barangayService = require("./barangay.service");
const serviceAreaService = require("./service-area.service");
const systemSettingsService = require("./system-settings.service");
const { PERMISSIONS: P } = require("../constants/admin-permissions");

async function listPendingDrivers(status = "pending") {
  const [applications, counts] = await Promise.all([
    driverApplicationModel.listApplicationsForAdmin(status),
    driverApplicationModel.countApplicationsByStatus(),
  ]);
  return { applications, counts };
}

// NOTE: the "driverId" the Admin Dashboard sends here is actually the
// driver_applications.id (see listPendingApplications, which returns
// application rows). Applications submitted through the v2 apply-driver
// flow have driver_id = NULL — no `drivers` row exists until the admin
// approves. Keying these functions by applicationId (not driverId) is
// what makes approve/reject/request-correction actually work for them.
function parseJsonSafe(value) {
  if (!value) return null;
  try {
    return JSON.parse(value);
  } catch (_error) {
    return null;
  }
}

// Documents the automatic check didn't clearly recognise (or hasn't
// checked yet). Approving those needs an explicit acknowledgement.
function documentWarnings(application) {
  if (!application.documents_checked_at) {
    return ["The automatic document check hasn't finished for this application."];
  }
  const warnings = [];
  const label = { suspicious: "doesn't look like", unreadable: "couldn't be read as", error: "couldn't be checked as" };
  if (application.license_check_status !== "verified") {
    warnings.push(`The license photo ${label[application.license_check_status] || "wasn't verified as"} a driver's license.`);
  }
  if (application.permit_check_status !== "verified") {
    warnings.push(`The permit photo ${label[application.permit_check_status] || "wasn't verified as"} a franchise / business permit.`);
  }
  return warnings;
}

async function approveDriver(applicationId, adminUserId, { acknowledgeDocumentWarnings = false } = {}) {
  const outcome = await db.withTransaction(async (client) => {
    const application = await driverApplicationModel.findById(applicationId, client);
    if (!application) {
      throw new ApiError(404, "Driver application not found.");
    }
    if (application.status !== "pending") {
      throw new ApiError(400, `Application is already ${application.status}.`);
    }

    const warnings = documentWarnings(application);
    if (warnings.length && !acknowledgeDocumentWarnings) {
      throw new ApiError(409, "Please review the document warnings before approving.", {
        code: "DOCUMENT_CHECK_WARNING",
        warnings,
      });
    }

    let driver = application.driver_id ? await driverModel.findById(application.driver_id, client) : null;

    // A resubmitted application (after approval was revoked) belongs to a
    // rider who already has a driver profile — reuse it, with the new
    // documents, instead of trying to create a second one.
    if (!driver) {
      driver = await driverModel.findByUserId(application.user_id, client);
      if (driver) {
        await client.query(
          `UPDATE drivers
              SET license_image_url = ?, business_permit_image_url = ?,
                  license_expires_at = COALESCE(?, license_expires_at),
                  license_number = COALESCE(?, license_number),
                  license_holder_name = COALESCE(?, license_holder_name)
            WHERE id = ?`,
          [
            application.license_image_url,
            application.business_permit_image_url,
            application.license_expires_at || null,
            application.license_number || null,
            application.license_holder_name || null,
            driver.id,
          ]
        );
        await client.query("UPDATE driver_applications SET driver_id = ? WHERE id = ?", [driver.id, application.id]);
      }
    }

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
    // Server-side OCR check of the uploaded photos (document-check.service).
    documentCheck: {
      checkedAt: application.documents_checked_at || null,
      license: application.license_check_status || null,
      permit: application.permit_check_status || null,
      details: parseJsonSafe(application.document_check_json),
    },
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

// Each figure is included only when the admin's permissions cover it, and
// its query is skipped otherwise — an SOS Responder's dashboard never
// carries earnings, passenger counts or driver applications.
async function getDashboardSummary(permissions = []) {
  const can = (permission) => permissions.includes(permission);
  const canRides = can(P.BOOKINGS_VIEW) || can(P.RIDES_VIEW);
  const canDrivers = can(P.DRIVERS_VIEW);
  const canOnlineDrivers = canDrivers || can(P.LIVE_MAP_VIEW);
  const canApplications = can(P.DRIVER_APPLICATIONS_VIEW);

  const [counts, onlineDrivers, allDrivers, rideHistory, passengers, pendingDrivers, licenses, recentApplications, sosAlerts] =
    await Promise.all([
      canRides || can(P.EARNINGS_VIEW) ? bookingModel.getDashboardCounts() : null,
      canOnlineDrivers ? driverModel.listOnlineDriversForAdmin() : null,
      canDrivers ? driverModel.listAllForAdmin() : null,
      canRides ? bookingModel.listRideHistory(20) : null,
      can(P.USERS_VIEW) ? userModel.listPassengersForAdmin() : null,
      canApplications ? driverApplicationModel.listPendingApplications() : null,
      canDrivers ? driverModel.listDriversWithExpiringLicenses(30) : null,
      canApplications ? driverApplicationModel.listRecent(5) : null,
      can(P.SOS_VIEW) ? listSosAlerts() : null,
    ]);

  const statusOf = (ride) => String(ride.status || "").toLowerCase();
  const summary = {};

  if (canRides) {
    summary.totalRides = counts.totalRides;
    summary.ongoingRides = rideHistory.filter((ride) => ["pending", "accepted", "ongoing"].includes(statusOf(ride))).length;
    summary.completedRidesToday = counts.completedRidesToday;
    summary.cancelledRidesToday = counts.cancelledRidesToday;
    summary.todaysBookings = counts.todaysBookings;
    summary.rideHistory = rideHistory;
    summary.recentBookings = rideHistory.slice(0, 5);
  }
  if (can(P.EARNINGS_VIEW)) summary.dailyEarnings = counts.dailyEarnings;
  if (canOnlineDrivers) {
    summary.activeDrivers = onlineDrivers.length;
    summary.onlineDrivers = onlineDrivers.length;
  }
  if (canDrivers) {
    summary.totalDrivers = allDrivers.length;
    summary.approvedDrivers = allDrivers.filter((d) => d.approval_status === "approved").length;
    summary.licenseExpiringSoon = licenses.length;
  }
  if (can(P.USERS_VIEW)) summary.totalPassengers = passengers.length;
  if (canApplications) {
    summary.pendingApplications = pendingDrivers.length;
    summary.recentDriverRegistrations = recentApplications;
  }
  if (can(P.SOS_VIEW)) summary.sosAlerts = sosAlerts.filter((alert) => alert.status === "active").length;

  return summary;
}

async function getRideActivity(days = 7, { includeEarnings = true } = {}) {
  const rows = await bookingModel.getRideActivity(days);
  return rows.map((row) => ({
    date: row.date,
    total: Number(row.total || 0),
    completed: Number(row.completed || 0),
    cancelled: Number(row.cancelled || 0),
    ...(includeEarnings ? { earnings: Number(row.earnings || 0) } : {}),
  }));
}

async function listAllDrivers() {
  return driverModel.listAllForAdmin();
}

// Takes an approved rider back out of service because their documents
// aren't right: driver mode is switched off and their application goes back
// to "needs correction" so they can resubmit proper documents (and be
// approved again). Refused while they're on a ride.
async function revokeDriverApproval(driverId, adminUserId, note) {
  const reason = String(note || "").trim() ||
    "Your submitted documents are not a valid driver's license and franchise / permit.";

  const outcome = await db.withTransaction(async (client) => {
    const driver = await driverModel.findById(driverId, client);
    if (!driver) throw new ApiError(404, "Driver not found.");
    if (!["approved", "suspended", "license_expired"].includes(driver.approval_status)) {
      throw new ApiError(400, `Driver is not approved (status: ${driver.approval_status}).`);
    }
    const [activeRide] = await client.query(
      `SELECT id FROM bookings WHERE driver_id = ? AND deleted_at IS NULL
         AND status IN ('accepted', 'assigned', 'arriving', 'ongoing', 'on_ride') LIMIT 1`,
      [driverId]
    );
    if (activeRide) {
      throw new ApiError(409, `This driver is on ride #${activeRide.id}. Try again after it ends.`);
    }

    await client.query("UPDATE drivers SET approval_status = 'pending', is_online = 0 WHERE id = ?", [driverId]);
    await client.query("UPDATE users SET driver_approval_status = 'pending' WHERE id = ?", [driver.user_id]);

    const [application] = await client.query(
      `SELECT id FROM driver_applications WHERE user_id = ? AND status <> 'archived' ORDER BY id DESC LIMIT 1`,
      [driver.user_id]
    );
    let updatedApplication = null;
    if (application) {
      updatedApplication = await driverApplicationModel.markNeedsCorrection(application.id, adminUserId, reason, client);
      await statusHistoryModel.logStatus(application.id, "needs_correction", `Approval revoked: ${reason}`, adminUserId, client);
    }
    return { driver, application: updatedApplication, recipientUserId: driver.user_id };
  });

  await notificationService.createNotification({
    type: "driver_approval_revoked",
    title: "Driver approval revoked",
    body: `Please resubmit your documents: ${reason}`,
    userId: outcome.recipientUserId,
    // Sent to both app modes — driver mode is no longer available to them.
    recipientRole: "everyone",
    sentBy: adminUserId,
    metadataJson: { driverId, status: "needs_correction", note: reason },
  });
  if (outcome.application?.email) {
    mailService
      .sendDriverCorrectionEmail(outcome.application.email, outcome.application.full_name, reason)
      .catch(() => {});
  }
  return { ...outcome, reason };
}

async function suspendDriver(driverId, adminUserId) {
  const driver = await driverModel.findById(driverId);
  if (!driver) throw new ApiError(404, "Driver not found.");
  if (!["approved", "license_expired"].includes(driver.approval_status)) {
    throw new ApiError(400, `Driver can't be suspended (status: ${driver.approval_status}).`);
  }
  const [activeRide] = await db.query(
    `SELECT id FROM bookings WHERE driver_id = ? AND deleted_at IS NULL
       AND status IN ('accepted', 'assigned', 'arriving', 'ongoing', 'on_ride') LIMIT 1`,
    [driverId]
  );
  if (activeRide) {
    throw new ApiError(409, `This driver is on ride #${activeRide.id}. Try again after it ends.`);
  }
  await driverModel.suspendDriver(driverId, adminUserId);
  return driverModel.findById(driverId);
}

async function reinstateDriver(driverId, adminUserId) {
  const driver = await driverModel.findById(driverId);
  if (!driver) throw new ApiError(404, "Driver not found.");
  if (driver.approval_status !== "suspended") {
    throw new ApiError(400, `Driver is not suspended (status: ${driver.approval_status}).`);
  }
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

  // Don't strand a ride in progress (as passenger, or as a driver on the
  // same account).
  const [activeRide] = await db.query(
    `SELECT b.id FROM bookings b
       LEFT JOIN drivers d ON d.id = b.driver_id
      WHERE (b.passenger_id = ? OR d.user_id = ?) AND b.deleted_at IS NULL
        AND b.status IN ('pending', 'accepted', 'assigned', 'arriving', 'ongoing', 'on_ride')
      LIMIT 1`,
    [passengerId, passengerId]
  );
  if (activeRide) {
    throw new ApiError(409, `This user has an active ride (#${activeRide.id}). Try again after it ends.`);
  }

  const suspended = await userModel.suspendUser(passengerId);
  // Sign them out everywhere: refresh tokens would otherwise keep renewing
  // their session until the next API call is refused.
  await refreshTokenModel.revokeAllByUserId(passengerId);
  await db.query("UPDATE drivers SET is_online = 0 WHERE user_id = ?", [passengerId]);
  return suspended;
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
    cancelReason: booking.cancel_reason || null,
    declineReason: booking.decline_reason,
    paymentMethod: "cash",
  };
}

function toComplaintView(row) {
  return {
    id: row.id,
    reporter: row.reporter_name || "Unknown",
    reporterPhone: row.reporter_phone || null,
    reportedUser: row.reported_user_name || null,
    rideId: row.booking_id,
    category: row.category,
    description: row.description,
    status: row.status,
    createdAt: row.created_at,
    resolutionNote: row.resolution_note || null,
    resolvedAt: row.resolved_at || null,
    resolvedByName: row.resolved_by_name || null,
  };
}

async function listComplaints() {
  const rows = await complaintModel.listForAdmin({ limit: 100, offset: 0 });
  return rows.map(toComplaintView);
}

// Closes an open report as resolved (acted on) or dismissed (no action
// needed), with an optional note on what was done.
async function resolveComplaint(complaintId, adminUserId, { status = "resolved", note = null } = {}) {
  const existing = await complaintModel.findById(complaintId);
  if (!existing) {
    throw new ApiError(404, "Report not found.");
  }
  if (existing.status !== "open") {
    throw new ApiError(409, `This report is already ${existing.status}.`);
  }
  const row = await complaintModel.resolveComplaint(complaintId, adminUserId, {
    status,
    resolutionNote: note ? String(note).trim() || null : null,
  });
  return toComplaintView(row);
}

async function listSosAlerts() {
  return sosService.listForAdmin();
}

async function acknowledgeSosAlert(sosId, admin) {
  return sosService.acknowledgeForAdmin(sosId, admin);
}

async function resolveSosAlert(sosId, admin, note) {
  return sosService.resolveForAdmin(sosId, admin, note);
}

async function getActivityLogs(limit = 100, offset = 0) {
  const query = `
    SELECT al.id, al.created_at, COALESCE(al.admin_name, u.full_name) AS admin_name, al.action, al.target_type, al.target_id, al.metadata_json
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
  return db.query(
    "SELECT id, name, is_enabled, lat, lng FROM barangays WHERE deleted_at IS NULL ORDER BY name ASC"
  );
}

// Enable/disable a barangay and/or move its pin. Pickups and drop-offs are
// matched to the nearest pin, so a pin in the wrong place blocks (or lets
// through) the wrong area.
async function updateBarangay(barangayId, changes, adminUserId) {
  const [existing] = await db.query(
    "SELECT id, name, is_enabled, lat, lng FROM barangays WHERE id = ? AND deleted_at IS NULL",
    [barangayId]
  );
  if (!existing) throw new ApiError(404, "Barangay not found.");

  const isEnabled = changes.is_enabled ?? Boolean(existing.is_enabled);
  const lat = changes.lat ?? existing.lat;
  const lng = changes.lng ?? existing.lng;
  // A moved pin has to land inside Guiuan's boundary (always, whatever
  // GEOFENCE_ENABLED says): pins decide which barangay a point belongs to.
  if (changes.lat !== undefined || changes.lng !== undefined) {
    serviceAreaService.assertPinInsideBoundary(lat, lng);
  }
  await db.query("UPDATE barangays SET is_enabled = ?, lat = ?, lng = ? WHERE id = ?", [
    isEnabled ? 1 : 0,
    lat,
    lng,
    barangayId,
  ]);
  barangayService.invalidateCache();

  const actions = [];
  if (changes.is_enabled !== undefined && changes.is_enabled !== Boolean(existing.is_enabled)) {
    actions.push(isEnabled ? "Barangay Enabled" : "Barangay Disabled");
  }
  if (changes.lat !== undefined || changes.lng !== undefined) actions.push("Barangay Pin Moved");
  for (const action of actions) {
    await db.query(
      `INSERT INTO activity_logs (admin_id, admin_name, action, target_type, target_id, metadata_json)
       VALUES (?, (SELECT full_name FROM users WHERE id = ?), ?, ?, ?, ?)`,
      [
        adminUserId,
        adminUserId,
        action,
        "barangay",
        barangayId,
        JSON.stringify({ barangayName: existing.name, isEnabled, lat, lng }),
      ]
    );
  }

  return { id: barangayId, name: existing.name, is_enabled: isEnabled ? 1 : 0, lat, lng };
}

async function getSystemSettings() {
  return systemSettingsService.getSettings();
}

async function updateSystemSettings(settings, adminUserId) {
  return systemSettingsService.updateSettings(settings, adminUserId);
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
  revokeDriverApproval,
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
  acknowledgeSosAlert,
  resolveSosAlert,
  getActivityLogs,
  listBarangays,
  updateBarangay,
  getSystemSettings,
  updateSystemSettings,
};
