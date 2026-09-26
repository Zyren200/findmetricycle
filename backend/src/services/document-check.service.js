// Server-side "computer vision" for driver applications: OCRs the uploaded
// license and permit photos and classifies them (utils/document-classifier).
// The website runs the same check, but anything the browser does can be
// skipped — this is the result the admin actually sees and that gates
// approval.
const path = require("path");
const env = require("../config/env");
const db = require("../config/db");
const { classifyDocument } = require("../utils/document-classifier");
const notificationService = require("./notification.service");

const OCR_TIMEOUT_MS = 90 * 1000;
const DOCS_DIR = path.resolve(process.cwd(), env.upload.dir, "driver-docs");
const CACHE_DIR = path.resolve(__dirname, "../../.ocr-cache");

let workerPromise = null;
let queue = Promise.resolve();

function getWorker() {
  if (!workerPromise) {
    // Loaded lazily: the OCR engine is only needed when an application
    // comes in, and it downloads its language data on first use.
    const { createWorker } = require("tesseract.js");
    workerPromise = createWorker("eng", 1, { cachePath: CACHE_DIR }).catch((error) => {
      workerPromise = null;
      throw error;
    });
  }
  return workerPromise;
}

function withTimeout(promise, ms) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error("OCR timed out")), ms);
    }),
  ]).finally(() => clearTimeout(timer));
}

async function ocrDocument(imageUrl) {
  if (!imageUrl) return "";
  const file = path.join(DOCS_DIR, path.basename(imageUrl));
  const worker = await getWorker();
  const { data } = await withTimeout(worker.recognize(file), OCR_TIMEOUT_MS);
  return data.text || "";
}

async function checkOne(imageUrl, kind) {
  try {
    const text = await ocrDocument(imageUrl);
    return { ...classifyDocument(text, kind), textSample: text.replace(/\s+/g, " ").trim().slice(0, 300) };
  } catch (error) {
    return { status: "error", error: error.message };
  }
}

/** OCRs and classifies both documents of an application and stores the result. */
async function checkApplication(applicationId) {
  const [app] = await db.query(
    "SELECT id, user_id, full_name, license_image_url, business_permit_image_url FROM driver_applications WHERE id = ?",
    [applicationId]
  );
  if (!app) return null;

  const license = await checkOne(app.license_image_url, "license");
  const permit = await checkOne(app.business_permit_image_url, "permit");

  await db.query(
    `UPDATE driver_applications
       SET license_check_status = ?, permit_check_status = ?,
           document_check_json = ?, documents_checked_at = NOW()
     WHERE id = ?`,
    [license.status, permit.status, JSON.stringify({ license, permit }), applicationId]
  );

  const flagged = [license, permit].some((r) => r.status !== "verified");
  if (flagged) {
    try {
      await notificationService.createNotification({
        type: "driver_documents_flagged",
        title: "Driver documents need a closer look",
        body: `${app.full_name}'s ${[
          license.status !== "verified" ? "license" : null,
          permit.status !== "verified" ? "permit" : null,
        ]
          .filter(Boolean)
          .join(" and ")} didn't pass the automatic document check.`,
        recipientRole: "admin",
        metadataJson: { applicationId },
      });
    } catch (_error) {
      // Notification failure shouldn't lose the check result.
    }
  }
  return { license, permit };
}

/**
 * Runs the check in the background (one at a time — OCR is CPU-heavy) so
 * submitting an application stays fast.
 */
function scheduleCheck(applicationId) {
  if (process.env.NODE_ENV === "test") return;
  queue = queue
    .then(() => checkApplication(applicationId))
    .catch((error) => console.error(`Document check failed for application ${applicationId}:`, error.message));
}

module.exports = { checkApplication, scheduleCheck };
