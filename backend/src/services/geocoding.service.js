// Reverse geocoding (lat/lng → short place name) via OpenStreetMap's
// Nominatim — the same service and address format the mobile app uses.
// Nominatim's usage policy: a descriptive User-Agent and at most ~1
// request/second, so calls are serialised with a gap between them.

const COORDINATE_PATTERN = /^\s*-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+\s*$/;
const MIN_GAP_MS = 1100;
const TIMEOUT_MS = 8000;

let queue = Promise.resolve();
let lastRequestAt = 0;

/** True for addresses that are just "11.10853, 125.38810". */
function isCoordinateAddress(value) {
  return value == null || String(value).trim() === "" || COORDINATE_PATTERN.test(String(value));
}

function formatAddress(data) {
  const address = data?.address;
  if (address && typeof address === "object") {
    const parts = [];
    for (const key of ["road", "neighbourhood", "suburb", "village", "town", "city"]) {
      const value = address[key];
      if (typeof value === "string" && value && !parts.includes(value)) parts.push(value);
      if (parts.length >= 2) break;
    }
    if (parts.length) return parts.join(", ");
  }
  if (typeof data?.display_name === "string" && data.display_name) {
    return data.display_name.split(",").map((s) => s.trim()).slice(0, 2).join(", ");
  }
  return null;
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
  return formatAddress(await response.json());
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
