import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../../api/client";
import { useAuth } from "../../context/AuthContext";
import { Link, useDocumentTitle } from "../../router";

const STATUS = {
  none: {
    icon: "📋",
    label: "No Application",
    tone: "muted",
    heading: "No Application Found",
    message: "You have not submitted a driver application yet.",
  },
  pending: {
    icon: "⏳",
    label: "Pending Review",
    tone: "sky",
    heading: "Application Submitted",
    message: "Your driver application is waiting for review by our admin team. We'll email you when there's an update.",
  },
  approved: {
    icon: "✅",
    label: "Approved",
    tone: "teal",
    heading: "Application Approved!",
    message: "Congratulations! Your driver application has been approved. Driver Mode is now available in your FindMeTricycle account.",
  },
  rejected: {
    icon: "❌",
    label: "Not Approved",
    tone: "coral",
    heading: "Application Not Approved",
    message: "Your driver application was not approved at this time.",
  },
  needs_correction: {
    icon: "🔄",
    label: "Action Required",
    tone: "amber",
    heading: "Resubmission Required",
    message: "Your application requires corrections. Please review the note below and update your application.",
  },
};

const TIMELINE_LABELS = {
  pending: "Submitted — Pending review",
  approved: "Approved",
  rejected: "Not approved",
  needs_correction: "Corrections requested",
  archived: "Archived",
};

function formatDate(value, withTime = false) {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleString("en-PH", withTime ? { dateStyle: "medium", timeStyle: "short" } : { dateStyle: "long" });
}

export default function StatusPage() {
  useDocumentTitle("Application Status — FindMeTricycle");
  const { isAuthenticated, user } = useAuth();
  const [application, setApplication] = useState(null);
  const [timeline, setTimeline] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [{ data: statusRes }, timelineRes] = await Promise.all([
        apiClient.get("/auth/v2/driver-status"),
        apiClient.get("/auth/v2/driver-application/timeline").catch(() => null),
      ]);
      const app = statusRes?.data || null;
      setApplication(app && app.status !== "archived" ? app : null);
      const items = timelineRes?.data?.data;
      setTimeline(Array.isArray(items) ? items : []);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load your application status.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (isAuthenticated) load();
    else setLoading(false);
  }, [isAuthenticated, load]);

  if (!isAuthenticated) {
    return (
      <div className="form-page">
        <div className="container" style={{ maxWidth: 448 }}>
          <div className="center-block">
            <div className="big">🔒</div>
            <h1>Sign In Required</h1>
            <p>You need to be signed in to check your driver application status.</p>
            <Link to="/driver/apply" className="cta cta-primary">
              Log In to Check Status
            </Link>
          </div>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="form-page">
        <div className="center-block">
          <div className="spinner" />
          <p>Loading your application status...</p>
        </div>
      </div>
    );
  }

  const status = application?.status || "none";
  const cfg = STATUS[status] || STATUS.pending;
  const canUpdate = status === "needs_correction" || status === "rejected";
  const adminNote =
    status === "rejected" ? application?.rejection_reason : status === "needs_correction" ? application?.correction_note : null;

  return (
    <div className="form-page">
      <div className="container container-form">
        <div className="form-page-head">
          <Link to="/driver" className="back-link">
            ← Driver Information
          </Link>
          <h1>Application Status</h1>
          <p>
            Hello{user?.fullName || user?.full_name ? `, ${user.fullName || user.full_name}` : ""}. Here is the
            current status of your driver application.
          </p>
        </div>

        {error ? (
          <div className="banner banner-error">
            {error}{" "}
            <button type="button" className="link-btn" onClick={load}>
              Retry
            </button>
          </div>
        ) : null}

        <div className="stack">
          <div className={`status-card tone-${cfg.tone}`}>
            <div className="big">{cfg.icon}</div>
            <div style={{ flex: 1 }}>
              <h2>{cfg.heading}</h2>
              <p>{cfg.message}</p>
              {status === "approved" ? (
                <div className="inner-note">
                  <b style={{ color: "var(--teal)" }}>Driver Mode is ready</b>
                  <p>
                    Open FindMeTricycle on your phone and go to your Profile to switch to Driver Mode. Your
                    passenger account remains fully functional.
                  </p>
                </div>
              ) : null}
              {adminNote ? (
                <div className="inner-note">
                  <b style={{ color: status === "rejected" ? "var(--coral)" : "var(--amber)" }}>Admin Note</b>
                  <p>{adminNote}</p>
                </div>
              ) : null}
            </div>
          </div>

          {application ? (
            <div className="panel">
              <div className="panel-head">Application Details</div>
              <div className="panel-body">
                <div className="kv">
                  <span>Reference Number</span>
                  <span>#{application.id}</span>
                </div>
                <div className="kv">
                  <span>Status</span>
                  <span className={`badge status-${status}`}>{cfg.label}</span>
                </div>
                <div className="kv">
                  <span>Plate Number</span>
                  <span>{application.plate_number || "—"}</span>
                </div>
                <div className="kv">
                  <span>Submitted</span>
                  <span>{formatDate(application.submitted_at)}</span>
                </div>
                {application.reviewed_at ? (
                  <div className="kv">
                    <span>Last Updated</span>
                    <span>{formatDate(application.reviewed_at)}</span>
                  </div>
                ) : null}
              </div>
            </div>
          ) : null}

          {application ? (
            <div className="panel">
              <div className="panel-head">Verification</div>
              <div className="panel-body">
                <div className="kv">
                  <span>Driver&apos;s License</span>
                  <span>{application.license_image_url ? "↑ Uploaded" : "○ Not uploaded"}</span>
                </div>
                <div className="kv">
                  <span>Franchise / Business Permit</span>
                  <span>{application.business_permit_image_url ? "↑ Uploaded" : "○ Not uploaded"}</span>
                </div>
                <div className="kv">
                  <span>Face Verification</span>
                  <span>{(application.liveness_status || "pending").replace(/_/g, " ").toUpperCase()}</span>
                </div>
              </div>
            </div>
          ) : null}

          {timeline.length > 0 ? (
            <div className="panel">
              <div className="panel-head">Application Timeline</div>
              <div className="panel-body" style={{ paddingTop: 16 }}>
                <div className="timeline">
                  {timeline.map((item) => (
                    <div className="timeline-item" key={item.id}>
                      <div className="timeline-dot" />
                      <div className="timeline-body">
                        <div className="timeline-title">{TIMELINE_LABELS[item.status] || item.status}</div>
                        <div className="timeline-time">{formatDate(item.created_at, true)}</div>
                        {item.note ? <div className="timeline-note">{item.note}</div> : null}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ) : null}

          <div className="cta-row">
            {status === "none" ? (
              <Link to="/driver/apply" className="cta cta-primary">
                Start Application
              </Link>
            ) : null}
            {canUpdate ? (
              <Link to="/driver/apply?resubmit=1" className="cta cta-primary">
                {status === "needs_correction" ? "Update Application" : "Resubmit Application"}
              </Link>
            ) : null}
            <button type="button" className="cta cta-outline" onClick={load}>
              Refresh Status
            </button>
            <Link to="/contact" className="cta cta-outline" style={{ borderColor: "transparent" }}>
              Contact Support
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
