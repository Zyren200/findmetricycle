// Decides from OCR text whether a photo really is a Philippine driver's
// license or a tricycle franchise / business permit. Each document type has
// weighted signals (phrases, number formats) — a photo must collect enough
// of them. Any single generic word (e.g. "PHILIPPINES", printed on every
// government ID and certificate) is never enough on its own.
//
// Kept dependency-free and mirrored in driver_apply/src/utils/
// documentClassifier.js so the website warns with the same rules the
// server enforces.

const MIN_WORDS = 6; // fewer real words than this → not a readable document
const PASS_SCORE = 3;

const SIGNALS = {
  license: [
    { re: /\b[A-Z]\d{2}[-\s]?\d{2}[-\s]?\d{6}\b/, weight: 3, label: "LTO license number" },
    { re: /LAND\s+TRANSPORTATION/, weight: 2, label: "Land Transportation Office" },
    { re: /DRIVER'?S?\s+LICEN[CS]E/, weight: 2, label: "Driver's License" },
    { re: /\bLTO\b/, weight: 1, label: "LTO" },
    { re: /DEPARTMENT\s+OF\s+TRANSPORTATION/, weight: 1, label: "Department of Transportation" },
    { re: /\bLICEN[CS]E\s*(NO|NUMBER)/, weight: 1, label: "License No." },
    { re: /\b(NON[-\s]?)?PROFESSIONAL\b/, weight: 1, label: "Professional / Non-Professional" },
    { re: /\b(RESTRICTIONS?|DL\s*CODES?|CONDITIONS?)\b/, weight: 1, label: "Restrictions / DL codes" },
    { re: /EXPIRATION\s+DATE/, weight: 1, label: "Expiration date" },
    { re: /\b(BLOOD\s+TYPE|EYES?\s+COLOR|WEIGHT|HEIGHT)\b/, weight: 1, label: "Physical details" },
  ],
  permit: [
    { re: /FRANCHISE/, weight: 2, label: "Franchise" },
    { re: /\bMTOP\b|MOTORIZED\s+TRICYCLE\s+OPERATOR/, weight: 2, label: "MTOP" },
    { re: /BUSINESS\s+PERMIT|MAYOR'?S?\s+PERMIT/, weight: 2, label: "Business / Mayor's permit" },
    { re: /TRICYCLE/, weight: 1.5, label: "Tricycle" },
    { re: /\bPERMIT\b/, weight: 1, label: "Permit" },
    { re: /\bOPERATOR\b/, weight: 1, label: "Operator" },
    { re: /\bTODA\b/, weight: 1, label: "TODA" },
    { re: /\b(PLATE|BODY)\s*(NO|NUMBER)|\bCHASSIS\b|\b(MOTOR|ENGINE)\s*(NO|NUMBER)/, weight: 1, label: "Vehicle details" },
    { re: /SANGGUNIANG|OFFICE\s+OF\s+THE\s+(MUNICIPAL|CITY)\s+MAYOR/, weight: 1, label: "LGU office" },
  ],
};

// Titles of other documents people upload by mistake. Seeing one of these
// outweighs incidental matches (e.g. a certificate that mentions "permit").
const OTHER_DOCUMENTS = [
  /CERTIFICATE\s+OF\s+(FINAL\s+)?(ELECTRICAL|BUILDING|OCCUPANCY|LIVE\s+BIRTH|MARRIAGE)/,
  /BARANGAY\s+CLEARANCE/,
  /POLICE\s+CLEARANCE/,
  /\bNBI\b/,
  /BIRTH\s+CERTIFICATE/,
  /PHILHEALTH|SOCIAL\s+SECURITY|\bSSS\b|\bUMID\b|POSTAL\s+ID|VOTER'?S?\s+ID|PASSPORT/,
];

function normalize(text) {
  return String(text || "")
    .toUpperCase()
    .replace(/[’`]/g, "'")
    .replace(/[^A-Z0-9'\s-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * @param {string} ocrText  raw OCR output
 * @param {"license"|"permit"} kind
 * @returns {{status: "verified"|"suspicious"|"unreadable", score: number,
 *   matched: string[], otherDocument: string|null, words: number}}
 */
function classifyDocument(ocrText, kind) {
  const text = normalize(ocrText);
  const words = (text.match(/\b[A-Z]{3,}\b/g) || []).length;

  const matched = [];
  let score = 0;
  for (const signal of SIGNALS[kind] || []) {
    if (signal.re.test(text)) {
      score += signal.weight;
      matched.push(signal.label);
    }
  }

  const other = OTHER_DOCUMENTS.map((re) => text.match(re)?.[0]).find(Boolean) || null;

  let status;
  if (words < MIN_WORDS && score < PASS_SCORE) status = "unreadable";
  else if (score >= PASS_SCORE && !other) status = "verified";
  else status = "suspicious";

  return { status, score, matched, otherDocument: other, words };
}

module.exports = { classifyDocument, PASS_SCORE };
