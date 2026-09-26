const sosModel = require("../models/sos.model");
const bookingModel = require("../models/booking.model");
const notificationService = require("./notification.service");
const { getIO } = require("../sockets");
const ApiError = require("../utils/api-error");

function toAdminPayload(alert) {
  return {
    id: alert.id,
    title: "SOS Alert",
    body:
      alert.message ||
      `Emergency alert from ${alert.passenger_name || "a passenger"}${
        alert.booking_id ? ` (Booking #${alert.booking_id})` : ""
      }.`,
    createdAt: alert.created_at,
    status: alert.status,
    bookingId: alert.booking_id,
    passengerId: alert.passenger_id,
    passengerName: alert.passenger_name,
    passengerPhone: alert.passenger_phone,
    driverId: alert.driver_id,
    driverName: alert.driver_name,
    driverPhone: alert.driver_phone,
    contact: alert.passenger_phone || alert.driver_phone || null,
    lat: alert.lat !== null ? Number(alert.lat) : null,
    lng: alert.lng !== null ? Number(alert.lng) : null,
  };
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
  });

  const payload = toAdminPayload(alert);

  try {
    getIO().to("role:admin").emit("admin:sos_alert", payload);
  } catch (err) {
    // Socket.io not initialized (e.g. unit tests) — the alert is still persisted.
  }

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
  });

  const payload = toAdminPayload(alert);

  try {
    getIO().to("role:admin").emit("admin:sos_alert", payload);
  } catch (err) {
    // Socket.io not initialized (e.g. unit tests) — the alert is still persisted.
  }

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
  const alerts = await sosModel.listForAdmin(25);
  return alerts.map(toAdminPayload);
}

async function resolveForAdmin(id, adminUserId) {
  const alert = await sosModel.resolveAlert(id, adminUserId);
  if (!alert) {
    throw new ApiError(404, "SOS alert not found.");
  }
  return toAdminPayload(alert);
}

module.exports = {
  createSosAlert,
  createDriverSosAlert,
  listForAdmin,
  resolveForAdmin,
};
