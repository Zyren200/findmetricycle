// How each admin notification type is shown, and which page acts on it.
const TYPES = {
  driver_application: { icon: "🧾", label: "Driver application", section: "applications" },
  driver_document_resubmission: { icon: "🧾", label: "Documents resubmitted", section: "applications" },
  driver_documents_flagged: { icon: "⚠️", label: "Documents flagged", section: "applications" },
  sos_alert: { icon: "🚨", label: "SOS alert", section: "sos" },
  sos_escalation: { icon: "⏰", label: "SOS not acknowledged", section: "sos" },
  driver_report: { icon: "📝", label: "Report", section: "complaints" },
  new_booking: { icon: "🛺", label: "New booking", section: "bookings" },
  booking_cancelled: { icon: "✖️", label: "Booking cancelled", section: "bookings" },
};

const FALLBACK = { icon: "🔔", label: "Notification", section: null };

export function notificationMeta(type) {
  return TYPES[type] || FALLBACK;
}

// Some titles already start with an emoji ("🚨 SOS Alert"); the type icon
// is shown beside them, so drop the repeat.
export function displayTitle(notification) {
  return String(notification?.title || "").replace(/^\p{Extended_Pictographic}️?\s*/u, "");
}

// Gmail-style list time: "9:15 AM" today, "Yesterday", "Sep 26", or with
// the year when it isn't this year.
export function shortTime(value, now = new Date()) {
  const date = value ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) return "";
  const sameDay = date.toDateString() === now.toDateString();
  if (sameDay) return date.toLocaleTimeString("en-PH", { hour: "numeric", minute: "2-digit" });
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  if (date.toDateString() === yesterday.toDateString()) return "Yesterday";
  return date.toLocaleDateString("en-PH", {
    month: "short",
    day: "numeric",
    ...(date.getFullYear() === now.getFullYear() ? {} : { year: "numeric" }),
  });
}
