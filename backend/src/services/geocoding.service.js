// Reverse geocoding (lat/lng → readable address) via OpenStreetMap's
// Nominatim — the same service and address format the mobile app uses
// (mobile_app/lib/core/utils/geocoding.dart): landmark or street, purok,
// barangay, town, province. Nominatim's usage policy: a descriptive
// User-Agent and at most ~1 request/second, so calls are serialised with a
// gap between them.

const { isInsideServiceArea } = require("./service-area.service");

const COORDINATE_PATTERN = /^\s*-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+\s*$/;
const MIN_GAP_MS = 1100;
const TIMEOUT_MS = 8000;

let queue = Promise.resolve();
let lastRequestAt = 0;

/** True for addresses that are just "11.10853, 125.38810". */
function isCoordinateAddress(value) {
  return value == null || String(value).trim() === "" || COORDINATE_PATTERN.test(String(value));
}

// OSM maps Guiuan's rural barangays without their municipality.
const SERVICE_AREA_TOWN = "Guiuan";

// Named grounds a point can be inside (a wharf, a school campus).
const LANDMARK_KEYS = [
  "amenity", "shop", "tourism", "leisure", "office", "building",
  "industrial", "commercial", "retail", "aeroway", "man_made", "historic",
];

const BARANGAY_PREFIX = /^(brgy\.?|barangay)\s+/i;

function text(value) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function first(address, keys) {
  for (const key of keys) {
    const value = text(address[key]);
    if (value) return value;
  }
  return null;
}

/**
 * "Guimbaolibot Avenue, Brgy. Poblacion Ward 9-A, Guiuan, Eastern Samar"
 * from a Nominatim jsonv2 reverse result, or null. In the Philippines OSM
 * tags barangays as villages (quarters in the poblacion), puroks and sitios
 * as hamlets or neighbourhoods, and the province as the state.
 */
function formatAddress(data, { fallbackTown = null } = {}) {
  const address = data?.address;
  if (!address || typeof address !== "object") return null;

  let street = first(address, ["road", "pedestrian", "footway", "path"]);
  const houseNumber = text(address.house_number);
  if (street && houseNumber) street = `${houseNumber} ${street}`;

  // The point itself is a named spot unless it's just a road or an area
  // (barangay, town), which the other parts already name.
  const landmark =
    (["place", "boundary", "highway"].includes(data.category)
      ? null
      : text(data.name) || text(address[data.addresstype])) || first(address, LANDMARK_KEYS);

  // Inside a rural barangay a "quarter" is one of its sitios; in the
  // poblacion, with no village around it, the quarter is the barangay.
  const village = text(address.village);
  const quarter = text(address.quarter);
  const purok =
    first(address, ["hamlet", "neighbourhood", "isolated_dwelling", "croft"]) || (village ? quarter : null);
  const barangay = village || quarter || first(address, ["suburb", "city_district"]);
  const town = first(address, ["town", "city", "municipality"]) || fallbackTown;
  const province = first(address, ["province", "state"]);

  const parts = [];
  const seen = new Set();
  const add = (value, prefix = "") => {
    if (!value) return;
    const key = value.replace(BARANGAY_PREFIX, "").toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    parts.push(BARANGAY_PREFIX.test(value) ? value : prefix + value);
  };
  add(landmark);
  add(street);
  add(purok);
  add(barangay, "Brgy. ");
  add(town);
  add(province);
  return parts.length ? parts.join(", ") : null;
}

async function lookup(lat, lng) {
  const wait = lastRequestAt + MIN_GAP_MS - Date.now();
  if (wait > 0) await new Promise((resolve) => setTimeout(resolve, wait));
  lastRequestAt = Date.now();

  const url = new URL("https://nominatim.openstreetmap.org/reverse");
  url.search = new URLSearchParams({
    format: "jsonv2",
    lat: String(lat),
    lon: String(lng),
    zoom: "18",
    addressdetails: "1",
  }).toString();

  const response = await fetch(url, {
    headers: { "User-Agent": "FindMeTricycle/1.0 (backend)", "Accept-Language": "en" },
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok) return null;
  const fallbackTown = isInsideServiceArea(lat, lng) ? SERVICE_AREA_TOWN : null;
  return formatAddress(await response.json(), { fallbackTown });
}

/** Place name for a point, or null if it can't be found (never throws). */
function reverseGeocode(lat, lng) {
  const latitude = Number(lat);
  const longitude = Number(lng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return Promise.resolve(null);
  const result = queue.then(() => lookup(latitude, longitude)).catch(() => null);
  queue = result.then(() => undefined);
  return result;
}

module.exports = { reverseGeocode, isCoordinateAddress, formatAddress };
