import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../../api/client";
import { firstName } from "../../components/Layout";
import { ICON } from "../../components/Icons";
import { Alert, Head, useToast } from "../../components/ui";
import { useAuth } from "../../context/AuthContext";
import { Link, navigate, useDocumentTitle } from "../../router";

const ST = {
  none: { cls: "st-none", badge: "NO APPLICATION", title: "You haven't applied yet", text: "Start your driver application. It takes about 10 minutes.", ic: "doc" },
  pending: {
    cls: "st-pending",
    badge: "PENDING REVIEW",
    title: "We're reviewing your application",
    text: "The admin team will email you when there is an update. You don't need to do anything right now.",
    ic: "clock",
  },
  approved: {
    cls: "st-approved",
    badge: "APPROVED",
    title: "You're approved to drive",
    text: "Open the FindMeTricycle app, go to Profile, and tap Switch to Driver Mode.",
    ic: "check",
  },
  rejected: {
    cls: "st-rejected",
    badge: "NOT APPROVED",
    title: "Your application was not approved",
    text: "Read the reason below. You can update and resubmit your application.",
    ic: "x",
  },
  needs_correction: {
    cls: "st-action",
    badge: "ACTION REQUIRED",
    title: "Please update your application",
    text: "The admin asked for a correction. Fix the items in the note and resubmit.",
    ic: "alert",
  },
};

const TIMELINE_LABELS = {
  pending: "Submitted · pending review",
  approved: "Approved",
  rejected: "Not approved",
  needs_correction: "Correction requested",
  archived: "Archived",
};

const pill = (tone, text) => <span className={`pill ${tone}`}>{text}</span>;

// Server-side document check (verified | suspicious | unreadable | error).
function docCheck(uploaded, status) {
  if (!uploaded) return "Not uploaded";
  if (status === "verified") return pill("ok", "Passed");
  if (status === "suspicious" || status === "unreadable") return pill("warn", "Flagged for admin");
  return pill("", "Uploaded");
}

function faceCheck(status) {
  if (status === "passed") return pill("ok", "Passed");
  if (status === "failed") return pill("bad", "Failed");
  if (status === "needs_review") return pill("warn", "Needs review");
  return pill("", "Pending");
}

function fmt(value) {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleString("en-PH", { month: "short", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit" });
}

export default function StatusPage() {
  useDocumentTitle("FindMeTricycle · My Application");
  const { isAuthenticated, user } = useAuth();
  const toast = useToast();
  const [application, setApplication] = useState(null);
  const [timeline, setTimeline] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
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
      return true;
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load your application status.");
      return false;
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
      <section>
        <div className="wrap">
          <div className="form-card glass" style={{ textAlign: "center" }}>
            <span className="ic v" style={{ margin: "0 auto" }}>
              {ICON.user}
            </span>
            <h2 style={{ marginTop: 16 }}>Sign in to see your application</h2>
            <p className="muted" style={{ marginTop: 8 }}>
              Use the passenger account you applied with.
            </p>
            <div className="row" style={{ justifyContent: "center", marginTop: 22 }}>
              <button className="btn btn-hot" type="button" onClick={() => navigate("/driver/apply?return=status")}>
                Sign In {ICON.arrow}
              </button>
            </div>
          </div>
        </div>
      </section>
    );
  }

  if (loading) {
    return (
      <section>
        <div className="wrap">
          <div className="form-card glass" style={{ textAlign: "center" }}>
            <div className="spinner" aria-hidden="true" />
            <p className="muted" style={{ marginTop: 14 }}>
              Loading your application status…
            </p>
          </div>
        </div>
      </section>
    );
  }

  const status = application?.status || "none";
  const s = ST[status] || ST.pending;
  const canUpdate = status === "needs_correction" || status === "rejected";
  const note = status === "rejected" ? application?.rejection_reason : status === "needs_correction" ? application?.correction_note : null;

  return (
    <section>
      <div className="wrap">
        <Head eyebrow="My application" title={`Hi, ${firstName(user)}`} />
        {error ? (
          <Alert tone="err" style={{ marginBottom: 16 }}>
            {error}
          </Alert>
        ) : null}
        <div className={`glass status-hero ${s.cls}`}>
          <span className="status-ic">{ICON[s.ic]}</span>
          <div>
            <span className="badge">{s.badge}</span>
            <h2 style={{ fontSize: 26, marginTop: 10 }}>{s.title}</h2>
            <p className="muted" style={{ marginTop: 6 }}>
              {s.text}
            </p>
          </div>
          <div className="row">
            {status === "none" ? (
              <Link className="btn btn-hot" to="/driver/apply">
                Start Application {ICON.arrow}
              </Link>
            ) : null}
            {canUpdate ? (
              <Link className="btn btn-hot" to="/driver/apply?resubmit=1">
                {status === "needs_correction" ? "Update Application" : "Resubmit Application"} {ICON.arrow}
              </Link>
            ) : null}
            <button
              className="btn btn-glass"
              type="button"
              onClick={async () => {
                if (await load()) toast("Status refreshed", fmt(new Date()));
              }}
            >
              Refresh Status
            </button>
            <Link className="btn btn-ghost" to="/contact">
              Contact Support
            </Link>
          </div>
        </div>

        {note ? (
          <Alert tone={status === "needs_correction" ? "warn" : "err"} title={status === "needs_correction" ? "Note from the admin" : "Reason"} style={{ marginTop: 16 }}>
            {note}
          </Alert>
        ) : null}

        {application ? (
          <div className="grid g2" style={{ marginTop: 16 }}>
            <div className="card glass">
              <h3 style={{ marginTop: 0 }}>Details</h3>
              <div className="kv" style={{ marginTop: 10 }}>
                <span>Reference number</span>
                <span className="mono">#{application.id}</span>
                <span>Plate number</span>
                <span>{application.plate_number || "—"}</span>
                <span>Submitted</span>
                <span>{fmt(application.submitted_at)}</span>
                <span>Last update</span>
                <span>{fmt(application.reviewed_at || application.updated_at || application.submitted_at)}</span>
              </div>
              <h3>Verification</h3>
              <div className="kv" style={{ marginTop: 10 }}>
                <span>Driver&apos;s license</span>
                <span>{docCheck(application.license_image_url, application.license_check_status)}</span>
                <span>Franchise / permit</span>
                <span>{docCheck(application.business_permit_image_url, application.permit_check_status)}</span>
                <span>Face check</span>
                <span>{faceCheck(application.liveness_status)}</span>
              </div>
            </div>
            <div className="card glass">
              <h3 style={{ marginTop: 0 }}>Timeline</h3>
              {timeline.length ? (
                <ol className="timeline" style={{ marginTop: 14 }}>
                  {[...timeline]
                    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
                    .map((item) => (
                      <li key={item.id}>
                        <time>{fmt(item.created_at)}</time>
                        <b style={{ display: "block" }}>{TIMELINE_LABELS[item.status] || item.status}</b>
                        {item.note ? <p>{item.note}</p> : null}
                      </li>
                    ))}
                </ol>
              ) : (
                <p className="muted" style={{ marginTop: 10 }}>
                  No updates yet.
                </p>
              )}
            </div>
          </div>
        ) : null}
      </div>
    </section>
  );
}
