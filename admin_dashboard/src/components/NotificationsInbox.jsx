import { useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import { formatDateTime } from "../utils/admin-formatters";
import { displayTitle, notificationMeta, shortTime } from "../utils/notification-meta";
import BookingCard from "./BookingCard";
import InboxLayout, { Field, InboxRow, InboxToolbar, RelatedCard } from "./InboxLayout";

/**
 * Gmail-style notifications: the list, and the open notification with the
 * full message and the record it's about (booking, application, SOS alert
 * or report).
 */
export default function NotificationsInbox({
  notifications = [],
  unreadCount = 0,
  selectedId = null,
  onSelect,
  onMarkAllRead,
  sosAlerts = [],
  complaints = [],
  onOpenBooking,
  onOpenReport,
  onOpenSection,
  // Pages this admin may open; links to others aren't shown.
  canOpenSection = () => true,
}) {
  const [filter, setFilter] = useState("all");
  const [search, setSearch] = useState("");

  const visible = useMemo(() => {
    const term = search.trim().toLowerCase();
    return notifications.filter((n) => {
      if (filter === "unread" && n.isRead) return false;
      if (!term) return true;
      return [n.title, n.body, notificationMeta(n.type).label].some((v) =>
        String(v || "").toLowerCase().includes(term)
      );
    });
  }, [notifications, filter, search]);

  const selected = notifications.find((n) => n.id === selectedId) || null;

  return (
    <InboxLayout
      placeholder="Select a notification to read it."
      toolbar={
        <InboxToolbar
          search={search}
          onSearch={setSearch}
          searchPlaceholder="Search notifications"
          tabs={[
            { key: "all", label: "All" },
            { key: "unread", label: `Unread${unreadCount ? ` (${unreadCount})` : ""}` },
          ]}
          activeTab={filter}
          onTab={setFilter}
          action={
            <button type="button" className="inbox-action" onClick={onMarkAllRead} disabled={!unreadCount}>
              Mark all read
            </button>
          }
        />
      }
      reading={
        selected ? (
          <NotificationReader
            notification={selected}
            sosAlerts={sosAlerts}
            complaints={complaints}
            onBack={() => onSelect?.(null)}
            onOpenBooking={onOpenBooking}
            onOpenReport={onOpenReport}
            onOpenSection={onOpenSection}
            canOpenSection={canOpenSection}
          />
        ) : null
      }
    >
      {visible.length === 0 ? (
        <div className="state-block">{notifications.length === 0 ? "No notifications yet." : "Nothing matches."}</div>
      ) : (
        <ul className="inbox-rows">
          {visible.map((n) => (
            <InboxRow
              key={n.id}
              unread={!n.isRead}
              selected={n.id === selectedId}
              icon={notificationMeta(n.type).icon}
              title={displayTitle(n)}
              snippet={n.body}
              time={shortTime(n.createdAt)}
              onClick={() => onSelect?.(n)}
            />
          ))}
        </ul>
      )}
    </InboxLayout>
  );
}

function NotificationReader({
  notification,
  sosAlerts,
  complaints,
  onBack,
  onOpenBooking,
  onOpenReport,
  onOpenSection,
  canOpenSection,
}) {
  const meta = notificationMeta(notification.type);
  const info = notification.metadata || {};
  const bookingId = info.bookingId || null;
  const applicationId = info.applicationId || null;
  const sos = info.sosId ? sosAlerts.find((a) => a.id === info.sosId) : null;
  const complaint = info.complaintId ? complaints.find((c) => c.id === info.complaintId) : null;

  // Bookings and applications aren't all loaded on the dashboard, so the
  // one this notification is about is fetched when it's opened. SOS alerts
  // and reports are already loaded — their booking isn't fetched.
  const hasLoadedRecord = Boolean(sos || complaint);
  const [related, setRelated] = useState({ status: "idle", data: null });
  useEffect(() => {
    let cancelled = false;
    const url = applicationId
      ? `/admin/drivers/${applicationId}`
      : bookingId && !hasLoadedRecord
        ? `/admin/bookings/${bookingId}`
        : null;
    if (!url) {
      setRelated({ status: "idle", data: null });
      return undefined;
    }
    setRelated({ status: "loading", data: null });
    apiClient
      .get(url)
      .then(({ data }) => !cancelled && setRelated({ status: "ready", data: data?.data || null }))
      .catch(() => !cancelled && setRelated({ status: "error", data: null }));
    return () => {
      cancelled = true;
    };
  }, [applicationId, bookingId, hasLoadedRecord]);

  return (
    <article className="reader">
      <button type="button" className="btn btn-ghost btn-sm reader-back" onClick={onBack}>
        ← Back to notifications
      </button>
      <span className="reader-category">
        <span aria-hidden="true">{meta.icon}</span>
        {meta.label}
      </span>
      <h2 className="reader-title">{displayTitle(notification)}</h2>
      <div className="reader-date">{formatDateTime(notification.createdAt)}</div>
      <p className="reader-body">{notification.body || "(No message)"}</p>

      {sos ? (
        <RelatedCard title={`SOS alert #${sos.id}`}>
          <Field label="Status" value={sos.status === "active" ? "open" : sos.status} />
          {sos.acknowledgedBy ? <Field label="Handled by" value={sos.acknowledgedBy.name} /> : null}
          {sos.resolutionNote ? <Field label="Resolution" value={sos.resolutionNote} /> : null}
          <Field label="From" value={sos.senderName || sos.passengerName || sos.driverName} />
          <Field label="Contact" value={sos.contact || sos.passengerPhone || sos.driverPhone} />
          {sos.bookingId ? <Field label="Booking" value={`#${sos.bookingId}`} /> : null}
          {sos.lat != null && sos.lng != null ? (
            <Field
              label="Location"
              value={
                <a href={`https://www.openstreetmap.org/?mlat=${sos.lat}&mlon=${sos.lng}#map=17/${sos.lat}/${sos.lng}`} target="_blank" rel="noreferrer">
                  {Number(sos.lat).toFixed(5)}, {Number(sos.lng).toFixed(5)} ↗
                </a>
              }
            />
          ) : null}
        </RelatedCard>
      ) : null}

      {complaint ? (
        <RelatedCard title={`Report #${complaint.id}`}>
          <Field label="Status" value={complaint.status} />
          <Field label="Category" value={String(complaint.category || "").replace(/_/g, " ")} />
          <Field label="Reported by" value={complaint.reporter} />
          <Field label="About" value={complaint.reportedUser} />
          {complaint.rideId ? <Field label="Ride" value={`#${complaint.rideId}`} /> : null}
          <Field label="Details" value={complaint.description} />
        </RelatedCard>
      ) : null}

      {related.status === "loading" ? <div className="reader-related muted">Loading details…</div> : null}
      {related.status === "error" ? (
        <div className="reader-related muted">Couldn&apos;t load the details. They may have been removed.</div>
      ) : null}

      {related.status === "ready" && related.data && applicationId ? (
        <RelatedCard title="Driver application">
          <Field label="Applicant" value={related.data.fullName} />
          <Field label="Status" value={related.data.approvalStatus} />
          <Field label="Phone" value={related.data.phone} />
          <Field label="Email" value={related.data.email} />
          <Field label="Tricycle" value={related.data.tricycleNumber} />
          <Field label="Submitted" value={formatDateTime(related.data.createdAt)} />
        </RelatedCard>
      ) : null}

      {related.status === "ready" && related.data && !applicationId ? <BookingCard booking={related.data} /> : null}

      <div className="reader-actions">
        {bookingId && onOpenBooking ? (
          <button type="button" className="btn btn-primary btn-sm" onClick={() => onOpenBooking(bookingId)}>
            Open booking #{bookingId}
          </button>
        ) : null}
        {info.complaintId && onOpenReport ? (
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => onOpenReport(info.complaintId)}>
            Open report #{info.complaintId}
          </button>
        ) : meta.section && canOpenSection(meta.section) && !(bookingId && meta.section === "bookings") ? (
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => onOpenSection?.(meta.section, info)}>
            {meta.section === "applications"
              ? "Review application"
              : meta.section === "sos"
                ? "Go to SOS alerts"
                : meta.section === "support"
                  ? "Open message"
                  : "Open page"}
          </button>
        ) : null}
      </div>
    </article>
  );
}
