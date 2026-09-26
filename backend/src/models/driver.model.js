const db = require("../config/db");

async function createDriverProfile(payload, client = db) {
  const result = await client.query(
    `
      INSERT INTO drivers
      (
        user_id,
        tricycle_number,
        license_image_url,
        business_permit_image_url,
        business_permit_expires_at,
        license_expires_at,
        license_number,
        license_holder_name,
        license_ocr_text,
        approval_status
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
    `,
    [
      payload.userId,
      payload.tricycleNumber,
      payload.licenseImageUrl,
      payload.businessPermitImageUrl,
      payload.businessPermitExpiresAt || null,
      payload.licenseExpiresAt || null,
      payload.licenseNumber || null,
      payload.licenseHolderName || null,
      payload.licenseOcrText || null,
    ]
  );

  return findById(result.insertId, client);
}

async function findById(driverId, client = db) {
  const rows = await client.query(
    `
      SELECT d.*, u.full_name, u.phone, u.email, u.status AS user_status
      FROM drivers d
      JOIN users u ON u.id = d.user_id
      WHERE d.id = ?
        AND d.deleted_at IS NULL
        AND u.deleted_at IS NULL
      LIMIT 1
    `,
    [driverId]
  );
  return rows[0] || null;
}

async function findByUserId(userId, client = db) {
  const rows = await client.query(
    `
      SELECT d.*, u.full_name, u.phone, u.email, u.status AS user_status
      FROM drivers d
      JOIN users u ON u.id = d.user_id
      WHERE d.user_id = ?
        AND d.deleted_at IS NULL
        AND u.deleted_at IS NULL
      LIMIT 1
    `,
    [userId]
  );
  return rows[0] || null;
}

async function listPending() {
  return db.query(
    `
      SELECT
        d.id,
        d.user_id,
        u.full_name,
        u.phone,
        u.email,
        d.tricycle_number,
        d.license_image_url,
        d.business_permit_image_url,
        d.license_expires_at,
        d.created_at
      FROM drivers d
      JOIN users u ON u.id = d.user_id
      WHERE d.approval_status = 'pending'
        AND d.deleted_at IS NULL
        AND u.deleted_at IS NULL
      ORDER BY d.created_at ASC
    `
  );
}

async function findByTricycleNumber(tricycleNumber) {
  const rows = await db.query("SELECT * FROM drivers WHERE tricycle_number = ? AND deleted_at IS NULL LIMIT 1", [
    tricycleNumber,
  ]);
  return rows[0] || null;
}

async function approveDriver(driverId, adminUserId, client = db) {
  await client.query(
    `
      UPDATE drivers
      SET approval_status = 'approved',
          approved_by = ?,
          approved_at = NOW(),
          rejection_reason = NULL
      WHERE id = ?
    `,
    [adminUserId, driverId]
  );

  await client.query(
    `
      UPDATE users u
      JOIN drivers d ON d.user_id = u.id
      SET u.status = 'active'
      WHERE d.id = ?
    `,
    [driverId]
  );

  return findById(driverId, client);
}

async function rejectDriver(driverId, adminUserId, rejectionReason, client = db) {
  await client.query(
    `
      UPDATE drivers
      SET approval_status = 'rejected',
          approved_by = ?,
          approved_at = NOW(),
          rejection_reason = ?
      WHERE id = ?
    `,
    [adminUserId, rejectionReason || null, driverId]
  );

  await client.query(
    `
      UPDATE users u
      JOIN drivers d ON d.user_id = u.id
      SET u.status = 'rejected'
      WHERE d.id = ?
    `,
    [driverId]
  );

  return findById(driverId, client);
}

async function setOnlineStatus(driverId, isOnline) {
  await db.query("UPDATE drivers SET is_online = ? WHERE id = ?", [isOnline ? 1 : 0, driverId]);
}

async function updateLocation(driverId, lat, lng) {
  await db.query(
    `
      UPDATE drivers
      SET current_lat = ?, current_lng = ?, last_location_update = NOW()
      WHERE id = ?
    `,
    [lat, lng, driverId]
  );
}

// A driver's client is supposed to set is_online back to false the moment
// they go offline (toggle, switch to Passenger Mode, logout) — but a
// killed app, closed browser tab, or dropped connection means that never
// happens. A genuinely active driver pushes a location update every ~4s
// (see mobile driver_ride_controller.dart), so anyone whose last update is
// older than this treated as effectively offline for matching purposes,
// regardless of what is_online still says in the DB.
const STALE_LOCATION_SECONDS = 60;

async function getApprovedOnlineDriversWithLocation() {
  return db.query(
    `
      SELECT d.*, u.full_name
      FROM drivers d
      JOIN users u ON u.id = d.user_id
      WHERE d.approval_status = 'approved'
        AND d.is_online = 1
        AND d.current_lat IS NOT NULL
        AND d.current_lng IS NOT NULL
        AND d.last_location_update >= DATE_SUB(NOW(), INTERVAL ${STALE_LOCATION_SECONDS} SECOND)
        AND d.deleted_at IS NULL
        AND u.deleted_at IS NULL
    `
  );
}

async function addEarningsAndRideCount(driverId, amount, client = db) {
  await client.query(
    `
      UPDATE drivers
      SET total_rides = total_rides + 1,
          total_earnings = total_earnings + ?
      WHERE id = ?
    `,
    [amount, driverId]
  );
}

async function refreshDriverRating(driverId) {
  const rows = await db.query(
    `
      SELECT AVG(stars) AS avg_stars
      FROM ratings
      WHERE driver_id = ?
    `,
    [driverId]
  );

  const avg = rows[0]?.avg_stars ? Number(rows[0].avg_stars) : 5;
  await db.query("UPDATE drivers SET rating_avg = ? WHERE id = ?", [Number(avg.toFixed(2)), driverId]);
}

const EARNINGS_CHART_DAYS = 7;

// Earnings are computed from the completed bookings themselves (the source
// of truth) rather than the drivers.total_earnings running counter, which
// drifts whenever a credit is missed or doubled. Periods use the database
// clock, the same one that stamps completed_at.
async function getEarningsSummary(driverId) {
  const [driver] = await db.query("SELECT id, rating_avg FROM drivers WHERE id = ? LIMIT 1", [driverId]);
  if (!driver) return null;

  const [totals] = await db.query(
    `
      SELECT
        COUNT(*) AS total_rides,
        COALESCE(SUM(final_fare), 0) AS total_earnings,
        COALESCE(SUM(CASE WHEN completed_at >= CURDATE() THEN 1 END), 0) AS today_rides,
        COALESCE(SUM(CASE WHEN completed_at >= CURDATE() THEN final_fare END), 0) AS today_earnings,
        COALESCE(SUM(CASE WHEN completed_at >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY) THEN 1 END), 0) AS week_rides,
        COALESCE(SUM(CASE WHEN completed_at >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY) THEN final_fare END), 0) AS week_earnings,
        COALESCE(SUM(CASE WHEN completed_at >= DATE_FORMAT(CURDATE(), '%Y-%m-01') THEN 1 END), 0) AS month_rides,
        COALESCE(SUM(CASE WHEN completed_at >= DATE_FORMAT(CURDATE(), '%Y-%m-01') THEN final_fare END), 0) AS month_earnings
      FROM bookings
      WHERE driver_id = ? AND status = 'completed' AND deleted_at IS NULL
    `,
    [driverId]
  );

  const dailyRows = await db.query(
    `
      SELECT DATE_FORMAT(completed_at, '%Y-%m-%d') AS day,
             COUNT(*) AS rides,
             COALESCE(SUM(final_fare), 0) AS earnings
      FROM bookings
      WHERE driver_id = ? AND status = 'completed' AND deleted_at IS NULL
        AND completed_at >= DATE_SUB(CURDATE(), INTERVAL ${EARNINGS_CHART_DAYS - 1} DAY)
      GROUP BY day
    `,
    [driverId]
  );
  const [{ today }] = await db.query("SELECT DATE_FORMAT(CURDATE(), '%Y-%m-%d') AS today");

  // One entry per day (oldest first), including days with no trips.
  const byDay = new Map(dailyRows.map((r) => [r.day, r]));
  const daily = [];
  for (let offset = EARNINGS_CHART_DAYS - 1; offset >= 0; offset -= 1) {
    const date = new Date(`${today}T00:00:00Z`);
    date.setUTCDate(date.getUTCDate() - offset);
    const day = date.toISOString().slice(0, 10);
    const row = byDay.get(day);
    daily.push({
      date: day,
      rides: Number(row?.rides || 0),
      earnings: Number(Number(row?.earnings || 0).toFixed(2)),
    });
  }

  const money = (v) => Number(Number(v || 0).toFixed(2));
  return {
    id: driver.id,
    rating_avg: Number(driver.rating_avg || 0),
    total_rides: Number(totals.total_rides || 0),
    total_earnings: money(totals.total_earnings),
    today: { rides: Number(totals.today_rides), earnings: money(totals.today_earnings) },
    week: { rides: Number(totals.week_rides), earnings: money(totals.week_earnings) },
    month: { rides: Number(totals.month_rides), earnings: money(totals.month_earnings) },
    daily,
  };
}

// Cancellation rate here means "of the bookings this driver was assigned
// to (i.e. actually accepted), what share ended up cancelled by the
// passenger" — bookings.driver_id is cleared on decline/reassignment, so
// there's no record of offers the driver never accepted; a true
// offer-level acceptance rate would need a separate event log, which
// doesn't exist yet.
async function getPerformanceStats(driverId) {
  const [counts] = await db.query(
    `
      SELECT
        SUM(status = 'completed') AS completed,
        SUM(status = 'cancelled') AS cancelled
      FROM bookings
      WHERE driver_id = ? AND deleted_at IS NULL
    `,
    [driverId]
  );

  const [ratingCounts] = await db.query(
    `
      SELECT
        COUNT(*) AS totalRatings,
        SUM(stars = 5) AS fiveStarRatings
      FROM ratings
      WHERE driver_id = ?
    `,
    [driverId]
  );

  const completed = Number(counts?.completed || 0);
  const cancelled = Number(counts?.cancelled || 0);
  const totalAssigned = completed + cancelled;

  return {
    completedRides: completed,
    cancelledRides: cancelled,
    cancellationRate: totalAssigned > 0 ? Number(((cancelled / totalAssigned) * 100).toFixed(1)) : 0,
    totalRatings: Number(ratingCounts?.totalRatings || 0),
    fiveStarRatings: Number(ratingCounts?.fiveStarRatings || 0),
  };
}

async function getProfileByUserId(userId) {
  const rows = await db.query(
    `
      SELECT
        d.id,
        d.user_id,
        u.full_name,
        u.phone,
        u.email,
        u.profile_image_url,
        u.status AS user_status,
        d.tricycle_number,
        d.approval_status,
        d.rating_avg,
        d.total_rides,
        d.total_earnings,
        d.is_online,
        d.current_lat,
        d.current_lng,
        d.last_location_update,
        d.license_expires_at,
        d.license_status,
        d.business_permit_expires_at,
        d.created_at
      FROM drivers d
      JOIN users u ON u.id = d.user_id
      WHERE d.user_id = ?
        AND d.deleted_at IS NULL
        AND u.deleted_at IS NULL
      LIMIT 1
    `,
    [userId]
  );
  return rows[0] || null;
}

async function updateProfile(driverId, payload) {
  const fields = [];
  const values = [];

  if (Object.prototype.hasOwnProperty.call(payload, "tricycleNumber")) {
    fields.push("tricycle_number = ?");
    values.push(payload.tricycleNumber);
  }

  if (fields.length === 0) {
    return findById(driverId);
  }

  values.push(driverId);
  await db.query(`UPDATE drivers SET ${fields.join(", ")} WHERE id = ?`, values);
  return findById(driverId);
}

async function listOnlineDriversForAdmin() {
  return db.query(
    `
      SELECT
        d.id,
        d.user_id,
        u.full_name,
        d.tricycle_number,
        d.current_lat,
        d.current_lng,
        d.last_location_update,
        d.rating_avg
      FROM drivers d
      JOIN users u ON u.id = d.user_id
      WHERE d.approval_status = 'approved'
        AND d.is_online = 1
        AND d.deleted_at IS NULL
        AND u.deleted_at IS NULL
    `
  );
}

async function listAllForAdmin() {
  return db.query(
    `
      SELECT
        d.id,
        d.user_id,
        u.full_name,
        u.phone,
        u.email,
        u.status as user_status,
        d.tricycle_number,
        d.approval_status,
        d.license_expires_at,
        d.license_number,
        d.license_holder_name,
        d.license_image_url,
        d.business_permit_image_url,
        d.is_online,
        d.current_lat,
        d.current_lng,
        d.rating_avg,
        d.total_rides,
        d.total_earnings,
        d.created_at
      FROM drivers d
      JOIN users u ON u.id = d.user_id
      WHERE d.deleted_at IS NULL
        AND u.deleted_at IS NULL
      ORDER BY d.created_at DESC
    `
  );
}

async function suspendDriver(driverId, adminUserId, client = db) {
    await client.query(
      `
        UPDATE users u
        JOIN drivers d ON d.user_id = u.id
        SET u.status = 'suspended', d.approval_status = 'suspended', d.is_online = 0
        WHERE d.id = ?
      `,
      [driverId]
    );

    await client.query(`UPDATE drivers SET is_online = 0 WHERE id = ?`, [driverId]);
  }

  async function reinstateDriver(driverId, adminUserId, client = db) {
    await client.query(
      `
        UPDATE users u
        JOIN drivers d ON d.user_id = u.id
        SET u.status = 'active', d.approval_status = 'approved'
        WHERE d.id = ?
      `,
      [driverId]
    );
  }

  async function listDriversWithExpiringLicenses(days = 30) {
    // returns drivers whose license_expires_at is within the next `days` days
    return db.query(
      `
        SELECT d.id, d.user_id, u.full_name, u.phone, d.license_image_url, d.license_expires_at
        FROM drivers d
        JOIN users u ON u.id = d.user_id
        WHERE d.license_expires_at IS NOT NULL
          AND d.license_expires_at <= DATE_ADD(NOW(), INTERVAL ? DAY)
          AND d.deleted_at IS NULL
          AND u.deleted_at IS NULL
        ORDER BY d.license_expires_at ASC
      `,
      [Number(days)]
    );
  }

module.exports = {
  createDriverProfile,
  findById,
  findByUserId,
  findByTricycleNumber,
  listPending,
  approveDriver,
  rejectDriver,
  setOnlineStatus,
  updateLocation,
  getApprovedOnlineDriversWithLocation,
  addEarningsAndRideCount,
  refreshDriverRating,
  getEarningsSummary,
  getPerformanceStats,
  getProfileByUserId,
  updateProfile,
  listOnlineDriversForAdmin,
  listAllForAdmin,
  suspendDriver,
  reinstateDriver,
  listDriversWithExpiringLicenses,
};
