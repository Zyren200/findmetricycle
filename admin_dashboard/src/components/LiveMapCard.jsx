import { useEffect, useMemo, useRef, useState } from "react";
import "maplibre-gl/dist/maplibre-gl.css";
import StatusPill from "./StatusPill";
import { asText, formatDateTime, shortenText } from "../utils/admin-formatters";

const DEFAULT_CENTER = [120.9842, 14.5995];
const DEFAULT_ZOOM = 12.5;
const MAP_STYLE_URL = "https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json";
const LIGHT_MAP_STYLE = "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json";

const emptyCollection = {
  type: "FeatureCollection",
  features: [],
};

function toLngLat(lat, lng) {
  const nLat = Number(lat);
  const nLng = Number(lng);

  if (!Number.isFinite(nLat) || !Number.isFinite(nLng)) {
    return null;
  }

  return [nLng, nLat];
}

function buildMapData(onlineDrivers = [], activeRides = []) {
  const bounds = {
    minLng: Infinity,
    minLat: Infinity,
    maxLng: -Infinity,
    maxLat: -Infinity,
  };
  const routeFeatures = [];
  const driverFeatures = [];
  const pickupFeatures = [];
  const dropoffFeatures = [];
  let hasBounds = false;
  let latestUpdate = null;

  function extendBounds(point) {
    if (!point) return;
    const [lng, lat] = point;
    bounds.minLng = Math.min(bounds.minLng, lng);
    bounds.minLat = Math.min(bounds.minLat, lat);
    bounds.maxLng = Math.max(bounds.maxLng, lng);
    bounds.maxLat = Math.max(bounds.maxLat, lat);
    hasBounds = true;
  }

  function updateLatest(value) {
    if (!value) return;
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return;
    if (!latestUpdate || parsed > latestUpdate) {
      latestUpdate = parsed;
    }
  }

  onlineDrivers.forEach((driver) => {
    const point = toLngLat(driver.current_lat, driver.current_lng);
    if (!point) return;

    driverFeatures.push({
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: point,
      },
      properties: {
        id: driver.id,
        label: asText(driver.full_name) || "Driver",
        subLabel: asText(driver.tricycle_number) || "-",
        rating: driver.rating_avg != null ? Number(driver.rating_avg).toFixed(1) : "-",
        lastUpdate: driver.last_location_update || "",
      },
    });
    extendBounds(point);
    updateLatest(driver.last_location_update);
  });

  activeRides.forEach((ride) => {
    const pickup = toLngLat(ride.pickup_lat, ride.pickup_lng);
    const dropoff = toLngLat(ride.dropoff_lat, ride.dropoff_lng);

    if (pickup) {
      pickupFeatures.push({
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: pickup,
        },
        properties: {
          id: `${ride.id}-pickup`,
          rideId: ride.id,
          label: `Ride #${ride.id} pickup`,
          subLabel: asText(ride.passenger_name) || "-",
        },
      });
      extendBounds(pickup);
    }

    if (dropoff) {
      dropoffFeatures.push({
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: dropoff,
        },
        properties: {
          id: `${ride.id}-dropoff`,
          rideId: ride.id,
          label: `Ride #${ride.id} drop-off`,
          subLabel: asText(ride.driver_name) || "-",
        },
      });
      extendBounds(dropoff);
    }

    if (pickup && dropoff) {
      routeFeatures.push({
        type: "Feature",
        geometry: {
          type: "LineString",
          coordinates: [pickup, dropoff],
        },
        properties: {
          id: ride.id,
          label: `Ride #${ride.id}`,
        },
      });
    }

    updateLatest(ride.requested_at);
  });

  return {
    bounds,
    hasBounds,
    latestUpdate,
    routeCollection: {
      type: "FeatureCollection",
      features: routeFeatures,
    },
    driverCollection: {
      type: "FeatureCollection",
      features: driverFeatures,
    },
    pickupCollection: {
      type: "FeatureCollection",
      features: pickupFeatures,
    },
    dropoffCollection: {
      type: "FeatureCollection",
      features: dropoffFeatures,
    },
  };
}

function setGeoJsonSource(map, sourceId, data) {
  const source = map.getSource(sourceId);
  if (source && typeof source.setData === "function") {
    source.setData(data);
    return;
  }

  if (!source) {
    map.addSource(sourceId, { type: "geojson", data });
  }
}

function ensureLayer(map, layer) {
  if (!map.getLayer(layer.id)) {
    map.addLayer(layer);
  }
}

export default function LiveMapCard({ onlineDrivers, activeRides }) {
  const containerRef = useRef(null);
  const mapRef = useRef(null);
  const hasFittedRef = useRef(false);
  const [mapReady, setMapReady] = useState(false);
  const [mapError, setMapError] = useState(null);
  const prevPositionsRef = useRef(new Map());
  const animRef = useRef(null);
  const [mapStyle, setMapStyle] = useState(MAP_STYLE_URL);

  const mapData = useMemo(
    () => buildMapData(onlineDrivers, activeRides),
    [activeRides, onlineDrivers]
  );

  useEffect(() => {
    let cancelled = false;

    async function initializeMap() {
      if (!containerRef.current || mapRef.current) return;
      try {
        const module = await import("maplibre-gl");
        if (cancelled || !containerRef.current || mapRef.current) return;

        const maplibregl = module.default || module;
        const map = new maplibregl.Map({
        container: containerRef.current,
        style: mapStyle,
        center: DEFAULT_CENTER,
        zoom: DEFAULT_ZOOM,
        pitch: 0,
        bearing: 0,
        attributionControl: true,
        cooperativeGestures: true,
      });

      map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "top-right");
      map.addControl(new maplibregl.ScaleControl({ maxWidth: 120, unit: "metric" }), "bottom-left");

      map.on("load", () => {
        map.addSource("routes", { type: "geojson", data: emptyCollection });
        map.addSource("drivers", { type: "geojson", data: emptyCollection });
        map.addSource("pickups", { type: "geojson", data: emptyCollection });
        map.addSource("dropoffs", { type: "geojson", data: emptyCollection });

        setupMapSourcesAndLayers(map);

        ensureLayer(map, {
          id: "pickup-points",
          type: "circle",
          source: "pickups",
          paint: {
            "circle-radius": 8,
            "circle-color": "#f2be35",
            "circle-stroke-color": "#ffffff",
            "circle-stroke-width": 2,
            "circle-opacity": 0.95,
          },
        });

        ensureLayer(map, {
          id: "dropoff-points",
          type: "circle",
          source: "dropoffs",
          paint: {
            "circle-radius": 8,
            "circle-color": "#c94530",
            "circle-stroke-color": "#ffffff",
            "circle-stroke-width": 2,
            "circle-opacity": 0.95,
          },
        });

        ensureLayer(map, {
          id: "driver-points",
          type: "circle",
          source: "drivers",
          paint: {
            "circle-radius": 7,
            "circle-color": "#0f8d4c",
            "circle-stroke-color": "#ffffff",
            "circle-stroke-width": 2,
            "circle-opacity": 0.98,
          },
        });

        ensureLayer(map, {
          id: "driver-count-labels",
          type: "symbol",
          source: "drivers",
          layout: {
            "text-field": ["get", "subLabel"],
            "text-size": 11,
            "text-offset": [0, 1.1],
            "text-anchor": "top",
            "icon-image": "marker-15",
            "icon-allow-overlap": true,
          },
          paint: {
            "text-color": "#1f2d2a",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1.2,
          },
        });

        map.on("mouseenter", "driver-points", () => {
          map.getCanvas().style.cursor = "pointer";
        });
        map.on("mouseleave", "driver-points", () => {
          map.getCanvas().style.cursor = "";
        });
        map.on("click", "driver-points", (event) => {
          const feature = event.features?.[0];
          if (!feature) return;
          const props = feature.properties || {};
          const coordinates = feature.geometry.coordinates.slice();
          const lastUpdate = props.lastUpdate ? formatDateTime(props.lastUpdate) : "-";

          new maplibregl.Popup({ closeButton: true, offset: 12 })
            .setLngLat(coordinates)
            .setHTML(
              `<div style="font-size:12px;line-height:1.5;">` +
                `<strong>${props.label || "Driver"}</strong><br/>` +
                `Tricycle: ${props.subLabel || "-"}<br/>` +
                `Rating: ${props.rating || "-"}<br/>` +
                `Last update: ${lastUpdate}` +
                `</div>`
            )
            .addTo(map);
        });

        setMapReady(true);
        setMapError(null);
      });

      map.on("error", (event) => {
        if (event?.error) {
          setMapError("Live map tiles are unavailable right now.");
        }
      });

      map.on("styledata", () => {
        setMapError(null);
      });

      mapRef.current = map;
      } catch (err) {
        console.error("LiveMap init error:", err);
        setMapError(String(err?.message || err));
      }
    }

    initializeMap();

    return () => {
      cancelled = true;
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
      hasFittedRef.current = false;
      setMapReady(false);
    };
  }, []);

  // Smoothly animate driver marker transitions when data updates
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !mapReady) return;

    const source = map.getSource("drivers");
    if (!source || typeof source.setData !== "function") return;

    // Prepare start and end positions
    const startPositions = new Map(prevPositionsRef.current);
    const targetFeatures = mapData.driverCollection.features.map((f) => ({ ...f }));
    const targetPositions = new Map();
    targetFeatures.forEach((f) => {
      const id = String(f.properties?.id || f.properties?.driverId || Math.random());
      targetPositions.set(id, f.geometry.coordinates);
    });

    // store new targets for next cycle
    prevPositionsRef.current = new Map(targetPositions);

    if (animRef.current) cancelAnimationFrame(animRef.current);
    const duration = 600;
    const start = Date.now();

    function frame() {
      const t = Math.min(1, (Date.now() - start) / duration);
      const interp = targetFeatures.map((f) => {
        const id = String(f.properties?.id || f.properties?.driverId || "");
        const from = startPositions.get(id) || f.geometry.coordinates;
        const to = targetPositions.get(id) || f.geometry.coordinates;
        const lng = from[0] + (to[0] - from[0]) * t;
        const lat = from[1] + (to[1] - from[1]) * t;
        return { ...f, geometry: { type: "Point", coordinates: [lng, lat] } };
      });

      source.setData({ type: "FeatureCollection", features: interp });

      if (t < 1) {
        animRef.current = requestAnimationFrame(frame);
      }
    }

    animRef.current = requestAnimationFrame(frame);

    return () => {
      if (animRef.current) cancelAnimationFrame(animRef.current);
    };
  }, [mapData.driverCollection, mapReady]);

  // Map control handlers
  function zoomIn() {
    const map = mapRef.current;
    if (!map) return;
    map.easeTo({ zoom: map.getZoom() + 1, duration: 300 });
  }

  function zoomOut() {
    const map = mapRef.current;
    if (!map) return;
    map.easeTo({ zoom: Math.max(0, map.getZoom() - 1), duration: 300 });
  }

  function rotateMap() {
    const map = mapRef.current;
    if (!map) return;
    map.easeTo({ bearing: (map.getBearing() + 45) % 360, duration: 500 });
  }

  function toggleTilt() {
    const map = mapRef.current;
    if (!map) return;
    const pitch = map.getPitch() > 0 ? 0 : 55;
    map.easeTo({ pitch, duration: 500 });
  }

  function applyMapStyle(styleUrl) {
    const map = mapRef.current;
    if (!map) return;
    setMapStyle(styleUrl);
    try {
      map.setStyle(styleUrl);
    } catch (err) {
      // ignore style switching errors
    }
  }

  function setupMapSourcesAndLayers(map) {
    if (!map) return;

  if (!map.getSource("routes")) {
    map.addSource("routes", { type: "geojson", data: emptyCollection });
  }
  if (!map.getSource("drivers")) {
    map.addSource("drivers", { type: "geojson", data: emptyCollection });
  }
  if (!map.getSource("pickups")) {
    map.addSource("pickups", { type: "geojson", data: emptyCollection });
  }
  if (!map.getSource("dropoffs")) {
    map.addSource("dropoffs", { type: "geojson", data: emptyCollection });
  }

  ensureLayer(map, {
    id: "route-lines",
    type: "line",
    source: "routes",
    paint: {
      "line-color": "#118649",
      "line-width": 4,
      "line-opacity": 0.8,
    },
  });

    ensureLayer(map, {
      id: "pickup-points",
      type: "circle",
      source: "pickups",
      paint: {
        "circle-radius": 8,
        "circle-color": "#f2be35",
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 2,
        "circle-opacity": 0.95,
      },
    });

    ensureLayer(map, {
      id: "dropoff-points",
      type: "circle",
      source: "dropoffs",
      paint: {
        "circle-radius": 8,
        "circle-color": "#c94530",
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 2,
        "circle-opacity": 0.95,
      },
    });

    ensureLayer(map, {
      id: "driver-points",
      type: "circle",
      source: "drivers",
      paint: {
        "circle-radius": 7,
        "circle-color": "#0f8d4c",
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 2,
        "circle-opacity": 0.98,
      },
    });

    ensureLayer(map, {
      id: "driver-count-labels",
      type: "symbol",
      source: "drivers",
      layout: {
        "text-field": ["get", "subLabel"],
        "text-size": 11,
        "text-offset": [0, 1.1],
        "text-anchor": "top",
        "icon-image": "marker-15",
        "icon-allow-overlap": true,
      },
      paint: {
        "text-color": "#1f2d2a",
        "text-halo-color": "#ffffff",
        "text-halo-width": 1.2,
      },
    });
  }

  function ensure3DBuildings(map) {
    try {
      if (!map || !map.getStyle) return;
      const style = map.getStyle();
      if (!style || !Array.isArray(style.layers)) return;

      // If style already has any fill-extrusion layers, nothing to do
      const hasExtrusion = style.layers.some((l) => l && l.type === "fill-extrusion");
      if (hasExtrusion) return;

      // Try to find an existing building layer to base extrusion on
      const buildingLayer = style.layers.find((l) => l && l.id && l.id.toLowerCase().includes("building"));
      if (!buildingLayer || !buildingLayer.source) return;

      const extrusionLayer = {
        id: "__injected_building_extrusion",
        type: "fill-extrusion",
        source: buildingLayer.source,
      };

      if (buildingLayer["source-layer"]) {
        extrusionLayer["source-layer"] = buildingLayer["source-layer"];
      }

      extrusionLayer.paint = {
        "fill-extrusion-color": "#dcdcdc",
        "fill-extrusion-height": ["coalesce", ["get", "height"], 12],
        "fill-extrusion-base": ["coalesce", ["get", "min_height"], 0],
        "fill-extrusion-opacity": 0.95,
      };

      // Insert the extrusion just below any existing building fill if possible
      const beforeId = buildingLayer.id || undefined;
      try {
        map.addLayer(extrusionLayer, beforeId);
      } catch (err) {
        // fallback: add without before
        try { map.addLayer(extrusionLayer); } catch (e) { /* ignore */ }
      }
    } catch (err) {
      // non-fatal
      console.debug("ensure3DBuildings error:", err);
    }
  }

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !mapReady) return;

    const handleStyleLoaded = () => {
      if (!map.isStyleLoaded()) return;
      setupMapSourcesAndLayers(map);
      ensure3DBuildings(map);
      setGeoJsonSource(map, "routes", mapData.routeCollection);
      setGeoJsonSource(map, "drivers", mapData.driverCollection);
      setGeoJsonSource(map, "pickups", mapData.pickupCollection);
      setGeoJsonSource(map, "dropoffs", mapData.dropoffCollection);
    };

    map.on("styledata", handleStyleLoaded);
    return () => {
      map.off("styledata", handleStyleLoaded);
    };
  }, [mapData, mapReady]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !mapReady) return;

    setGeoJsonSource(map, "routes", mapData.routeCollection);
    setGeoJsonSource(map, "drivers", mapData.driverCollection);
    setGeoJsonSource(map, "pickups", mapData.pickupCollection);
    setGeoJsonSource(map, "dropoffs", mapData.dropoffCollection);

    if (!hasFittedRef.current && mapData.hasBounds) {
      map.fitBounds(
        [
          [mapData.bounds.minLng, mapData.bounds.minLat],
          [mapData.bounds.maxLng, mapData.bounds.maxLat],
        ],
        {
          padding: 48,
          duration: 900,
          maxZoom: 15,
        }
      );
      hasFittedRef.current = true;
    }
  }, [mapData, mapReady]);

  const summary = useMemo(() => {
    return {
      drivers: mapData.driverCollection.features.length,
      rides: mapData.routeCollection.features.length,
      updates: mapData.latestUpdate,
    };
  }, [mapData]);

  const driverPreview = onlineDrivers.slice(0, 4);
  const ridePreview = activeRides.slice(0, 3);

  return (
    <section className="panel">
      <div className="panel-header section-header">
        <div>
          <p className="panel-label">Live tracking</p>
          <h3>Live Map Overview</h3>
        </div>
        <div className="section-metrics">
          <div className="mini-metric">
            <span>Online Drivers</span>
            <strong className="metric-compact">{summary.drivers}</strong>
          </div>
          <div className="mini-metric">
            <span>Active Rides</span>
            <strong className="metric-compact">{summary.rides}</strong>
          </div>
        </div>
      </div>

      {mapError ? <div className="error-banner">{mapError}</div> : null}

      <div className="map-frame">
        <div className="map-overlay">
          <div className="map-status-row">
            <StatusPill label="Carto Basemap" tone="success" />
            <StatusPill label="MapLibre GL" tone="info" />
            <StatusPill label={mapReady ? "Live" : "Connecting"} tone={mapReady ? "success" : "warning"} />
          </div>
        </div>

        <div ref={containerRef} className="map-container" aria-label="Live tracking map" />

        

        {mapError ? <div className="map-fallback">{mapError}</div> : null}
      </div>

      <div className="map-legend">
        <div className="map-legend-group">
          <p className="panel-label">Latest sync</p>
          <strong className="metric-compact">{summary.updates ? formatDateTime(summary.updates) : "Waiting for data"}</strong>
          <span className="muted small-text">Routes and markers refresh automatically.</span>
        </div>

        <div className="map-legend-group">
          <p className="panel-label">Driver feed</p>
          <div className="map-list">
            {driverPreview.length === 0 ? (
              <span className="muted small-text">No active drivers.</span>
            ) : (
              driverPreview.map((driver) => (
                <div key={driver.id} className="map-list-item">
                  <span className="map-dot map-dot-driver" />
                  <div className="cell-stack">
                    <strong>{asText(driver.full_name) || "-"}</strong>
                    <span className="muted small-text">{shortenText(driver.tricycle_number, 10, 4)}</span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        <div className="map-legend-group">
          <p className="panel-label">Active rides</p>
          <div className="map-list">
            {ridePreview.length === 0 ? (
              <span className="muted small-text">No active rides.</span>
            ) : (
              ridePreview.map((ride) => (
                <div key={ride.id} className="map-list-item">
                  <span className="map-dot map-dot-ride" />
                  <div className="cell-stack">
                    <strong>Ride #{ride.id}</strong>
                    <span className="muted small-text">{asText(ride.passenger_name) || "-"}</span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
