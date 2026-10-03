const db = require("../config/db");
const ApiError = require("../utils/api-error");

// Operating hours are local Guiuan time, whatever timezone the server runs in.
const SERVICE_TIMEZONE = "Asia/Manila";
const CACHE_MS = 30 * 1000;

const DEFAULTS = {
  appName: "FindMeTricycle",
  supportEmail: "",
  contactNumber: "",
  operatingHoursStart: "05:00",
  operatingHoursEnd: "22:00",
  enforceOperatingHours: false,
};

const SETTING_TYPES = {
  appName: "string",
  supportEmail: "string",
  contactNumber: "string",
  operatingHoursStart: "string",
  operatingHoursEnd: "string",
  enforceOperatingHours: "boolean",
};

let cache = null;
let cacheLoadedAt = 0;

function invalidateCache() {
  cache = null;
}

/** "5:00 AM" / "17:30" → "HH:MM" (24h), or null. */
function toHHMM(text) {
  const match = String(text || "").trim().match(/^(\d{1,2}):(\d{2})\s*([ap]\.?m\.?)?$/i);
  if (!match) return null;
  let hours = Number(match[1]);
  const minutes = Number(match[2]);
  const meridiem = match[3]?.[0]?.toLowerCase();
  if (meridiem === "p" && hours < 12) hours += 12;
  if (meridiem === "a" && hours === 12) hours = 0;
  if (hours > 23 || minutes > 59) return null;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`;
}

function toMinutes(hhmm) {
  const [hours, minutes] = hhmm.split(":").map(Number);
  return hours * 60 + minutes;
}

function formatTime(hhmm) {
  const [hours, minutes] = hhmm.split(":").map(Number);
  const suffix = hours < 12 ? "AM" : "PM";
  return `${hours % 12 || 12}:${String(minutes).padStart(2, "0")} ${suffix}`;
}

function minutesNowInServiceArea(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: SERVICE_TIMEZONE,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(now);
  const value = (type) => Number(parts.find((part) => part.type === type)?.value || 0);
  return value("hour") * 60 + value("minute");
}

/** Same start and end means open all day; end before start runs past midnight. */
function isWithinHours(start, end, now = new Date()) {
  const current = minutesNowInServiceArea(now);
  const from = toMinutes(start);
  const to = toMinutes(end);
  if (from === to) return true;
  if (from < to) return current >= from && current < to;
  return current >= from || current < to;
}

async function getSettings() {
  if (cache && Date.now() - cacheLoadedAt < CACHE_MS) return cache;

  const rows = await db.query(
    "SELECT setting_key, setting_value FROM system_settings WHERE deleted_at IS NULL"
  );
  const raw = Object.fromEntries(rows.map((row) => [row.setting_key, row.setting_value]));

  // Older saves stored hours as free text ("5:00 AM - 10:00 PM").
  const [legacyStart, legacyEnd] = String(raw.operatingHours || "").split(/\s*[-–]\s*/);

  cache = {
    appName: raw.appName || DEFAULTS.appName,
    supportEmail: raw.supportEmail || DEFAULTS.supportEmail,
    contactNumber: raw.contactNumber || DEFAULTS.contactNumber,
    operatingHoursStart:
      toHHMM(raw.operatingHoursStart) || toHHMM(legacyStart) || DEFAULTS.operatingHoursStart,
    operatingHoursEnd: toHHMM(raw.operatingHoursEnd) || toHHMM(legacyEnd) || DEFAULTS.operatingHoursEnd,
    enforceOperatingHours: raw.enforceOperatingHours === "true" || raw.enforceOperatingHours === "1",
  };
  cacheLoadedAt = Date.now();
  return cache;
}

async function updateSettings(settings, adminUserId) {
  for (const [key, type] of Object.entries(SETTING_TYPES)) {
    await db.query(
      `INSERT INTO system_settings (setting_key, setting_value, value_type, updated_by)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         setting_value = VALUES(setting_value),
         value_type = VALUES(value_type),
         updated_by = VALUES(updated_by),
         deleted_at = NULL,
         updated_at = NOW()`,
      [key, String(settings[key]), type, adminUserId]
    );
  }
  // The free-text value is superseded by the start/end pair.
  await db.query(
    "UPDATE system_settings SET deleted_at = NOW() WHERE setting_key = 'operatingHours' AND deleted_at IS NULL"
  );

  await db.query(
    `INSERT INTO activity_logs (admin_id, admin_name, action, target_type, metadata_json)
     VALUES (?, (SELECT full_name FROM users WHERE id = ?), ?, ?, ?)`,
    [adminUserId, adminUserId, "System Settings Updated", "settings", JSON.stringify(settings)]
  );

  invalidateCache();
  return getSettings();
}

function operatingHoursView(settings, now = new Date()) {
  return {
    start: settings.operatingHoursStart,
    end: settings.operatingHoursEnd,
    label: `${formatTime(settings.operatingHoursStart)} – ${formatTime(settings.operatingHoursEnd)}`,
    enforced: settings.enforceOperatingHours,
    isOpenNow: isWithinHours(settings.operatingHoursStart, settings.operatingHoursEnd, now),
  };
}

/** Refuses new bookings outside operating hours, when the admin turned that on. */
async function assertOpenForBooking(now = new Date()) {
  const settings = await getSettings();
  if (!settings.enforceOperatingHours) return;
  const hours = operatingHoursView(settings, now);
  if (!hours.isOpenNow) {
    throw new ApiError(403, `Bookings are only available from ${hours.label}. Please try again later.`, {
      code: "OUTSIDE_OPERATING_HOURS",
    });
  }
}

/** What the apps show users: support contacts and service hours. */
async function getPublicConfig() {
  const settings = await getSettings();
  return {
    appName: settings.appName,
    supportEmail: settings.supportEmail,
    contactNumber: settings.contactNumber,
    operatingHours: operatingHoursView(settings),
  };
}

module.exports = {
  invalidateCache,
  getSettings,
  updateSettings,
  getPublicConfig,
  assertOpenForBooking,
  isWithinHours,
  toHHMM,
};
