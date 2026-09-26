import { useEffect, useState } from "react";
import { apiClient } from "../api/client";

const STATUS_LABELS = {
  pending: "Pending",
  approved: "Approved",
  rejected: "Unqualified",
  needs_correction: "Action Required",
  archived: "Archived",
};

function formatDate(value) {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}

export default function StatusPage({ application, onUpdateApplication, onLogout }) {
  const [timeline, setTimeline] = useState([]);
  const [loadingTimeline, setLoadingTimeline] = useState(true);

  useEffect(() => {
    let cancelled = false;
    apiClient
      .get("/auth/v2/driver-application/timeline")
      .then(({ data }) => {
        if (!cancelled) setTimeline(Array.isArray(data?.data) ? data.data : []);
      })
      .catch(() => {})
      .finally(() => {
        if (!cancelled) setLoadingTimeline(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const status = application?.status || "pending";
  const canUpdate = status === "needs_correction" || status === "rejected";

  return (
    <div className="screen">
      <div className="shell">
        <div className="brand">
          <span className="brand-emoji">🛺</span>
          <span className="brand-title">FindMeTricycle</span>
        </div>

        <div className="card">
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8 }}>
            <h2 style={{ margin: 0 }}>Application Status</h2>
            <span className={`badge status-${status}`}>{STATUS_LABELS[status] || status}</span>
          </div>

          {status === "pending" ? (
            <div className="banner banner-warning">
              Your application is waiting for admin review. We'll email you when there's an update.
            </div>
          ) : null}

          {status === "approved" ? (
            <div className="banner banner-success">
              🎉 Congratulations! Your application was approved. Open the FindMeTricycle app and switch to
              Driver Mode from your Profile screen.
            </div>
          ) : null}

          {status === "rejected" ? (
            <div className="banner banner-error">
              Your application was not approved.
              {application?.rejection_reason ? ` Reason: ${application.rejection_reason}` : ""}
            </div>
          ) : null}

          {status === "needs_correction" ? (
            <div className="banner banner-warning">
              Action needed: {application?.correction_note || "Please review and update your documents."}
            </div>
          ) : null}

          <div className="review-section">
            <h3>Plate Number</h3>
            <div className="review-row">
              <span>Plate</span>
              <span>{application?.plate_number || "-"}</span>
            </div>
            <div className="review-row">
              <span>Submitted</span>
              <span>{formatDate(application?.submitted_at)}</span>
            </div>
          </div>

          <div className="review-section">
            <h3>📍 Application Timeline</h3>
            {loadingTimeline ? (
              <p>Loading timeline…</p>
            ) : timeline.length === 0 ? (
              <p>No timeline events yet.</p>
            ) : (
              <div className="timeline">
                {timeline.map((item) => (
                  <div className="timeline-item" key={item.id}>
                    <div className="timeline-dot" />
                    <div className="timeline-body">
                      <div className="timeline-title">{STATUS_LABELS[item.status] || item.status}</div>
                      <div className="timeline-time">{formatDate(item.created_at)}</div>
                      {item.note ? <div className="timeline-note">{item.note}</div> : null}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {canUpdate ? (
            <button type="button" className="btn btn-primary" onClick={onUpdateApplication} style={{ marginBottom: 10 }}>
              {status === "needs_correction" ? "Update Application" : "Resubmit Application"}
            </button>
          ) : null}

          <button type="button" className="btn btn-ghost" onClick={onLogout} style={{ width: "100%" }}>
            Sign Out
          </button>
        </div>
      </div>
    </div>
  );
}
