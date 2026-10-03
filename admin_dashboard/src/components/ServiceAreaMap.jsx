import { useEffect, useRef, useState } from "react";
import "maplibre-gl/dist/maplibre-gl.css";
import { loadMaplibre, MAP_STYLE_URL } from "../utils/maplibre";
import {
  GUIUAN_CENTER,
  addServiceAreaOutline,
  fitToServiceArea,
  isOutsideServiceArea,
  relaxedMaxBounds,
  useServiceArea,
} from "../utils/service-area";

const EMPTY = { type: "FeatureCollection", features: [] };

/**
 * A small map of Guiuan with its boundary outline and some points.
 *
 * points: [{ id, lat, lng, label, color, highlight }]. A point outside
 * Guiuan stays reachable (the map limits widen for it) and is labelled
 * "Outside service area".
 * focus: { lat, lng } to fly to (e.g. the alert being viewed).
 * onMapClick(lat, lng): clicks on the map, e.g. to place a pin.
 */
export default function ServiceAreaMap({ points = [], focus = null, onMapClick = null, height = 320, ariaLabel = "Map" }) {
  const area = useServiceArea();
  const containerRef = useRef(null);
  const mapRef = useRef(null);
  const [ready, setReady] = useState(false);
  const [mapError, setMapError] = useState(null);
  const clickRef = useRef(onMapClick);
  clickRef.current = onMapClick;

  useEffect(() => {
    let cancelled = false;
    loadMaplibre()
      .then((maplibregl) => {
        if (cancelled || !containerRef.current || mapRef.current) return;
        const map = new maplibregl.Map({
          container: containerRef.current,
          style: MAP_STYLE_URL,
          center: focus ? [Number(focus.lng), Number(focus.lat)] : GUIUAN_CENTER,
          zoom: focus ? 14 : 10.5,
          attributionControl: false,
        });
        map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");
        map.addControl(new maplibregl.AttributionControl({ compact: true }), "bottom-right");
        map.on("load", () => {
          map.addSource("points", { type: "geojson", data: EMPTY });
          map.addLayer({
            id: "points-circle",
            type: "circle",
            source: "points",
            paint: {
              "circle-radius": ["case", ["get", "highlight"], 9, 6],
              "circle-color": ["get", "color"],
              "circle-stroke-color": "#ffffff",
              "circle-stroke-width": ["case", ["get", "highlight"], 3, 1.5],
            },
          });
          map.addLayer({
            id: "points-label",
            type: "symbol",
            source: "points",
            layout: {
              "text-field": ["get", "text"],
              "text-size": 11,
              "text-offset": [0, 1.1],
              "text-anchor": "top",
              "text-optional": true,
            },
            paint: { "text-color": "#1f2d2a", "text-halo-color": "#ffffff", "text-halo-width": 1.2 },
          });
          setReady(true);
        });
        map.on("click", (event) => {
          if (clickRef.current) clickRef.current(event.lngLat.lat, event.lngLat.lng);
        });
        map.on("error", (event) => {
          if (event?.error) setMapError("Map tiles are unavailable right now.");
        });
        mapRef.current = map;
      })
      .catch((err) => setMapError(String(err?.message || err)));
    return () => {
      cancelled = true;
      mapRef.current?.remove();
      mapRef.current = null;
    };
    // The map is created once; props are applied by the effects below.
  }, []);

  // Outline, limits and the first view of Guiuan, once both are ready.
  const fittedRef = useRef(false);
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready || !area) return;
    addServiceAreaOutline(map, area, { beforeLayerId: "points-circle" });
    if (!fittedRef.current) {
      fittedRef.current = true;
      // Viewing one point: work out the zoom limit from Guiuan's fit, then
      // go back to the point.
      const view = focus ? { center: map.getCenter(), zoom: map.getZoom() } : null;
      fitToServiceArea(map, area, { padding: 16 });
      if (view) map.jumpTo(view);
    }
  }, [area, ready, focus]);

  // Points (and the limits that must include them).
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready) return;
    const features = points
      .filter((p) => Number.isFinite(Number(p.lat)) && Number.isFinite(Number(p.lng)))
      .map((p) => {
        const outside = isOutsideServiceArea(area, p.lat, p.lng);
        return {
          type: "Feature",
          geometry: { type: "Point", coordinates: [Number(p.lng), Number(p.lat)] },
          properties: {
            id: p.id,
            color: p.color || "#0E8C46",
            highlight: Boolean(p.highlight),
            text: outside ? `${p.label || ""}${p.label ? " · " : ""}Outside service area` : p.label || "",
          },
        };
      });
    map.getSource("points")?.setData({ type: "FeatureCollection", features });
    if (area) {
      map.setMaxBounds(relaxedMaxBounds(area, features.map((f) => f.geometry.coordinates)));
    }
  }, [points, area, ready]);

  // A crosshair while a click places something.
  useEffect(() => {
    const map = mapRef.current;
    if (map && ready) map.getCanvas().style.cursor = onMapClick ? "crosshair" : "";
  }, [onMapClick, ready]);

  // Fly to the point being viewed.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready || !focus) return;
    const lat = Number(focus.lat);
    const lng = Number(focus.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
    map.flyTo({ center: [lng, lat], zoom: Math.max(map.getZoom(), 14), duration: 600 });
  }, [focus?.lat, focus?.lng, ready]);

  return (
    <div className="service-area-map" style={{ height }}>
      <div ref={containerRef} className="service-area-map-canvas" aria-label={ariaLabel} />
      {mapError ? <div className="map-fallback">{mapError}</div> : null}
    </div>
  );
}
