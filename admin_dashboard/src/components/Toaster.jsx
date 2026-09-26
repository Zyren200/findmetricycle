import React from 'react';

export default function Toaster({ toasts = [], onRemove = () => {} }) {
  return (
    <div className="toast-container">
      {toasts.map((t) => (
        <div key={t.id} className={`toast ${t.type || "info"}`}>
          <div style={{ flex: 1, minWidth: 0 }}>{t.message}</div>
          <button className="ghost-btn btn-sm" onClick={() => onRemove(t.id)}>×</button>
        </div>
      ))}
    </div>
  );
}
