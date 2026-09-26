import React from "react";
import { formatDateTime } from "../utils/admin-formatters";

export default function NotificationsPanel({ notifications = [], onClose, onMarkAllRead, onMarkRead }) {
  return (
    <div className="notifications-panel">
      <div className="notifications-header">
        <strong>Notifications</strong>
        <div>
          <button className="btn btn-ghost btn-sm" onClick={onMarkAllRead}>Mark all read</button>
          <button className="btn btn-ghost btn-sm" onClick={onClose} style={{ marginLeft: 8 }}>Close</button>
        </div>
      </div>
      <div className="notifications-list">
        {notifications.length === 0 ? (
          <div className="state-block">No notifications</div>
        ) : (
          notifications.map((n) => (
            <div key={n.id} className={`notification-item ${n.isRead ? "read" : "unread"}`}>
              <div className="notification-main">
                <div className="notification-title">{n.title}</div>
                <div className="notification-time muted">{formatDateTime(n.createdAt || n.created_at)}</div>
              </div>
              <div className="notification-body">{n.body}</div>
              <div className="notification-actions">
                {!n.isRead && <button className="btn btn-ghost btn-sm" onClick={() => onMarkRead(n.id)}>Mark read</button>}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
