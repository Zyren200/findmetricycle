#!/usr/bin/env node
// Writes the copy of the service area the mobile app bundles
// (mobile_app/assets/service_area/service_area.json): the same data
// GET /api/service-area returns, so the app's maps and checks work on first
// launch and offline. The app replaces it with the live version as soon as
// it reaches the server.
//
//   npm run service-area:export
//
// tests/geofence-boundary.test.js fails when the bundled copy is out of
// date with data/service-area/guiuan.geojson.
const fs = require("fs");
const path = require("path");

const MOBILE_COPY = path.resolve(__dirname, "..", "..", "mobile_app", "assets", "service_area", "service_area.json");

function exportServiceArea() {
  // Loaded here so update-service-area.js can call this after rewriting
  // the boundary file.
  delete require.cache[require.resolve("../src/services/service-area.service")];
  const serviceArea = require("../src/services/service-area.service");
  const data = {
    ...serviceArea.describeServiceArea(),
    // Until the app hears from the server, assume production rules.
    enforced: true,
    bundled: true,
  };
  fs.mkdirSync(path.dirname(MOBILE_COPY), { recursive: true });
  fs.writeFileSync(MOBILE_COPY, `${JSON.stringify(data)}\n`);
  return { file: MOBILE_COPY, version: data.version };
}

if (require.main === module) {
  const { file, version } = exportServiceArea();
  console.log(`Wrote ${path.relative(process.cwd(), file)} (version ${version})`);
}

module.exports = { exportServiceArea, MOBILE_COPY };
