// MapLibre, loaded on demand (it's large) and set up once.
let loading = null;

export function loadMaplibre() {
  if (!loading) {
    loading = Promise.all([
      import("maplibre-gl"),
      // MapLibre v6 loads its tile worker from a file next to its own
      // module, which doesn't survive bundling — so let Vite bundle the
      // worker separately and point MapLibre at the emitted URL.
      import("maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url"),
    ]).then(([module, { default: workerUrl }]) => {
      const maplibregl = module.default || module;
      maplibregl.setWorkerUrl(workerUrl);
      return maplibregl;
    });
  }
  return loading;
}

export const MAP_STYLE_URL = "https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json";
