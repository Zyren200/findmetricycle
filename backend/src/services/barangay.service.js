const db = require("../config/db");
const ApiError = require("../utils/api-error");
const { haversineKm } = require("../utils/haversine");
const defaultBarangays = require("../data/guiuan-barangays");

// A point is matched to the barangay with the nearest pin. Beyond this
// distance from every pin it's treated as outside the mapped barangays
// (open sea, the next town) and isn't blocked here — the optional geofence
// is what limits the service area as a whole.
const MAX_PIN_DISTANCE_KM = 4;
const CACHE_MS = 30 * 1000;

let cache = null;
let cacheLoadedAt = 0;
let warnedMissingColumns = false;

function invalidateCache() {
  cache = null;
}

/**
 * Makes sure every Guiuan barangay exists and has a pin. Runs on server
 * start; never overwrites a pin an admin has moved.
 */
async function syncDefaultBarangays() {
  const placeholders = defaultBarangays.map(() => "(?, ?, ?)").join(", ");
  const params = defaultBarangays.flatMap((b) => [b.name, b.lat, b.lng]);
  try {
    await db.query(
      `INSERT INTO barangays (name, lat, lng) VALUES ${placeholders}
       ON DUPLICATE KEY UPDATE
         lat = COALESCE(barangays.lat, VALUES(lat)),
         lng = COALESCE(barangays.lng, VALUES(lng))`,
      params
    );
    invalidateCache();
  } catch (error) {
    if (error.code === "ER_BAD_FIELD_ERROR") {
      console.warn("Barangay pins are missing — run `npm run migrate` to enable barangay coverage.");
      return;
    }
    throw error;
  }
}

async function loadBarangays() {
  if (cache && Date.now() - cacheLoadedAt < CACHE_MS) return cache;
  try {
    const rows = await db.query(
      "SELECT id, name, is_enabled, lat, lng FROM barangays WHERE deleted_at IS NULL"
    );
    cache = rows.map((row) => ({
      id: row.id,
      name: row.name,
      isEnabled: Boolean(row.is_enabled),
      lat: row.lat == null ? null : Number(row.lat),
      lng: row.lng == null ? null : Number(row.lng),
    }));
  } catch (error) {
    // Database not migrated yet: don't take booking down over coverage.
    if (error.code !== "ER_BAD_FIELD_ERROR") throw error;
    if (!warnedMissingColumns) {
      warnedMissingColumns = true;
      console.warn("Barangay coverage is off until `npm run migrate` adds the lat/lng columns.");
    }
    cache = [];
  }
  cacheLoadedAt = Date.now();
  return cache;
}

/** The barangay whose pin is nearest to the point, or null if none is close. */
async function findBarangayAt(lat, lng) {
  const latitude = Number(lat);
  const longitude = Number(lng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;

  let nearest = null;
  let nearestKm = Infinity;
  for (const barangay of await loadBarangays()) {
    if (barangay.lat == null || barangay.lng == null) continue;
    const km = haversineKm(latitude, longitude, barangay.lat, barangay.lng);
    if (km < nearestKm) {
      nearest = barangay;
      nearestKm = km;
    }
  }
  return nearestKm <= MAX_PIN_DISTANCE_KM ? nearest : null;
}

/** Refuses a booking whose pickup or drop-off is in a disabled barangay. */
async function assertBookableLocations({ pickupLat, pickupLng, dropoffLat, dropoffLng }) {
  const pickup = await findBarangayAt(pickupLat, pickupLng);
  if (pickup && !pickup.isEnabled) {
    throw new ApiError(403, `Rides can't be booked from ${pickup.name} right now. Please choose another pickup point.`, {
      code: "BARANGAY_DISABLED",
      point: "pickup",
      barangay: pickup.name,
    });
  }
  const dropoff = await findBarangayAt(dropoffLat, dropoffLng);
  if (dropoff && !dropoff.isEnabled) {
    throw new ApiError(403, `Rides to ${dropoff.name} aren't available right now. Please choose another destination.`, {
      code: "BARANGAY_DISABLED",
      point: "dropoff",
      barangay: dropoff.name,
    });
  }
}

async function listDisabledBarangayNames() {
  return (await loadBarangays())
    .filter((b) => !b.isEnabled)
    .map((b) => b.name)
    .sort((a, b) => a.localeCompare(b));
}

module.exports = {
  MAX_PIN_DISTANCE_KM,
  syncDefaultBarangays,
  findBarangayAt,
  assertBookableLocations,
  listDisabledBarangayNames,
  invalidateCache,
};
