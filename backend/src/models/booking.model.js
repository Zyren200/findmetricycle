const crypto = require("crypto");
const bcrypt = require("bcryptjs");
const db = require("../config/db");

// Response window a driver has to accept/decline before the offer is
// treated as expired and reassigned to the next nearest driver.
const OFFER_TTL_SECONDS = 20;
const MAX_PIN_ATTEMPTS = 5;
const PIN_STATUSES = ["pending", "searching", "accepted", "assigned", "arriving"];

function generatePin() {
  return String(crypto.randomInt(1000, 10000));
}

// The plain pickup PIN is kept so the passenger can see it again after an
// app restart, but it must only ever reach the passenger who owns the
// booking — every general-purpose read strips it here, and the passenger
// gets it through getPickupPinForPassenger() instead.
function withoutPin(row) {
  if (!row) return row;
  const { pickup_pin, ...rest } = row;
  return rest;
}

async function createBooking(payload) {
  const pin = generatePin();
  const pinHash = await bcrypt.hash(pin, 8);

  const result = await db.query(
    `
      INSERT INTO bookings (
        passenger_id,
        driver_id,
        pickup_address,
        pickup_lat,
        pickup_lng,
        dropoff_address,
        dropoff_lat,
        dropoff_lng,
        passenger_count,
        distance_km,
        estimated_fare,
        fare_breakdown_json,
        pickup_pin_hash,
        pickup_pin,
        status
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
    `,
    [
      payload.passengerId,
      payload.driverId || null,
      payload.pickupAddress || null,
      payload.pickupLat,
      payload.pickupLng,
      payload.dropoffAddress || null,
      payload.dropoffLat,
      payload.dropoffLng,
      payload.passengerCount || 1,
      payload.distanceKm,
      payload.estimatedFare,
      payload.fareBreakdown ? JSON.stringify(payload.fareBreakdown) : null,
      pinHash,
      pin,
    ]
  );

  const booking = await findById(result.insertId);
  // Only ever handed back once, right after creation, so the passenger's
  // own client can display it — never re-readable from storage afterward.
  return { ...booking, pickup_pin: pin };
}

async function findById(bookingId, client = db) {
  const rows = await client.query(
    `
      SELECT
        b.*,
        p.full_name AS passenger_name,
        p.phone AS passenger_phone,
        d.user_id AS driver_user_id,
        du.full_name AS driver_name,
        du.phone AS driver_phone,
        d.tricycle_number,
        d.rating_avg AS driver_rating,
        d.current_lat,
        d.current_lng,
        d.last_location_update,
        d.is_online
      FROM bookings b
      JOIN users p ON p.id = b.passenger_id
      LEFT JOIN drivers d ON d.id = b.driver_id
      LEFT JOIN users du ON du.id = d.user_id
      WHERE b.id = ?
        AND b.deleted_at IS NULL
      LIMIT 1
    `,
    [bookingId]
  );

  return withoutPin(rows[0]) || null;
}

async function findActiveByPassenger(passengerId) {
  const rows = await db.query(
    `
      SELECT
        b.*,
        p.full_name AS passenger_name,
        p.phone AS passenger_phone,
        d.user_id AS driver_user_id,
        du.full_name AS driver_name,
        du.phone AS driver_phone,
        d.tricycle_number,
        d.rating_avg AS driver_rating,
        d.current_lat,
        d.current_lng,
        d.last_location_update,
        d.is_online
      FROM bookings b
      JOIN users p ON p.id = b.passenger_id
      LEFT JOIN drivers d ON d.id = b.driver_id
      LEFT JOIN users du ON du.id = d.user_id
      WHERE b.passenger_id = ?
        AND b.status IN ('pending', 'searching', 'accepted', 'assigned', 'arriving', 'ongoing', 'on_ride')
        AND b.deleted_at IS NULL
      ORDER BY b.id DESC
      LIMIT 1
    `,
    [passengerId]
  );
  return withoutPin(rows[0]) || null;
}

async function findActiveByDriver(driverId) {
  const rows = await db.query(
    `
      SELECT
        b.*,
        p.full_name AS passenger_name,
        p.phone AS passenger_phone,
        d.user_id AS driver_user_id,
        du.full_name AS driver_name,
        du.phone AS driver_phone,
        d.tricycle_number,
        d.rating_avg AS driver_rating,
        d.current_lat,
        d.current_lng,
        d.last_location_update,
        d.is_online
      FROM bookings b
      JOIN users p ON p.id = b.passenger_id
      LEFT JOIN drivers d ON d.id = b.driver_id
      LEFT JOIN users du ON du.id = d.user_id
      WHERE b.driver_id = ?
        AND b.status IN ('pending', 'searching', 'accepted', 'assigned', 'arriving', 'ongoing', 'on_ride')
        AND b.deleted_at IS NULL
      -- The ride a driver is on always wins over a leftover pending offer,
      -- or arrive/start/complete would look up the wrong booking.
      ORDER BY b.status = 'pending', b.id DESC
      LIMIT 1
    `,
    [driverId]
  );
  return withoutPin(rows[0]) || null;
}

// Every status in which a booking holds its driver (an offer waiting for an
// answer counts — the driver can only weigh one request at a time).
const DRIVER_HOLDING_STATUSES = ["pending", "searching", "accepted", "assigned", "arriving", "ongoing", "on_ride"];
const DRIVER_ON_RIDE_STATUSES = ["accepted", "assigned", "arriving", "ongoing", "on_ride"];

function inList(statuses) {
  return statuses.map((status) => `'${status}'`).join(", ");
}

// Takes the driver's row lock for the rest of the transaction, so two
// requests deciding about the same driver run one after the other instead
// of both seeing them as free.
async function lockDriver(client, driverId) {
  const rows = await client.query("SELECT id FROM drivers WHERE id = ? FOR UPDATE", [driverId]);
  return rows.length > 0;
}

async function driverHasOtherBooking(client, driverId, bookingId, statuses) {
  const rows = await client.query(
    `SELECT id FROM bookings
     WHERE driver_id = ? AND id <> ? AND status IN (${inList(statuses)}) AND deleted_at IS NULL
     LIMIT 1`,
    [driverId, bookingId]
  );
  return rows.length > 0;
}

// Atomic for both sides: the booking must still be pending and unassigned,
// and the driver must not already hold another booking. Two passengers
// picking the same rider at the same instant used to both win (the old
// check only covered the booking), leaving the rider with two requests.
// `assigned: false` comes with a reason — "driver_busy" (someone else got
// this rider) or "booking_taken" (this booking already moved on).
async function assignDriver(bookingId, driverId) {
  const outcome = await db.withTransaction(async (client) => {
    if (!(await lockDriver(client, driverId))) return { assigned: false, reason: "driver_busy" };
    if (await driverHasOtherBooking(client, driverId, bookingId, DRIVER_HOLDING_STATUSES)) {
      return { assigned: false, reason: "driver_busy" };
    }

    const result = await client.query(
      `
        UPDATE bookings
        SET driver_id = ?, decline_reason = NULL,
            offer_expires_at = DATE_ADD(NOW(), INTERVAL ${OFFER_TTL_SECONDS} SECOND)
        WHERE id = ? AND driver_id IS NULL AND status = 'pending'
      `,
      [driverId, bookingId]
    );
    return result.affectedRows > 0
      ? { assigned: true, reason: null }
      : { assigned: false, reason: "booking_taken" };
  });
  return { ...outcome, booking: await findById(bookingId) };
}

// Only un-assigns while the offer is still pending and still held by
// `expectedDriverId` — if the driver accepted a moment earlier (or the
// booking already moved on to someone else) nothing changes.
async function clearAssignedDriver(bookingId, expectedDriverId, declineReason = null) {
  const result = await db.query(
    `
      UPDATE bookings
      SET driver_id = NULL, decline_reason = ?, offer_expires_at = NULL
      WHERE id = ? AND driver_id = ? AND status = 'pending'
    `,
    [declineReason, bookingId, expectedDriverId]
  );
  return { changed: result.affectedRows > 0, booking: await findById(bookingId) };
}

// Pending bookings whose driver never responded in time — the caller
// (ride-offer-scheduler.service.js) treats these the same as a decline:
// clear the driver and try to reassign to the next nearest one.
async function findExpiredPendingOffers() {
  const rows = await db.query(
    `
      SELECT * FROM bookings
      WHERE status = 'pending'
        AND driver_id IS NOT NULL
        AND offer_expires_at IS NOT NULL
        AND offer_expires_at < NOW()
        AND deleted_at IS NULL
    `
  );
  return rows.map(withoutPin);
}

// The passenger's PIN for their own pre-trip booking. Bookings created
// before the plain PIN was stored (or whose PIN got locked out by wrong
// guesses) get a fresh PIN so the passenger is never left without one.
async function getPickupPinForPassenger(bookingId, passengerId) {
  const rows = await db.query(
    "SELECT pickup_pin, pin_attempts, pin_verified_at, status FROM bookings WHERE id = ? AND passenger_id = ? LIMIT 1",
    [bookingId, passengerId]
  );
  const row = rows[0];
  if (!row || !PIN_STATUSES.includes(row.status) || row.pin_verified_at) return null;
  if (row.pickup_pin && row.pin_attempts < MAX_PIN_ATTEMPTS) return row.pickup_pin;

  const pin = generatePin();
  const pinHash = await bcrypt.hash(pin, 8);
  await db.query(
    "UPDATE bookings SET pickup_pin = ?, pickup_pin_hash = ?, pin_attempts = 0 WHERE id = ? AND pin_verified_at IS NULL",
    [pin, pinHash, bookingId]
  );
  return pin;
}

async function verifyPickupPin(bookingId, code) {
  const rows = await db.query(
    "SELECT pickup_pin_hash, pin_attempts FROM bookings WHERE id = ? LIMIT 1",
    [bookingId]
  );
  const row = rows[0];
  if (!row || !row.pickup_pin_hash) {
    return { ok: false, reason: "no_pin" };
  }
  if (row.pin_attempts >= MAX_PIN_ATTEMPTS) {
    return { ok: false, reason: "locked" };
  }

  const matches = await bcrypt.compare(String(code || ""), row.pickup_pin_hash);
  if (!matches) {
    await db.query(
      "UPDATE bookings SET pin_attempts = pin_attempts + 1 WHERE id = ?",
      [bookingId]
    );
    return {
      ok: false,
      reason: "mismatch",
      attemptsRemaining: Math.max(0, MAX_PIN_ATTEMPTS - (row.pin_attempts + 1)),
    };
  }

  // Trip is starting — the plain PIN has done its job, drop it.
  await db.query(
    "UPDATE bookings SET pin_verified_at = NOW(), pickup_pin = NULL WHERE id = ?",
    [bookingId]
  );
  return { ok: true };
}

// Guarded on driver_id so a driver whose offer already expired and was
// handed to someone else can't still accept it.
// A driver can only be on one ride: accepting is refused (reason
// "driver_busy") while they already have an accepted / ongoing booking.
async function markAccepted(bookingId, driverId) {
  const outcome = await db.withTransaction(async (client) => {
    await lockDriver(client, driverId);
    if (await driverHasOtherBooking(client, driverId, bookingId, DRIVER_ON_RIDE_STATUSES)) {
      return { changed: false, reason: "driver_busy" };
    }

    const result = await client.query(
      `
        UPDATE bookings
        SET status = 'accepted', accepted_at = NOW(), offer_expires_at = NULL
        WHERE id = ? AND driver_id = ? AND status = 'pending'
      `,
      [bookingId, driverId]
    );
    return result.affectedRows > 0
      ? { changed: true, reason: null }
      : { changed: false, reason: "offer_gone" };
  });
  return { ...outcome, booking: await findById(bookingId) };
}

async function markArriving(bookingId) {
  await db.query(
    `
      UPDATE bookings
      SET status = 'arriving'
      WHERE id = ? AND status = 'accepted'
    `,
    [bookingId]
  );
  return findById(bookingId);
}

async function markOngoing(bookingId) {
  await db.query(
    `
      UPDATE bookings
      SET status = 'ongoing', started_at = NOW()
      WHERE id = ? AND status IN ('accepted', 'arriving')
    `,
    [bookingId]
  );
  return findById(bookingId);
}

// `client` lets completeRide run this and the earnings credit in one
// transaction; `changed` is false when a concurrent request already
// completed the ride, so earnings are never credited twice.
async function markCompleted(bookingId, finalFare, client = db) {
  const result = await client.query(
    `
      UPDATE bookings
      SET status = 'completed', completed_at = NOW(), final_fare = ?
      WHERE id = ? AND status = 'ongoing'
    `,
    [finalFare, bookingId]
  );
  return { changed: result.affectedRows > 0 };
}

// 'arriving' is included so a passenger can still back out once the driver
// is at pickup, and a driver-reported no-show (booking.service.js
// markNoShow) can close out a ride they've already reached pickup for.
const CANCELLABLE_STATUSES = ["pending", "accepted", "arriving"];

// `fromStatuses` widens what can be cancelled — only the admin's
// force-close passes every active status, including a ride in progress.
async function markCancelled(bookingId, cancelledBy, { reason = null, fromStatuses = CANCELLABLE_STATUSES } = {}) {
  const result = await db.query(
    `
      UPDATE bookings
      SET status = 'cancelled', cancelled_at = NOW(), cancelled_by = ?${reason ? ", cancel_reason = ?" : ""}
      WHERE id = ? AND status IN (${inList(fromStatuses)})
    `,
    reason ? [cancelledBy, reason, bookingId] : [cancelledBy, bookingId]
  );
  return { changed: result.affectedRows > 0, booking: await findById(bookingId) };
}

// Rides waiting for a driver who has gone silent: accepted/arriving for at
// least `minutes`, with no location from the driver for as long. A ride in
// progress is never returned — a dead zone mid-trip is normal, and only the
// admin closes those.
async function findRidesWithUnreachableDriver(minutes) {
  const rows = await db.query(
    `
      SELECT b.id, b.driver_id, b.passenger_id, d.user_id AS driver_user_id
      FROM bookings b
      JOIN drivers d ON d.id = b.driver_id
      WHERE b.status IN ('accepted', 'arriving')
        AND b.deleted_at IS NULL
        AND (b.accepted_at IS NULL OR b.accepted_at < DATE_SUB(NOW(), INTERVAL ${Number(minutes)} MINUTE))
        AND (d.last_location_update IS NULL
             OR d.last_location_update < DATE_SUB(NOW(), INTERVAL ${Number(minutes)} MINUTE))
    `
  );
  return rows;
}

// A driver backing out before the trip starts: the booking goes back to
// "waiting for a rider" so the passenger can pick someone else instead of
// booking all over again.
async function releaseDriver(bookingId, driverId, reason) {
  const result = await db.query(
    `
      UPDATE bookings
      SET status = 'pending', driver_id = NULL, accepted_at = NULL,
          offer_expires_at = NULL, decline_reason = ?
      WHERE id = ? AND driver_id = ? AND status IN ('accepted', 'arriving')
    `,
    [reason, bookingId, driverId]
  );
  return { changed: result.affectedRows > 0, booking: await findById(bookingId) };
}

async function listActiveRidesForAdmin() {
  return db.query(
    `
      SELECT
        b.id,
        b.status,
        b.pickup_lat,
        b.pickup_lng,
        b.dropoff_lat,
        b.dropoff_lng,
        b.requested_at,
        p.full_name AS passenger_name,
        d.tricycle_number,
        d.current_lat,
        d.current_lng,
        d.last_location_update,
        d.is_online,
        du.full_name AS driver_name
      FROM bookings b
      JOIN users p ON p.id = b.passenger_id
      LEFT JOIN drivers d ON d.id = b.driver_id
      LEFT JOIN users du ON du.id = d.user_id
      WHERE b.status IN ('pending', 'searching', 'accepted', 'assigned', 'arriving', 'ongoing', 'on_ride')
        AND b.deleted_at IS NULL
      ORDER BY b.id DESC
    `
  );
}

async function listRideHistory(limit = 100) {
  return db.query(
    `
      SELECT
        b.id,
        b.status,
        b.pickup_address,
        b.dropoff_address,
        b.distance_km,
        b.estimated_fare,
        b.final_fare,
        b.requested_at,
        b.completed_at,
        p.full_name AS passenger_name,
        du.full_name AS driver_name
      FROM bookings b
      JOIN users p ON p.id = b.passenger_id
      LEFT JOIN drivers d ON d.id = b.driver_id
      LEFT JOIN users du ON du.id = d.user_id
      WHERE b.deleted_at IS NULL
      ORDER BY b.id DESC
      LIMIT ?
    `,
    [limit]
  );
}

async function listCompletedByDriver(driverId, limit = 50) {
  return db.query(
    `
      SELECT
        b.id,
        b.status,
        b.pickup_address,
        b.dropoff_address,
        b.distance_km,
        b.estimated_fare,
        b.final_fare,
        b.requested_at,
        b.accepted_at,
        b.started_at,
        b.completed_at,
        p.full_name AS passenger_name,
        r.stars AS passenger_rating,
        r.feedback AS passenger_feedback
      FROM bookings b
      JOIN users p ON p.id = b.passenger_id
      LEFT JOIN ratings r ON r.booking_id = b.id
      WHERE b.driver_id = ?
        AND b.status = 'completed'
        AND b.deleted_at IS NULL
      ORDER BY b.completed_at DESC, b.id DESC
      LIMIT ?
    `,
    [driverId, limit]
  );
}

// A rider's finished trips — completed plus ones that were cancelled after
// they'd accepted (declined/expired offers clear driver_id, so they never
// appear here). Newest first; optional status filter.
async function listHistoryByDriver(driverId, { limit = 20, offset = 0, status = null } = {}) {
  const statuses = status ? [status] : ["completed", "cancelled"];
  return db.query(
    `
      SELECT
        b.id,
        b.status,
        b.pickup_address,
        b.dropoff_address,
        b.distance_km,
        b.estimated_fare,
        b.final_fare,
        b.passenger_count,
        b.requested_at,
        b.accepted_at,
        b.started_at,
        b.completed_at,
        b.cancelled_at,
        b.cancelled_by,
        p.full_name AS passenger_name,
        r.stars AS passenger_rating,
        r.feedback AS passenger_feedback
      FROM bookings b
      JOIN users p ON p.id = b.passenger_id
      LEFT JOIN ratings r ON r.booking_id = b.id
      WHERE b.driver_id = ?
        AND b.status IN (${statuses.map(() => "?").join(", ")})
        AND b.deleted_at IS NULL
      ORDER BY COALESCE(b.completed_at, b.cancelled_at, b.requested_at) DESC, b.id DESC
      LIMIT ? OFFSET ?
    `,
    [driverId, ...statuses, limit, offset]
  );
}

async function getDriverRideStats(driverId) {
  const [row] = await db.query(
    `
      SELECT
        COALESCE(SUM(status = 'completed'), 0) AS completed,
        COALESCE(SUM(status = 'cancelled'), 0) AS cancelled,
        COALESCE(SUM(CASE WHEN status = 'completed' THEN final_fare END), 0) AS total_earned
      FROM bookings
      WHERE driver_id = ? AND status IN ('completed', 'cancelled') AND deleted_at IS NULL
    `,
    [driverId]
  );
  return {
    completed: Number(row.completed || 0),
    cancelled: Number(row.cancelled || 0),
    totalEarned: Number(Number(row.total_earned || 0).toFixed(2)),
  };
}

async function listByPassenger(passengerId, limit = 50, offset = 0) {
  return db.query(
    `
      SELECT
        b.id,
        b.status,
        b.pickup_address,
        b.pickup_lat,
        b.pickup_lng,
        b.dropoff_address,
        b.dropoff_lat,
        b.dropoff_lng,
        b.distance_km,
        b.estimated_fare,
        b.final_fare,
        b.requested_at,
        b.accepted_at,
        b.started_at,
        b.completed_at,
        b.cancelled_at,
        b.cancelled_by,
        b.passenger_count,
        u.full_name AS driver_name,
        d.tricycle_number,
        r.stars AS rating,
        r.feedback AS rating_feedback
      FROM bookings b
      LEFT JOIN drivers d ON d.id = b.driver_id
      LEFT JOIN users u ON u.id = d.user_id
      LEFT JOIN ratings r ON r.booking_id = b.id
      WHERE b.passenger_id = ?
        AND b.deleted_at IS NULL
      ORDER BY b.requested_at DESC, b.id DESC
      LIMIT ? OFFSET ?
    `,
    [passengerId, limit, offset]
  );
}

// Totals for the passenger's history header — computed over every ride,
// not just the page currently loaded.
async function getPassengerRideStats(passengerId) {
  const [row] = await db.query(
    `
      SELECT
        COUNT(*) AS total,
        COALESCE(SUM(status = 'completed'), 0) AS completed,
        COALESCE(SUM(status = 'cancelled'), 0) AS cancelled,
        COALESCE(SUM(CASE WHEN status = 'completed' THEN final_fare END), 0) AS total_spent
      FROM bookings
      WHERE passenger_id = ? AND deleted_at IS NULL
    `,
    [passengerId]
  );
  return {
    total: Number(row.total || 0),
    completed: Number(row.completed || 0),
    cancelled: Number(row.cancelled || 0),
    totalSpent: Number(Number(row.total_spent || 0).toFixed(2)),
  };
}

async function getDashboardCounts() {
  const [totalRidesRow] = await db.query("SELECT COUNT(*) AS count FROM bookings WHERE deleted_at IS NULL");
  const [dailyEarningsRow] = await db.query(
    `
      SELECT IFNULL(SUM(final_fare), 0) AS total
      FROM bookings
      WHERE status = 'completed'
        AND DATE(completed_at) = CURDATE()
        AND deleted_at IS NULL
    `
  );

  const [todayRow] = await db.query(
    `SELECT
        SUM(DATE(requested_at) = CURDATE()) AS todaysBookings,
        SUM(status = 'completed' AND DATE(requested_at) = CURDATE()) AS completedToday,
        SUM(status = 'cancelled' AND DATE(requested_at) = CURDATE()) AS cancelledToday
      FROM bookings
      WHERE deleted_at IS NULL`
  );

  return {
    totalRides: Number(totalRidesRow.count || 0),
    dailyEarnings: Number(dailyEarningsRow.total || 0),
    todaysBookings: Number(todayRow.todaysBookings || 0),
    completedRidesToday: Number(todayRow.completedToday || 0),
    cancelledRidesToday: Number(todayRow.cancelledToday || 0),
  };
}

async function getRideActivity(days = 7) {
  return db.query(
    `
      SELECT
        DATE(requested_at) AS date,
        COUNT(*) AS total,
        SUM(status = 'completed') AS completed,
        SUM(status = 'cancelled') AS cancelled,
        IFNULL(SUM(CASE WHEN status = 'completed' THEN final_fare ELSE 0 END), 0) AS earnings
      FROM bookings
      WHERE deleted_at IS NULL
        AND requested_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
      GROUP BY DATE(requested_at)
      ORDER BY date ASC
    `,
    [days]
  );
}

async function listDriverIdsWithActiveRide() {
  const rows = await db.query(
    `
      SELECT DISTINCT driver_id
      FROM bookings
      WHERE driver_id IS NOT NULL
        AND status IN ('pending', 'searching', 'accepted', 'assigned', 'arriving', 'ongoing', 'on_ride')
        AND deleted_at IS NULL
    `
  );

  return rows.map((item) => item.driver_id);
}

module.exports = {
  createBooking,
  findById,
  findActiveByPassenger,
  findActiveByDriver,
  assignDriver,
  clearAssignedDriver,
  findExpiredPendingOffers,
  verifyPickupPin,
  getPickupPinForPassenger,
  markAccepted,
  markArriving,
  markOngoing,
  markCompleted,
  markCancelled,
  releaseDriver,
  findRidesWithUnreachableDriver,
  listActiveRidesForAdmin,
  listRideHistory,
  listCompletedByDriver,
  listByPassenger,
  listHistoryByDriver,
  getDriverRideStats,
  getPassengerRideStats,
  getDashboardCounts,
  getRideActivity,
  listDriverIdsWithActiveRide,
};
