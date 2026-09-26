// Marker images for the admin live map, drawn on a canvas at runtime (no
// image assets) so they match the mobile app: a tricycle badge for drivers,
// a green pickup pin and a red drop-off pin.

export const MARKER_ICONS = {
  driver: "fmt-driver",
  pickup: "fmt-pickup",
  dropoff: "fmt-dropoff",
};

const GREEN = "#0e8c46";
const RED = "#c94530";
const PICKUP_GREEN = "#118649";

function makeCanvas(width, height, ratio) {
  const canvas = document.createElement("canvas");
  canvas.width = Math.ceil(width * ratio);
  canvas.height = Math.ceil(height * ratio);
  const ctx = canvas.getContext("2d");
  ctx.scale(ratio, ratio);
  return { canvas, ctx };
}

function toImage(canvas, ctx) {
  return ctx.getImageData(0, 0, canvas.width, canvas.height);
}

// Round badge with the 🛺 (auto-rickshaw) emoji — reads as "tricycle".
function driverBadge(ratio) {
  const size = 40;
  const { canvas, ctx } = makeCanvas(size, size, ratio);
  const c = size / 2;
  const r = size / 2 - 3;

  ctx.shadowColor = "rgba(0,0,0,0.35)";
  ctx.shadowBlur = 4;
  ctx.shadowOffsetY = 1;
  ctx.beginPath();
  ctx.arc(c, c, r, 0, Math.PI * 2);
  ctx.fillStyle = "#ffffff";
  ctx.fill();
  ctx.shadowColor = "transparent";

  ctx.lineWidth = 3;
  ctx.strokeStyle = GREEN;
  ctx.stroke();

  ctx.font = `20px "Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji", sans-serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("🛺", c, c + 1);
  return toImage(canvas, ctx);
}

// Teardrop pin (tip at the bottom centre). `inner` draws the white mark.
function pin(color, ratio, inner) {
  const width = 30;
  const height = 40;
  const { canvas, ctx } = makeCanvas(width, height, ratio);
  const r = width / 2 - 3;
  const cx = width / 2;
  const cy = r + 3;
  const tipY = height - 2;

  ctx.beginPath();
  ctx.moveTo(cx, tipY);
  ctx.quadraticCurveTo(cx - r * 0.95, cy + r * 0.9, cx - r, cy);
  ctx.arc(cx, cy, r, Math.PI, 0);
  ctx.quadraticCurveTo(cx + r * 0.95, cy + r * 0.9, cx, tipY);
  ctx.closePath();

  ctx.shadowColor = "rgba(0,0,0,0.35)";
  ctx.shadowBlur = 4;
  ctx.shadowOffsetY = 1;
  ctx.fillStyle = color;
  ctx.fill();
  ctx.shadowColor = "transparent";
  ctx.lineWidth = 2.5;
  ctx.strokeStyle = "#ffffff";
  ctx.stroke();

  ctx.fillStyle = "#ffffff";
  inner(ctx, cx, cy, r);
  return toImage(canvas, ctx);
}

function pickupPin(ratio) {
  return pin(PICKUP_GREEN, ratio, (ctx, cx, cy, r) => {
    ctx.beginPath();
    ctx.arc(cx, cy, r * 0.38, 0, Math.PI * 2);
    ctx.fill();
  });
}

function dropoffPin(ratio) {
  return pin(RED, ratio, (ctx, cx, cy, r) => {
    // A small flag: pole + pennant.
    const s = r * 0.9;
    ctx.fillRect(cx - s * 0.45, cy - s * 0.55, s * 0.14, s * 1.1);
    ctx.beginPath();
    ctx.moveTo(cx - s * 0.31, cy - s * 0.55);
    ctx.lineTo(cx + s * 0.5, cy - s * 0.3);
    ctx.lineTo(cx - s * 0.31, cy - s * 0.05);
    ctx.closePath();
    ctx.fill();
  });
}

/** Adds the marker images to `map` (safe to call again after a style change). */
export function registerMarkerIcons(map) {
  const ratio = Math.max(1, Math.min(3, window.devicePixelRatio || 1));
  const images = {
    [MARKER_ICONS.driver]: () => driverBadge(ratio),
    [MARKER_ICONS.pickup]: () => pickupPin(ratio),
    [MARKER_ICONS.dropoff]: () => dropoffPin(ratio),
  };
  for (const [name, draw] of Object.entries(images)) {
    if (!map.hasImage(name)) {
      map.addImage(name, draw(), { pixelRatio: ratio });
    }
  }
}
