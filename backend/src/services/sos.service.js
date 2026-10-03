const sosModel = require("../models/sos.model");
const bookingModel = require("../models/booking.model");
const notificationService = require("./notification.service");
const { getIO } = require("../sockets");
const ApiError = require("../utils/api-error");
const { PERMISSIONS, permissionRoom } = require("../constants/admin-permissions");
const { SOS_ESCALATION_AFTER_MS, SOS_STATUS } = require("../constants/sos");

// Live SOS alerts go only to admins who can see them; escalations only to
// those who receive them (Super Admins).
const SOS_ROOM = permissionRoom(PERMISSIONS.SOS_VIEW);
const ESCALATION_ROOM = permissionRoom(PERMISSIONS.SOS_ESCALATIONS_RECEIVE);

// Who pressed SOS. Alerts from before this was recorded fall back to the
// passenger, as they always were shown.
function senderName(alert) {
  if (alert.triggered_by_role === "driver") return alert.driver_name || "a driver";
  return alert.passenger_name || "a passenger";
}

function toAdminPayload(alert) {
  return {
    id: alert.id,
    title: "SOS Alert",
    body:
      alert.message ||
      `Emergency alert from ${senderName(alert)}${alert.booking_id ? ` (Booking #${alert.booking_id})` : ""}.`,
    createdAt: alert.created_at,
    status: alert.status,
    bookingId: alert.booking_id,
    passengerId: alert.passenger_id,
    passengerName: alert.passenger_name,
    passengerPhone: alert.passenger_phone,
    driverId: alert.driver_id,
    driverName: alert.driver_name,
    driverPhone: alert.driver_phone,
    sentBy: alert.triggered_by_role || null,
    senderName: senderName(alert),
    contact:
      (alert.triggered_by_role === "driver" ? alert.driver_phone : alert.passenger_phone) ||
      alert.passenger_phone ||
      alert.driver_phone ||
      null,
    lat: alert.lat !== null ? Number(alert.lat) : null,
    lng: alert.lng !== null ? Number(alert.lng) : null,
    acknowledgedBy: alert.acknowledged_by ? { id: alert.acknowledged_by, name: alert.acknowledged_by_name || "An admin" } : null,
    acknowledgedAt: alert.acknowledged_at || null,
    resolvedBy: alert.resolved_by ? { id: alert.resolved_by, name: alert.resolved_by_name || "An admin" } : null,
    resolvedAt: alert.resolved_at || null,
    resolutionNote: alert.resolution_note || null,
    escalatedAt: alert.escalated_at || null,
  };
}

function emitToSosRoom(event, payload) {
  try {
    getIO().to(SOS_ROOM).emit(event, payload);
  } catch (err) {
    // Socket.io not initialized (e.g. unit tests) — the change is still saved.
  }
}

async function createSosAlert({ passengerId, bookingId, lat, lng, message }) {
  let driverId = null;

  if (bookingId) {
    const booking = await bookingModel.findById(bookingId);
    if (!booking) {
      throw new ApiError(404, "Booking not found.");
    }
    if (Number(booking.passenger_id) !== Number(passengerId)) {
      throw new ApiError(403, "Booking does not belong to this passenger.");
    }
    driverId = booking.driver_id || null;
  }

  const alert = await sosModel.createAlert({
    passengerId,
    driverId,
    bookingId: bookingId || null,
    lat: lat ?? null,
    lng: lng ?? null,
    message: message || null,
    triggeredByUserId: passengerId,
    triggeredByRole: "passenger",
  });

  const payload = toAdminPayload(alert);
  emitToSosRoom("admin:sos_alert", payload);

  try {
    await notificationService.createNotification({
      type: "sos_alert",
      title: "🚨 SOS Alert",
      body: payload.body,
      recipientRole: "admin",
      metadataJson: { sosId: alert.id, bookingId: alert.booking_id, passengerId },
    });
  } catch (err) {
    // Notification-feed failures should never block the SOS response to the passenger.
  }

  return payload;
}

// Driver-triggered SOS is always tied to a booking (sos_alerts.passenger_id
// is NOT NULL, so we need the booking to know who the passenger is) —
// matches Phase 9's "During active ride: SOS".
async function createDriverSosAlert({ driverId, bookingId, lat, lng, message }) {
  if (!bookingId) {
    throw new ApiError(400, "bookingId is required to send an SOS alert.");
  }

  const booking = await bookingModel.findById(bookingId);
  if (!booking) {
    throw new ApiError(404, "Booking not found.");
  }
  if (Number(booking.driver_id) !== Number(driverId)) {
    throw new ApiError(403, "Booking does not belong to this driver.");
  }

  const alert = await sosModel.createAlert({
    passengerId: booking.passenger_id,
    driverId,
    bookingId,
    lat: lat ?? booking.pickup_lat ?? null,
    lng: lng ?? booking.pickup_lng ?? null,
    message: message || null,
    triggeredByUserId: booking.driver_user_id || null,
    triggeredByRole: "driver",
  });

  const payload = toAdminPayload(alert);
  emitToSosRoom("admin:sos_alert", payload);

  try {
    await notificationService.createNotification({
      type: "sos_alert",
      title: "🚨 SOS Alert",
      body: payload.body || `Emergency alert from driver on Booking #${bookingId}.`,
      recipientRole: "admin",
      metadataJson: { sosId: alert.id, bookingId, driverId },
    });
  } catch (err) {
    // Notification-feed failures should never block the SOS response to the driver.
  }

  return payload;
}

async function listForAdmin() {
  const alerts = await sosModel.listForAdmin(50);
  return alerts.map(toAdminPayload);
}

// Why acknowledging or resolving didn't go through, from the alert as it
// is now.
function conflictFor(alert, attempted) {
  if (!alert) return new ApiError(404, "SOS alert not found.");
  if (alert.status === SOS_STATUS.ACKNOWLEDGED) {
    if (attempted === "acknowledge") {
      return new ApiError(409, `${alert.acknowledged_by_name || "Another admin"} is already handling this alert.`, {
        acknowledgedBy: alert.acknowledged_by_name || null,
      });
    }
  }
  if (alert.status === SOS_STATUS.OPEN && attempted === "resolve") {
    return new ApiError(409, "Acknowledge the alert before resolving it.");
  }
  if (alert.status === SOS_STATUS.RESOLVED) {
    return new ApiError(409, "This alert has already been resolved.");
  }
  return new ApiError(409, "This alert can't be changed any more.");
}

// "I'm handling this." Only one admin gets an alert: everyone with SOS
// access sees who has it, live, and the person who sent the SOS is told
// help is on the way.
async function acknowledgeForAdmin(id, admin) {
  const acknowledged = await sosModel.acknowledge(id, admin.userId);
  const alert = await sosModel.findById(id);
  if (!acknowledged) {
    throw conflictFor(alert, "acknowledge");
  }

  const payload = toAdminPayload(alert);
  emitToSosRoom("admin:sos_updated", payload);
  await notifySenderHandled(alert);
  return payload;
}

async function resolveForAdmin(id, admin, note) {
  const resolved = await sosModel.resolve(id, admin.userId, note);
  const alert = await sosModel.findById(id);
  if (!resolved) {
    throw conflictFor(alert, "resolve");
  }

  const payload = toAdminPayload(alert);
  emitToSosRoom("admin:sos_updated", payload);
  return payload;
}

// Through the existing notification system: it shows in the sender's
// notification list (any type is listed) and arrives as a push.
async function notifySenderHandled(alert) {
  if (!alert.triggered_by_user_id || !alert.triggered_by_role) return;
  try {
    await notificationService.createNotification({
      userId: alert.triggered_by_user_id,
      recipientRole: alert.triggered_by_role,
      type: "sos_acknowledged",
      title: "Your SOS is being handled",
      body: "A FindMeTricycle responder has your emergency alert and is working on it now.",
      metadataJson: { sosId: alert.id, bookingId: alert.booking_id || null },
    });
  } catch (err) {
    // Telling the sender must never fail the acknowledgement.
  }
}

// Every alert still open past SOS_ESCALATION_AFTER_MS goes to the Super
// Admins once: a notification in their feed, plus a live event that plays
// the alarm on their dashboard. Returns the escalated alerts.
async function escalateOverdueAlerts() {
  const due = await sosModel.listDueForEscalation(SOS_ESCALATION_AFTER_MS / 1000);
  const escalated = [];

  for (const { id } of due) {
    // Another server (or a slow previous run) may have taken it already.
    if (!(await sosModel.claimEscalation(id))) continue;
    const alert = await sosModel.findById(id);
    if (!alert) continue;

    const payload = toAdminPayload(alert);
    const minutes = Math.round(SOS_ESCALATION_AFTER_MS / 60000);
    try {
      await notificationService.createNotification({
        type: "sos_escalation",
        title: "⏰ SOS not acknowledged",
        body: `No one has acknowledged the SOS from ${payload.senderName}${
          alert.booking_id ? ` (Booking #${alert.booking_id})` : ""
        } for over ${minutes} minute${minutes === 1 ? "" : "s"}.`,
        recipientRole: "admin",
        metadataJson: { sosId: alert.id, bookingId: alert.booking_id || null },
      });
    } catch (err) {
      // The live event below still goes out.
    }
    try {
      getIO().to(ESCALATION_ROOM).emit("admin:sos_escalation", payload);
    } catch (err) {
      // Socket.io not initialized (e.g. unit tests).
    }
    emitToSosRoom("admin:sos_updated", payload);
    escalated.push(payload);
  }

  return escalated;
}

module.exports = {
  createSosAlert,
  createDriverSosAlert,
  listForAdmin,
  acknowledgeForAdmin,
  resolveForAdmin,
  escalateOverdueAlerts,
};
