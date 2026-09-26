import { useState } from "react";

export default function ConfirmDialog({
  open,
  title,
  message,
  requireInput = false,
  inputLabel = "Reason",
  defaultValue = "",
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  danger = false,
  onConfirm,
  onCancel,
}) {
  const [value, setValue] = useState(defaultValue);

  if (!open) return null;

  function handleConfirm() {
    if (requireInput && !value.trim()) return;
    onConfirm(requireInput ? value.trim() : true);
    setValue(defaultValue);
  }

  function handleCancel() {
    setValue(defaultValue);
    onCancel();
  }

  return (
    <div className="modal-overlay open">
      <div className="modal" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <div className="modal-title">{title}</div>
          <button className="modal-close" type="button" onClick={handleCancel}>
            ×
          </button>
        </div>
        <div className="modal-body">
          {message ? <p style={{ marginTop: 0 }}>{message}</p> : null}
          {requireInput ? (
            <div className="form-group">
              <label className="form-label">{inputLabel}</label>
              <textarea
                className="form-input"
                rows={3}
                value={value}
                onChange={(e) => setValue(e.target.value)}
                autoFocus
                style={{ width: "100%", resize: "vertical" }}
              />
            </div>
          ) : null}
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" type="button" onClick={handleCancel}>
            {cancelLabel}
          </button>
          <button
            className={danger ? "btn btn-danger" : "btn btn-success"}
            type="button"
            onClick={handleConfirm}
            disabled={requireInput && !value.trim()}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
