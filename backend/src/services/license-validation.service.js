const ApiError = require("../utils/api-error");

function normalizeText(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ");
}

function isNameCompatible(expectedName, extractedName) {
  const expected = normalizeText(expectedName);
  const extracted = normalizeText(extractedName);

  if (!expected || !extracted) {
    return false;
  }

  if (expected === extracted) {
    return true;
  }

  const expectedParts = expected.split(" ").filter(Boolean);
  const extractedParts = extracted.split(" ").filter(Boolean);

  return expectedParts.every((part) => extracted.includes(part)) ||
    extractedParts.every((part) => expected.includes(part));
}

function parseDate(value) {
  if (!value) {
    return null;
  }

  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

// PH LTO license numbers are commonly formatted like "H04-23-001476" — a
// letter/digit prefix, two dash-separated groups. Checked with a strict
// pattern first since it's unambiguous; a looser one is the fallback for
// other formats.
const LICENSE_NUMBER_PH_PATTERN = /\b([A-Z]\d{2}-\d{2}-\d{6})\b/;
const LICENSE_NUMBER_LABEL_PATTERN =
  /(?:license\s*(?:no|number|#)|lic(?:ense)?\s*#)\s*[:-]?\s*([A-Z][A-Z0-9]{0,2}\d{2}-\d{2}-\d{6}|[A-Z0-9]{4,}-?[A-Z0-9]{0,12})/i;

// PH licenses commonly print "LASTNAME, FIRSTNAME MIDDLENAME" — all caps —
// on its own line, distinct from the (mixed-case) "Last Name, First Name"
// header line above it. Checking this first avoids matching the header.
const LAST_FIRST_NAME_PATTERN = /^[A-Z][A-Z .'-]{2,},\s*[A-Z][A-Za-z .'-]{2,}$/;
const NAME_LABEL_PATTERN = /(?:name|holder)\s*[:-]\s*([A-Za-z ,.'-]{3,120})/i;

function extractLicenseSignals(ocrText) {
  const text = String(ocrText || "");
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  const nameLine = lines.find((line) => LAST_FIRST_NAME_PATTERN.test(line));
  const nameMatch = nameLine || text.match(NAME_LABEL_PATTERN)?.[1];

  const numberMatch =
    text.match(LICENSE_NUMBER_PH_PATTERN)?.[1] ||
    text.match(LICENSE_NUMBER_LABEL_PATTERN)?.[1];

  return {
    licenseHolderName: nameMatch ? nameMatch.trim() : null,
    licenseNumber: numberMatch ? numberMatch.trim().toUpperCase() : null,
  };
}

const EXPIRY_LABEL_WORDS = /expiration date|expiry date|expiry|expires|exp date/i;
const BIRTH_LABEL_WORDS = /date of birth|birth date|birthdate|dob/i;
const ANY_DATE_PATTERN = /\b(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{2,4})\b/;

/**
 * Finds the line containing labelWords, then looks for the first
 * date-shaped token on that same line or the next couple of lines — PH LTO
 * cards print field headers on one row and values on the row(s) below (a
 * table layout), so a same-line "label immediately followed by date" check
 * never matches, and falling back to "any date anywhere in the text" risks
 * picking up an unrelated date (e.g. birth date read as the expiry date).
 */
function findDateNearLabel(lines, labelWords, lookaheadLines = 2) {
  for (let i = 0; i < lines.length; i++) {
    if (!labelWords.test(lines[i])) continue;
    for (let j = i; j <= i + lookaheadLines && j < lines.length; j++) {
      const match = lines[j].match(ANY_DATE_PATTERN);
      if (match) return match[1];
    }
  }
  return null;
}

/**
 * Best-effort scan for an expiry date inside raw OCR text. This is a
 * screening signal only — never used to auto-approve/reject an application,
 * per the driver-verification guiding principle (admin has final authority).
 */
function extractExpiryDate(ocrText) {
  const text = String(ocrText || "");
  const lines = text.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  const raw = findDateNearLabel(lines, EXPIRY_LABEL_WORDS);
  return parseDate(raw);
}

/**
 * Same proximity-based read, but for the birth date field — kept separate
 * from expiry so the two never get confused with each other.
 */
function extractBirthDate(ocrText) {
  const text = String(ocrText || "");
  const lines = text.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  const raw = findDateNearLabel(lines, BIRTH_LABEL_WORDS);
  return parseDate(raw);
}

function classifyExpiry(expiryDate, { expiringSoonDays = 30 } = {}) {
  if (!expiryDate) return "unable_to_determine";
  const now = new Date();
  const msPerDay = 24 * 60 * 60 * 1000;
  const daysUntilExpiry = (expiryDate.getTime() - now.getTime()) / msPerDay;
  if (daysUntilExpiry < 0) return "expired";
  if (daysUntilExpiry <= expiringSoonDays) return "expiring_soon";
  return "valid";
}

function validateLicenseUpload({
  fullName,
  licenseExpiryDate,
  licenseHolderName,
  ocrText,
}) {
  const expiryDate = parseDate(licenseExpiryDate);
  if (!expiryDate) {
    throw new ApiError(
      400,
      "Driver license expiry date is required."
    );
  }

  const normalizedExpiry = new Date(expiryDate);
  normalizedExpiry.setHours(23, 59, 59, 999);

  if (normalizedExpiry.getTime() < Date.now()) {
    throw new ApiError(400, "Driver License Expired. Please upload a valid license.");
  }

  const extractedSignals = extractLicenseSignals(ocrText);
  const extractedName = licenseHolderName || extractedSignals.licenseHolderName || ocrText || "";
  if (extractedName && !isNameCompatible(fullName, extractedName)) {
    throw new ApiError(
      400,
      "Driver license name does not match the registered account name."
    );
  }

  return {
    licenseExpiresAt: normalizedExpiry,
    extractedName: extractedName || null,
    licenseNumber: extractedSignals.licenseNumber || null,
    validationStatus: "validated",
  };
}

module.exports = {
  validateLicenseUpload,
  isNameCompatible,
  normalizeText,
  extractLicenseSignals,
  extractExpiryDate,
  extractBirthDate,
  classifyExpiry,
};
