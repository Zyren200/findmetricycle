import React from "react";
import { formatDateTime } from "../utils/admin-formatters";

const TYPE_ICONS = {
  driver_application: "🧾",
  driver_document_resubmission: "🧾",
  driver_documents_flagged: "⚠️",
  sos_alert: "🚨",
  driver_report: "📝",
  new_booking: "🛺",
  booking_cancelled: "✖️",
};

export default function NotificationsPanel({
  notifications = [],
  unreadCount = 0,
  onClose,
  onMarkAllRead,
  onMarkRead,
  onOpen,
}) {
  return (
    <div className="notifications-panel">
      <div className="notifications-header">
        <strong>
          Notifications{unreadCount ? <span className="muted"> · {unreadCount} unread</span> : null}
        </strong>
        <div>
          <button className="btn btn-ghost btn-sm" type="button" onClick={onMarkAllRead} disabled={!unreadCount}>
            Mark all read
          </button>
          <button className="btn btn-ghost btn-sm" type="button" onClick={onClose} style={{ marginLeft: 8 }}>
            Close
          </button>
        </div>
      </div>
      <div className="notifications-list">
        {notifications.length === 0 ? (
          <div className="state-block">No notifications</div>
        ) : (
          notifications.map((n) => (
            <div
              key={n.id}
              className={`notification-item ${n.isRead ? "read" : "unread"}`}
              role="button"
              tabIndex={0}
              style={{ cursor: "pointer" }}
              onClick={() => onOpen?.(n)}
              onKeyDown={(event) => {
                if (event.key === "Enter") onOpen?.(n);
              }}
            >
              <div className="notification-main">
                <div className="notification-title">
                  {!n.isRead ? <span className="notif-dot" aria-label="unread" /> : null}
                  <span style={{ marginRight: 6 }}>{TYPE_ICONS[n.type] || "🔔"}</span>
                  {n.title}
                </div>
                <div className="notification-time muted">{formatDateTime(n.createdAt || n.created_at)}</div>
              </div>
              <div className="notification-body">{n.body}</div>
              {!n.isRead ? (
                <div className="notification-actions">
                  <button
                    className="btn btn-ghost btn-sm"
                    type="button"
                    onClick={(event) => {
                      event.stopPropagation(); // mark read without navigating
                      onMarkRead(n.id);
                    }}
                  >
                    Mark read
                  </button>
                </div>
              ) : null}
            </div>
          ))
        )}
      </div>
    </div>
  );
}
