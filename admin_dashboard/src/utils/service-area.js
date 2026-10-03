import { useEffect, useState } from "react";
import { apiClient } from "../api/client";

// Guiuan's service area from GET /api/service-area (the backend's
// data/service-area is the source of truth): the boundary, mainland and
// islands, plus the map limits. Loaded once per page load.
let loading = null;

export function loadServiceArea() {
  if (!loading) {
    loading = apiClient
      .get("/service-area", { skipAuthRedirect: true })
      .then(({ data }) => data?.data || null)
      .catch(() => {
        loading = null; // try again next time
        return null;
      });
  }
  return loading;
}

/** The service area, or null until it has loaded (or if it can't). */
export function useServiceArea() {
  const [area, setArea] = useState(null);
  useEffect(() => {
    let cancelled = false;
    loadServiceArea().then((value) => {
      if (!cancelled) setArea(value);
    });
    return () => {
      cancelled = true;
    };
  }, []);
  return area;
}

// Guiuan's town proper, for maps that open before the service area loads.
export const GUIUAN_CENTER = [125.72364, 11.03162];

function inRing(lng, lat, ring) {
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i];
    const [xj, yj] = ring[j];
    if (yi > lat !== yj > lat && lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

function distanceToBoundaryMeters(area, lat, lng) {
  const kx = 111320 * Math.cos((lat * Math.PI) / 180);
  const ky = 110540;
  let best = Infinity;
  for (const polygon of area.boundary.geometry.coordinates) {
    for (const ring of polygon) {
      for (let i = 1; i < ring.length; i += 1) {
        const ax = (ring[i - 1][0] - lng) * kx;
        const ay = (ring[i - 1][1] - lat) * ky;
        const bx = (ring[i][0] - lng) * kx;
        const by = (ring[i][1] - lat) * ky;
        const dx = bx - ax;
        const dy = by - ay;
        const t = Math.max(0, Math.min(1, -(ax * dx + ay * dy) / (dx * dx + dy * dy || 1)));
        best = Math.min(best, Math.hypot(ax + t * dx, ay + t * dy));
      }
    }
  }
  return best;
}

/**
 * Whether a point is inside Guiuan (the same rule as the backend), counting
 * points within [bufferMeters] of the boundary. Null while the area hasn't
 * loaded or the point is invalid.
 */
export function isInsideServiceArea(area, lat, lng, { bufferMeters = area?.bufferMeters ?? 300 } = {}) {
  const la = Number(lat);
  const ln = Number(lng);
  if (!area || !Number.isFinite(la) || !Number.isFinite(ln)) return null;
  const polygons = area.boundary.geometry.coordinates;
  if (polygons.some((polygon) => inRing(ln, la, polygon[0]) && !polygon.slice(1).some((hole) => inRing(ln, la, hole)))) {
    return true;
  }
  return bufferMeters > 0 && distanceToBoundaryMeters(area, la, ln) <= bufferMeters;
}

/** True only when the area is known and the point is outside it. */
export function isOutsideServiceArea(area, lat, lng) {
  return isInsideServiceArea(area, lat, lng) === false;
}

// Extra room around Guiuan for the dashboard's wide maps: a landscape map
// can only zoom out as far as its limits allow, so the phone app's tight
// limits would keep the dashboard from ever showing all of Guiuan. This
// still keeps the map to the Guiuan area, not all of Samar.
const DASHBOARD_PAD_LNG = 0.35;
const DASHBOARD_PAD_LAT = 0.15;

/**
 * The map limits: around Guiuan, widened to include every given [lng, lat]
 * point — an SOS, a ride or a driver outside Guiuan must never be out of
 * reach.
 */
export function relaxedMaxBounds(area, points = [], padDegrees = 0.03) {
  if (!area) return null;
  let [minLng, minLat, maxLng, maxLat] = area.mapBounds;
  minLng -= DASHBOARD_PAD_LNG;
  maxLng += DASHBOARD_PAD_LNG;
  minLat -= DASHBOARD_PAD_LAT;
  maxLat += DASHBOARD_PAD_LAT;
  for (const point of points) {
    if (!point) continue;
    const [lng, lat] = point;
    if (!Number.isFinite(lng) || !Number.isFinite(lat)) continue;
    minLng = Math.min(minLng, lng - padDegrees);
    minLat = Math.min(minLat, lat - padDegrees);
    maxLng = Math.max(maxLng, lng + padDegrees);
    maxLat = Math.max(maxLat, lat + padDegrees);
  }
  return [
    [minLng, minLat],
    [maxLng, maxLat],
  ];
}

/**
 * Fits the map to all of Guiuan, then stops zooming out much past that.
 * The service area's minZoom suits a phone; a short, wide dashboard map
 * needs to go a little further out to show the mainland and Homonhon at
 * once.
 */
export function fitToServiceArea(map, area, { padding = 20 } = {}) {
  if (!map || !area) return;
  map.setMinZoom(null);
  map.fitBounds(serviceAreaBounds(area), { padding, duration: 0 });
  map.setMinZoom(Math.min(area.minZoom, map.getZoom() - 0.5));
}

/** Guiuan's own bounds, for "fit the map to Guiuan". */
export function serviceAreaBounds(area) {
  if (!area) return null;
  const [minLng, minLat, maxLng, maxLat] = area.bbox;
  return [
    [minLng, minLat],
    [maxLng, maxLat],
  ];
}

/**
 * Draws Guiuan's boundary outline under the map's own markers. Safe to call
 * again after a style change (sources and layers are re-added if missing).
 */
export function addServiceAreaOutline(map, area, { beforeLayerId } = {}) {
  if (!map || !area) return;
  if (!map.getSource("service-area")) {
    map.addSource("service-area", { type: "geojson", data: { type: "FeatureCollection", features: [area.boundary] } });
  }
  const before = beforeLayerId && map.getLayer(beforeLayerId) ? beforeLayerId : undefined;
  if (!map.getLayer("service-area-fill")) {
    map.addLayer(
      {
        id: "service-area-fill",
        type: "fill",
        source: "service-area",
        paint: { "fill-color": "#0E8C46", "fill-opacity": 0.05 },
      },
      before
    );
  }
  if (!map.getLayer("service-area-line")) {
    map.addLayer(
      {
        id: "service-area-line",
        type: "line",
        source: "service-area",
        paint: { "line-color": "#0E8C46", "line-width": 2, "line-opacity": 0.9, "line-dasharray": [2, 1.5] },
      },
      before
    );
  }
}
