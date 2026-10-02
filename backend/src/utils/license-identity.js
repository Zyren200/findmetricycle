// Checks that an OCR'd driver's license is a Philippine LTO license that
// belongs to the applicant: it must carry an LTO license number
// (e.g. "H04-23-001476") and the account holder's name.
//
// Kept dependency-free and mirrored in driver_apply/src/utils/
// licenseIdentity.js so the website blocks the same uploads the server
// rejects (backend/tests/license-identity.test.js checks both copies agree).

// Letter + 2 digits, 2 digits, 6 digits. OCR often reads 0 as O and 1 as
// I/L inside the digit groups, and drops or swaps the dashes.
const LTO_NUMBER = /\b([A-Z])\s?([0-9OIL]{2})\s?[-–—.]?\s?([0-9OIL]{2})\s?[-–—.]?\s?([0-9OIL]{6})\b/;

const NAME_SUFFIXES = new Set(["JR", "SR", "II", "III", "IV", "V"]);
const MIN_READABLE_WORDS = 6;

// Words printed on every LTO card. A name may match one of these exactly,
// but never "almost" (otherwise REYES would pass on the printed "EYES").
const CARD_LABELS = new Set([
  "REPUBLIC", "PHILIPPINES", "DEPARTMENT", "TRANSPORTATION", "LAND", "OFFICE", "DRIVER", "DRIVERS",
  "LICENSE", "LICENCE", "PROFESSIONAL", "NON-PROFESSIONAL", "STUDENT", "PERMIT", "LAST", "FIRST",
  "MIDDLE", "NAME", "NATIONALITY", "SEX", "DATE", "BIRTH", "WEIGHT", "HEIGHT", "ADDRESS", "EXPIRATION",
  "AGENCY", "CODE", "CODES", "BLOOD", "TYPE", "EYES", "COLOR", "CONDITIONS", "RESTRICTIONS", "NONE",
  "BROWN", "BLACK", "BLUE", "GRAY", "SIGNATURE", "ASSISTANT", "SECRETARY", "PHL",
]);

function normalize(text) {
  return String(text || "")
    .toUpperCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // Ñ → N, accents dropped
    .replace(/[^A-Z0-9\s-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function digits(group) {
  return group.replace(/O/g, "0").replace(/[IL]/g, "1");
}

function findLicenseNumber(ocrText) {
  const m = normalize(ocrText).match(LTO_NUMBER);
  if (!m) return null;
  return `${m[1]}${digits(m[2])}-${digits(m[3])}-${digits(m[4])}`;
}

function editDistanceAtMostOne(a, b) {
  if (a === b) return true;
  if (Math.abs(a.length - b.length) > 1) return false;
  let i = 0;
  let j = 0;
  let edits = 0;
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) {
      i += 1;
      j += 1;
      continue;
    }
    edits += 1;
    if (edits > 1) return false;
    if (a.length > b.length) i += 1;
    else if (b.length > a.length) j += 1;
    else {
      i += 1;
      j += 1;
    }
  }
  return edits + (a.length - i) + (b.length - j) <= 1;
}

/** The name's meaningful parts: no suffixes, initials or single letters. */
function nameTokens(fullName) {
  return normalize(fullName)
    .split(" ")
    .filter((t) => t.length >= 2 && !NAME_SUFFIXES.has(t) && /^[A-Z-]+$/.test(t));
}

// A token is on the card if a word matches it exactly, or — for longer
// names, where one misread letter is common — with a single edit, or if
// it's there with the spaces squeezed out ("DELACRUZ").
function tokenOnCard(token, words, squeezed) {
  if (words.includes(token)) return true;
  if (token.length >= 4 && words.some((w) => !CARD_LABELS.has(w) && editDistanceAtMostOne(token, w))) return true;
  return token.length >= 4 && squeezed.includes(token);
}

/**
 * @param {string} ocrText  raw OCR output of the license photo
 * @param {string} accountName  the applicant's registered full name
 * @returns {{
 *   licenseNumber: string|null,
 *   readable: boolean,
 *   nameStatus: "match"|"mismatch"|"unreadable",
 *   missingNames: string[],
 * }}
 */
function checkLicenseIdentity(ocrText, accountName) {
  const text = normalize(ocrText);
  const words = text.split(" ").filter(Boolean);
  const readable = (text.match(/\b[A-Z]{3,}\b/g) || []).length >= MIN_READABLE_WORDS;
  const licenseNumber = findLicenseNumber(ocrText);

  const tokens = nameTokens(accountName);
  if (!readable || tokens.length === 0) {
    return { licenseNumber, readable, nameStatus: "unreadable", missingNames: [] };
  }

  const squeezed = words.join("");
  // First name and surname must both be on the card. Middle names are
  // optional — accounts often leave them out.
  const required = tokens.length > 1 ? [tokens[0], tokens[tokens.length - 1]] : tokens;
  const missingNames = required.filter((t) => !tokenOnCard(t, words, squeezed));

  return {
    licenseNumber,
    readable,
    nameStatus: missingNames.length === 0 ? "match" : "mismatch",
    missingNames,
  };
}

module.exports = { checkLicenseIdentity, findLicenseNumber, nameTokens };
