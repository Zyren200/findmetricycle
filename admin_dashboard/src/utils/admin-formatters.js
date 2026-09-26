export function asText(value) {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  return text.length ? text : null;
}

export function asNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function formatMoney(value, currency = "PHP") {
  return `${currency} ${asNumber(value).toFixed(2)}`;
}

export function formatDateTime(value) {
  const parsed = value ? new Date(value) : null;
  if (!parsed || Number.isNaN(parsed.getTime())) return "-";

  const year = String(parsed.getFullYear()).padStart(4, "0");
  const month = String(parsed.getMonth() + 1).padStart(2, "0");
  const day = String(parsed.getDate()).padStart(2, "0");
  const hour = String(parsed.getHours()).padStart(2, "0");
  const minute = String(parsed.getMinutes()).padStart(2, "0");
  return `${year}-${month}-${day} ${hour}:${minute}`;
}

export function shortenText(value, prefix = 10, suffix = 8) {
  const text = asText(value);
  if (!text) return "-";
  if (text.length <= prefix + suffix + 3) return text;
  return `${text.slice(0, prefix)}...${text.slice(-suffix)}`;
}

export function bookingStatusLabel(status) {
  switch (asText(status)?.toLowerCase()) {
    case "pending":
      return "Pending";
    case "accepted":
      return "Accepted";
    case "ongoing":
      return "Ongoing";
    case "completed":
      return "Completed";
    case "cancelled":
      return "Cancelled";
    default:
      return asText(status) || "-";
  }
}

const BACKEND_ORIGIN =
  import.meta.env.VITE_SOCKET_URL ||
  (import.meta.env.VITE_API_BASE_URL || "").replace(/\/api\/?$/, "") ||
  "";

// Driver license/permit/selfie documents are served via an authenticated
// route (see backend/src/routes/documents.routes.js), not the public
// /uploads static mount. A plain <a href> can't set an Authorization
// header, so the admin's token rides along as a query param.
export function resolveDriverDocumentUrl(path) {
  if (!path) return null;
  if (/^https?:\/\//i.test(path)) return path;

  const token = localStorage.getItem("fmt_admin_token") || sessionStorage.getItem("fmt_admin_token") || "";
  const filenameMatch = path.match(/\/uploads\/driver-docs\/([^/?]+)$/);
  if (filenameMatch) {
    return `${BACKEND_ORIGIN}/api/documents/driver/${filenameMatch[1]}?token=${encodeURIComponent(token)}`;
  }

  return BACKEND_ORIGIN ? `${BACKEND_ORIGIN}${path}` : path;
}

export function statusTone(value) {
  const normalized = asText(value)?.toLowerCase() || "";
  if (["approved", "active", "completed", "online"].includes(normalized)) {
    return "success";
  }
  if (["rejected", "cancelled", "disabled", "suspended", "offline", "expired"].includes(normalized)) {
    return "danger";
  }
  if (["pending", "processing", "accepted", "ongoing"].includes(normalized)) {
    return "warning";
  }
  return "neutral";
}
