#!/usr/bin/env node
// Runs the server-side document check (OCR + classification) on driver
// applications submitted before it existed, or on one application:
//   node scripts/check-driver-documents.js          # all never-checked
//   node scripts/check-driver-documents.js 11       # a specific id
const db = require("../src/config/db");
const { checkApplication } = require("../src/services/document-check.service");

async function main() {
  const id = Number(process.argv[2]);
  const ids = id
    ? [id]
    : (await db.query(
        "SELECT id FROM driver_applications WHERE documents_checked_at IS NULL AND status <> 'archived' ORDER BY id"
      )).map((row) => row.id);

  for (const applicationId of ids) {
    const result = await checkApplication(applicationId);
    if (!result) {
      console.log(`#${applicationId}: not found`);
      continue;
    }
    console.log(
      `#${applicationId}: license=${result.license.status}` +
        `${result.license.otherDocument ? ` (${result.license.otherDocument})` : ""}` +
        `, permit=${result.permit.status}`
    );
  }
  process.exit(0);
}

main().catch((error) => {
  console.error("Document check failed:", error.message);
  process.exit(1);
});
