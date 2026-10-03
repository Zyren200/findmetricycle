#!/usr/bin/env node
// Rebuilds data/service-area/guiuan.geojson — the one boundary the backend,
// the mobile app and the admin dashboard all use.
//
//   node scripts/update-service-area.js
//
// OpenStreetMap has no municipal boundary for Guiuan (only the town's
// point and a few barangays), so the boundary comes from the official
// PSA / NAMRIA administrative boundaries, as GeoJSON published by
// faeldon/philippines-json-maps (MIT). The script downloads the Eastern
// Samar municipalities, keeps Guiuan (PSGC 0802609000, which includes
// Homonhon, Suluan, Calicoan, Manicani, Tubabao and the smaller islands),
// and simplifies it so it stays small without losing any island.
const fs = require("fs");
const path = require("path");

const SOURCE_URL =
  "https://raw.githubusercontent.com/faeldon/philippines-json-maps/master/2023/geojson/provdists/hires/municities-provdist-802600000.0.1.json";
const GUIUAN_PSGC = 802609000;
// Douglas–Peucker tolerance. 10 m keeps all 33 parts (every island) and
// changes the area by about 0.01%; GEOFENCE_BUFFER_METERS covers far more.
const SIMPLIFY_TOLERANCE_M = 10;
const DECIMALS = 5; // ~1 m
const OUTPUT = path.resolve(__dirname, "..", "data", "service-area", "guiuan.geojson");

// Local metres per degree around Guiuan (lat ~11°N), plenty accurate here.
const KX = 111320 * Math.cos((11 * Math.PI) / 180);
const KY = 110540;

function distanceToSegmentM(p, a, b) {
  const ax = a[0] * KX, ay = a[1] * KY, bx = b[0] * KX, by = b[1] * KY, px = p[0] * KX, py = p[1] * KY;
  const dx = bx - ax, dy = by - ay;
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy || 1)));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

function douglasPeucker(points, toleranceM) {
  if (points.length < 3) return points;
  let maxDistance = 0;
  let index = 0;
  for (let i = 1; i < points.length - 1; i += 1) {
    const d = distanceToSegmentM(points[i], points[0], points[points.length - 1]);
    if (d > maxDistance) {
      maxDistance = d;
      index = i;
    }
  }
  if (maxDistance <= toleranceM) return [points[0], points[points.length - 1]];
  return [
    ...douglasPeucker(points.slice(0, index + 1), toleranceM).slice(0, -1),
    ...douglasPeucker(points.slice(index), toleranceM),
  ];
}

// A closed ring is split at the point farthest from its start, so both
// halves keep their shape.
function simplifyRing(ring, toleranceM) {
  const open = ring.slice(0, -1);
  let far = 0;
  let farDistance = 0;
  for (let i = 1; i < open.length; i += 1) {
    const d = Math.hypot((open[i][0] - open[0][0]) * KX, (open[i][1] - open[0][1]) * KY);
    if (d > farDistance) {
      farDistance = d;
      far = i;
    }
  }
  const first = douglasPeucker(open.slice(0, far + 1), toleranceM);
  const second = douglasPeucker([...open.slice(far), open[0]], toleranceM);
  const out = [...first.slice(0, -1), ...second.slice(0, -1)];
  out.push(out[0]);
  return out;
}

const round = (n) => Math.round(n * 10 ** DECIMALS) / 10 ** DECIMALS;

function ringAreaKm2(ring) {
  let a = 0;
  for (let i = 1; i < ring.length; i += 1) a += ring[i - 1][0] * ring[i][1] - ring[i][0] * ring[i - 1][1];
  return (Math.abs(a / 2) * KX * KY) / 1e6;
}

async function run() {
  console.log(`Downloading ${SOURCE_URL}`);
  const response = await fetch(SOURCE_URL);
  if (!response.ok) throw new Error(`Download failed: HTTP ${response.status}`);
  const source = await response.json();

  const feature = source.features.find((f) => Number(f.properties?.adm3_psgc) === GUIUAN_PSGC);
  if (!feature) throw new Error(`Guiuan (PSGC ${GUIUAN_PSGC}) not found in the download.`);
  if (feature.geometry.type !== "MultiPolygon") throw new Error(`Expected a MultiPolygon, got ${feature.geometry.type}.`);

  const coordinates = feature.geometry.coordinates
    .map((polygon) => polygon.map((ring) => simplifyRing(ring, SIMPLIFY_TOLERANCE_M).map(([x, y]) => [round(x), round(y)])))
    .filter((polygon) => polygon[0].length >= 4);
  if (coordinates.length !== feature.geometry.coordinates.length) {
    throw new Error("Simplifying dropped an island; lower SIMPLIFY_TOLERANCE_M.");
  }

  const areaKm2 = coordinates.reduce(
    (sum, polygon) => sum + ringAreaKm2(polygon[0]) - polygon.slice(1).reduce((h, ring) => h + ringAreaKm2(ring), 0),
    0
  );

  const output = {
    type: "FeatureCollection",
    features: [
      {
        type: "Feature",
        properties: {
          name: "Guiuan, Eastern Samar",
          psgc: "0802609000",
          areaKm2: Number(areaKm2.toFixed(2)),
          parts: coordinates.length,
          source: "PSA / NAMRIA administrative boundaries (2023), GeoJSON by faeldon/philippines-json-maps (MIT)",
          sourceUrl: SOURCE_URL,
          retrieved: new Date().toISOString().slice(0, 10),
          simplification: `Douglas-Peucker ${SIMPLIFY_TOLERANCE_M} m, ${DECIMALS} decimals`,
        },
        geometry: { type: "MultiPolygon", coordinates },
      },
    ],
  };

  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, `${JSON.stringify(output)}\n`);
  console.log(
    `Wrote ${path.relative(process.cwd(), OUTPUT)}: ${coordinates.length} parts, ${areaKm2.toFixed(2)} km², ` +
      `${(fs.statSync(OUTPUT).size / 1024).toFixed(0)} KB`
  );

  // And the copy the mobile app bundles.
  const { file } = require("./export-service-area").exportServiceArea();
  console.log(`Wrote ${path.relative(process.cwd(), file)}`);
}

run().catch((error) => {
  console.error("Failed to update the service area:", error.message);
  process.exit(1);
});
