// Guiuan's service area: the municipal boundary in
// data/service-area/guiuan.geojson (mainland and every island). One place
// for every check, and what GET /api/service-area hands the app and the
// admin dashboard.
//
// Used for bookings and saved places (when GEOFENCE_ENABLED is on) and for
// barangay pins (always). Never for SOS alerts, driver locations, or rides
// already under way.
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const booleanPointInPolygon = require("@turf/boolean-point-in-polygon").default;
const env = require("../config/env");
const ApiError = require("../utils/api-error");
const { isInsideGeofence } = require("../utils/geofence");
const defaultBarangays = require("../data/guiuan-barangays");

const BOUNDARY_FILE = path.resolve(__dirname, "../../data/service-area/guiuan.geojson");

// Map limits sent to the clients: how far past the boundary the camera may
// go, and zoom levels that keep the whole municipality (about 39 × 44 km,
// islands included) reachable without zooming out to all of Samar.
const MAP_PADDING_DEGREES = 0.04; // ~4.4 km
const MIN_ZOOM = 9.5;
const MAX_ZOOM = 19;
const DEFAULT_ZOOM = 14;

const OUTSIDE_MESSAGE = "Sorry, FindMeTricycle only operates within Guiuan.";

const raw = fs.readFileSync(BOUNDARY_FILE, "utf8");
const boundary = JSON.parse(raw);
const feature = boundary.features?.[0];
if (!feature || feature.geometry?.type !== "MultiPolygon") {
  throw new Error(`${BOUNDARY_FILE} must hold one MultiPolygon feature.`);
}
const polygons = feature.geometry.coordinates;
// Changes whenever the boundary file does, so clients know to refresh.
const version = crypto.createHash("sha1").update(raw).digest("hex").slice(0, 16);

const bbox = polygons.reduce(
  ([minLng, minLat, maxLng, maxLat], polygon) => {
    for (const [lng, lat] of polygon[0]) {
      minLng = Math.min(minLng, lng);
      minLat = Math.min(minLat, lat);
      maxLng = Math.max(maxLng, lng);
      maxLat = Math.max(maxLat, lat);
    }
    return [minLng, minLat, maxLng, maxLat];
  },
  [Infinity, Infinity, -Infinity, -Infinity]
);

const mapBounds = [
  bbox[0] - MAP_PADDING_DEGREES,
  bbox[1] - MAP_PADDING_DEGREES,
  bbox[2] + MAP_PADDING_DEGREES,
  bbox[3] + MAP_PADDING_DEGREES,
];

// The town proper: the average of the Poblacion barangay pins.
const poblacion = defaultBarangays.filter((b) => /^Poblacion/i.test(b.name));
const center = {
  lat: Number((poblacion.reduce((s, b) => s + b.lat, 0) / poblacion.length).toFixed(5)),
  lng: Number((poblacion.reduce((s, b) => s + b.lng, 0) / poblacion.length).toFixed(5)),
};

/** A finite number in range, or null (null, "", booleans and junk are rejected). */
function toCoordinate(value, limit) {
  if (value === null || value === undefined || value === "" || typeof value === "boolean") return null;
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) && Math.abs(n) <= limit ? n : null;
}

function isValidCoordinate(lat, lng) {
  return toCoordinate(lat, 90) !== null && toCoordinate(lng, 180) !== null;
}

// Shortest distance (metres) from the point to the boundary's edges.
// Local flat-earth scaling is accurate to well under a metre at this size.
function distanceToBoundaryMeters(lat, lng) {
  const kx = 111320 * Math.cos((lat * Math.PI) / 180);
  const ky = 110540;
  let best = Infinity;
  for (const polygon of polygons) {
    for (const ring of polygon) {
      for (let i = 1; i < ring.length; i += 1) {
        const ax = (ring[i - 1][0] - lng) * kx;
        const ay = (ring[i - 1][1] - lat) * ky;
        const bx = (ring[i][0] - lng) * kx;
        const by = (ring[i][1] - lat) * ky;
        const dx = bx - ax;
        const dy = by - ay;
        const t = Math.max(0, Math.min(1, -(ax * dx + ay * dy) / (dx * dx + dy * dy || 1)));
        best = Math.min(best, Math.hypot(ax + t * dx, ay + t * dy));
      }
    }
  }
  return best;
}

/**
 * Whether a point is inside Guiuan, counting points within [bufferMeters]
 * of the boundary as inside (GPS error along borders and coastlines).
 * Invalid coordinates are never inside.
 */
function isInsideServiceArea(lat, lng, { bufferMeters = env.geofence.bufferMeters } = {}) {
  const la = toCoordinate(lat, 90);
  const ln = toCoordinate(lng, 180);
  if (la === null || ln === null) return false;

  // Quick rejection far outside: the buffer, in degrees, generously.
  const pad = bufferMeters / 100000;
  if (ln < bbox[0] - pad || ln > bbox[2] + pad || la < bbox[1] - pad || la > bbox[3] + pad) return false;

  if (booleanPointInPolygon([ln, la], feature)) return true;
  return bufferMeters > 0 && distanceToBoundaryMeters(la, ln) <= bufferMeters;
}

// The configured check: Guiuan's boundary, or the older radius.
function isBookableLocation(lat, lng) {
  return env.geofence.mode === "radius" ? isInsideGeofence(Number(lat), Number(lng)) : isInsideServiceArea(lat, lng);
}

/**
 * Pickup and drop-off must both be inside the service area (when
 * GEOFENCE_ENABLED is on). Throws in the API's error format, saying which
 * point is outside.
 */
function assertBookingInsideServiceArea({ pickupLat, pickupLng, dropoffLat, dropoffLng }) {
  if (!env.geofence.enabled) return;
  if (!isBookableLocation(pickupLat, pickupLng)) {
    throw new ApiError(403, `${OUTSIDE_MESSAGE} Please choose a pickup point inside Guiuan.`, {
      code: "OUTSIDE_SERVICE_AREA",
      point: "pickup",
    });
  }
  if (!isBookableLocation(dropoffLat, dropoffLng)) {
    throw new ApiError(403, `${OUTSIDE_MESSAGE} Please choose a destination inside Guiuan.`, {
      code: "OUTSIDE_SERVICE_AREA",
      point: "dropoff",
    });
  }
}

/** A saved place must be somewhere a ride can go (when GEOFENCE_ENABLED is on). */
function assertPlaceInsideServiceArea(lat, lng) {
  if (!env.geofence.enabled) return;
  if (!isBookableLocation(lat, lng)) {
    throw new ApiError(403, `${OUTSIDE_MESSAGE} This place can't be saved.`, { code: "OUTSIDE_SERVICE_AREA" });
  }
}

/** Barangay pins belong inside Guiuan's boundary — always checked, no buffer. */
function assertPinInsideBoundary(lat, lng) {
  if (!isInsideServiceArea(lat, lng, { bufferMeters: 0 })) {
    throw new ApiError(400, "The pin must be inside Guiuan's boundary.", { code: "OUTSIDE_SERVICE_AREA" });
  }
}

/** What GET /api/service-area returns. Nothing in it is sensitive. */
function describeServiceArea() {
  return {
    version,
    name: feature.properties?.name || "Guiuan, Eastern Samar",
    enforced: env.geofence.enabled,
    mode: env.geofence.mode,
    bufferMeters: env.geofence.bufferMeters,
    bbox,
    mapBounds,
    center,
    minZoom: MIN_ZOOM,
    maxZoom: MAX_ZOOM,
    defaultZoom: DEFAULT_ZOOM,
    attribution: "Boundary © PSA / NAMRIA",
    boundary: feature,
  };
}

module.exports = {
  OUTSIDE_MESSAGE,
  version,
  isValidCoordinate,
  isInsideServiceArea,
  distanceToBoundaryMeters,
  assertBookingInsideServiceArea,
  assertPlaceInsideServiceArea,
  assertPinInsideBoundary,
  describeServiceArea,
};
