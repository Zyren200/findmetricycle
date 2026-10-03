import React from "react";
import { displayTitle, notificationMeta, shortTime } from "../utils/notification-meta";

// The bell dropdown: the latest notifications as a short preview. Clicking
// one opens it in full in the Notifications inbox.
export default function NotificationsPanel({
  notifications = [],
  unreadCount = 0,
  onClose,
  onMarkAllRead,
  onMarkRead,
  onOpen,
  onOpenInbox,
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
          notifications.slice(0, 20).map((n) => (
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
                  <span style={{ marginRight: 6 }}>{notificationMeta(n.type).icon}</span>
                  {displayTitle(n)}
                </div>
                <div className="notification-time muted">{shortTime(n.createdAt || n.created_at)}</div>
              </div>
              <div className="notification-body notification-preview">{n.body}</div>
              {!n.isRead ? (
                <div className="notification-actions">
                  <button
                    className="btn btn-ghost btn-sm"
                    type="button"
                    onClick={(event) => {
                      event.stopPropagation(); // mark read without opening
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
      {onOpenInbox ? (
        <div className="notifications-footer">
          <button className="btn btn-ghost btn-sm" type="button" onClick={onOpenInbox}>
            Open inbox →
          </button>
        </div>
      ) : null}
      <style>{`
        .notification-preview {
          display: -webkit-box;
          -webkit-line-clamp: 2;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }
        .notifications-footer {
          display: flex;
          justify-content: center;
          padding-top: 8px;
          border-top: 1px solid var(--border);
        }
      `}</style>
    </div>
  );
}
