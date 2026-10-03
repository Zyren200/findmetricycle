# Service area boundary

`guiuan.geojson` is the boundary of the Municipality of Guiuan, Eastern Samar
(PSGC 0802609000): a MultiPolygon of 33 parts — the mainland and every island
(Homonhon, Suluan, Calicoan, Manicani, Tubabao and the smaller ones).

It is the single source of truth for the service area. The backend checks
bookings and saved places against it and serves it at `GET /api/service-area`,
where the mobile app and the admin dashboard read it.

## Source

OpenStreetMap has no municipal boundary for Guiuan (only the town's point and a
few barangays), so this comes from the official **PSA / NAMRIA** administrative
boundaries (2023), as GeoJSON published by
[faeldon/philippines-json-maps](https://github.com/faeldon/philippines-json-maps)
(MIT). The file's `properties` record the source URL and the date it was
retrieved. Credit: "Boundary © PSA / NAMRIA".

It is simplified (Douglas–Peucker, 10 m tolerance, 5 decimals) to about 57 KB;
the area changes by about 0.01% and no island is dropped.

## Updating

```bash
cd backend
node scripts/update-service-area.js
```

The script downloads the source again, keeps Guiuan, simplifies it and rewrites
`guiuan.geojson`. Then run `npm test` — the tests check that the islands and all
60 barangay pins are still inside.
