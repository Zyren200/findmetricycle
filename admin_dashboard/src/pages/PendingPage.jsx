import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import DocumentCheckBadge, { hasDocumentWarning } from "../components/DocumentCheckBadge";
import PageHero from "../components/PageHero";
import PendingDriversTable, { APPLICATION_STATUS } from "../components/PendingDriversTable";
import ConfirmDialog from "../components/ConfirmDialog";
import StatusPill from "../components/StatusPill";
import { formatDateTime, resolveDriverDocumentUrl } from "../utils/admin-formatters";
import { useAuth } from "../context/AuthContext";
import { PERMISSIONS as P } from "../utils/admin-access";

const TABS = [
  ["pending", "Pending"],
  ["needs_correction", "Needs correction"],
  ["rejected", "Rejected"],
  ["approved", "Approved"],
  ["all", "All"],
];

const EMPTY_TEXT = {
  pending: "No applications waiting for review.",
  needs_correction: "No applications waiting for the applicant to fix documents.",
  rejected: "No rejected applications.",
  approved: "No approved applications.",
  all: "No driver applications yet.",
};

const LIVENESS = {
  passed: ["Passed", "success"],
  needs_review: ["Needs review — compare the selfie with the license photo", "warning"],
  failed: ["Failed", "danger"],
  pending: ["Not done", "neutral"],
};

const TIMELINE_LABELS = {
  pending: "Submitted",
  approved: "Approved",
  rejected: "Rejected",
  needs_correction: "Correction requested",
  archived: "Replaced by a newer application",
};

function DocumentPreview({ label, url, check }) {
  const src = url ? resolveDriverDocumentUrl(url) : null;
  return (
    <figure className="doc-preview-card">
      <figcaption>
        <span>{label}</span>
        {check ? <DocumentCheckBadge kind={check.kind} status={check.status} /> : null}
      </figcaption>
      {src ? (
        <a href={src} target="_blank" rel="noreferrer" title="Open full size">
          <img src={src} alt={label} loading="lazy" />
        </a>
      ) : (
        <div className="doc-preview-missing">Not uploaded</div>
      )}
    </figure>
  );
}

export default function PendingPage() {
  const { can } = useAuth();
  const canReview = can(P.DRIVER_APPLICATIONS_REVIEW);
  const [tab, setTab] = useState("pending");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [applications, setApplications] = useState([]);
  const [counts, setCounts] = useState({});
  const [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState(null);
  const [timeline, setTimeline] = useState([]);
  const [dialog, setDialog] = useState(null); // "reject" | "correction"

  const load = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/drivers/pending", { params: { status: tab } });
      setApplications(Array.isArray(data?.data) ? data.data : []);
      setCounts(data?.meta?.counts || {});
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load driver applications.");
    } finally {
      setLoading(false);
    }
  }, [tab]);

  useEffect(() => {
    setLoading(true);
    load();
  }, [load]);

  async function openReview(applicationId) {
    try {
      const [detailRes, timelineRes] = await Promise.all([
        apiClient.get(`/admin/drivers/${applicationId}`),
        apiClient.get(`/admin/drivers/${applicationId}/timeline`).catch(() => ({ data: { data: [] } })),
      ]);
      setSelected(detailRes.data?.data || null);
      setTimeline(Array.isArray(timelineRes.data?.data) ? timelineRes.data.data : []);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load the application.");
    }
  }

  async function runAction(request, failureMessage) {
    setBusy(true);
    try {
      await request();
      setSelected(null);
      await load();
    } catch (err) {
      setError(err?.response?.data?.message || failureMessage);
    } finally {
      setBusy(false);
    }
  }

  function approve() {
    const id = selected.id;
    return runAction(async () => {
      try {
        await apiClient.post(`/admin/drivers/${id}/approve`);
      } catch (err) {
        // The server refuses flagged documents unless the admin confirms
        // they checked the photos themselves.
        const details = err?.response?.data?.details;
        if (details?.code !== "DOCUMENT_CHECK_WARNING") throw err;
        const confirmed = window.confirm(
          "The automatic document check flagged this application:\n\n• " +
            details.warnings.join("\n• ") +
            "\n\nOnly approve if the photos really are a valid driver's license and franchise / permit.\n\nApprove anyway?"
        );
        if (!confirmed) return;
        await apiClient.post(`/admin/drivers/${id}/approve`, { acknowledgeDocumentWarnings: true });
      }
    }, "Approval failed.");
  }

  function handleDialogConfirm(value) {
    const id = selected?.id;
    const type = dialog;
    setDialog(null);
    if (!id) return;
    if (type === "reject") {
      runAction(() => apiClient.post(`/admin/drivers/${id}/reject`, { reason: value }), "Reject failed.");
    } else if (type === "correction") {
      runAction(
        () => apiClient.post(`/admin/drivers/${id}/request-correction`, { note: value }),
        "Request correction failed."
      );
    }
  }

  const check = selected?.documentCheck || {};
  const flagged = selected ? hasDocumentWarning(check.license, check.permit) : false;
  const [statusLabel, statusTone] = APPLICATION_STATUS[selected?.approvalStatus] || [selected?.approvalStatus, "neutral"];
  const [livenessLabel, livenessTone] = LIVENESS[selected?.livenessStatus] || LIVENESS.pending;

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Approvals"
        title="Driver Applications"
        description="Review applicants' documents before they can drive."
        actions={
          <button type="button" className="ghost-btn" onClick={load}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}

      <section className="panel">
        <div className="tab-row" role="tablist">
          {TABS.map(([key, label]) => (
            <button
              key={key}
              type="button"
              role="tab"
              aria-selected={tab === key}
              className={tab === key ? "tab-btn active" : "tab-btn"}
              onClick={() => setTab(key)}
            >
              {label}
              {key !== "all" && counts[key] ? <span className="tab-count">{counts[key]}</span> : null}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="state-block">Loading applications…</div>
        ) : (
          <PendingDriversTable applications={applications} onReview={openReview} emptyText={EMPTY_TEXT[tab]} />
        )}
      </section>

      {selected ? (
        <div className="modal-overlay open">
          <div className="modal" style={{ width: 720 }}>
            <div className="modal-header">
              <div className="modal-title">
                {selected.fullName} <StatusPill label={statusLabel} tone={statusTone} />
              </div>
              <button className="modal-close" type="button" onClick={() => setSelected(null)}>
                ×
              </button>
            </div>
            <div className="modal-body">
              {flagged ? (
                <div className="warning-banner" style={{ marginBottom: 12 }}>
                  The automatic check doesn't think these are the right documents
                  {check.details?.license?.otherDocument ? ` (the license photo reads as "${check.details.license.otherDocument}")` : ""}.
                  Look at the photos below before deciding.
                </div>
              ) : null}

              <div className="doc-preview-grid">
                <DocumentPreview
                  label="Driver's license"
                  url={selected.licenseImageUrl}
                  check={{ kind: "license", status: check.license }}
                />
                <DocumentPreview
                  label="Franchise / permit"
                  url={selected.businessPermitImageUrl}
                  check={{ kind: "permit", status: check.permit }}
                />
                <DocumentPreview label="Selfie" url={selected.selfieImageUrl} />
              </div>

              <div className="detail-list" style={{ marginTop: 16 }}>
                <div className="detail-row"><span>Email</span><strong>{selected.email || "-"}</strong></div>
                <div className="detail-row"><span>Mobile</span><strong>{selected.phone || "-"}</strong></div>
                <div className="detail-row"><span>Address</span><strong>{selected.address || "-"}</strong></div>
                <div className="detail-row"><span>Plate number</span><strong>{selected.tricycleNumber || "-"}</strong></div>
                <div className="detail-row"><span>Franchise number</span><strong>{selected.franchiseNumber || "-"}</strong></div>
                <div className="detail-row"><span>License type</span><strong>{selected.licenseType || "-"}</strong></div>
                <div className="detail-row"><span>License number</span><strong>{selected.licenseNumber || "-"}</strong></div>
                <div className="detail-row"><span>License expiry</span><strong>{selected.licenseExpiresAt ? formatDateTime(selected.licenseExpiresAt) : "-"}</strong></div>
                <div className="detail-row"><span>Liveness check</span><StatusPill label={livenessLabel} tone={livenessTone} /></div>
                <div className="detail-row">
                  <span>Emergency contact</span>
                  <strong>
                    {selected.emergencyContactName || "-"}
                    {selected.emergencyContactPhone ? ` · ${selected.emergencyContactPhone}` : ""}
                  </strong>
                </div>
                <div className="detail-row"><span>Submitted</span><strong>{formatDateTime(selected.createdAt)}</strong></div>
                {selected.rejectionReason ? (
                  <div className="detail-row"><span>Rejection reason</span><strong>{selected.rejectionReason}</strong></div>
                ) : null}
                {selected.correctionNote ? (
                  <div className="detail-row"><span>Correction asked</span><strong>{selected.correctionNote}</strong></div>
                ) : null}
                {selected.reviewedAt ? (
                  <div className="detail-row">
                    <span>Reviewed</span>
                    <strong>{formatDateTime(selected.reviewedAt)}{selected.reviewedByName ? ` · ${selected.reviewedByName}` : ""}</strong>
                  </div>
                ) : null}
              </div>

              {timeline.length > 0 ? (
                <div style={{ marginTop: 16 }}>
                  <h4 style={{ margin: "0 0 8px" }}>History</h4>
                  <div className="timeline">
                    {timeline.map((item) => (
                      <div className="tl-item" key={item.id}>
                        <div className="tl-dot" />
                        <div className="tl-content">
                          <div className="tl-title">{TIMELINE_LABELS[item.status] || item.status}</div>
                          <div className="tl-time">
                            {formatDateTime(item.created_at)}
                            {item.changed_by_name ? ` · by ${item.changed_by_name}` : ""}
                          </div>
                          {item.note ? <div>{item.note}</div> : null}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ) : null}
            </div>
            <div className="modal-footer">
              {canReview && selected.approvalStatus === "pending" ? (
                <>
                  <button className="btn btn-danger" type="button" disabled={busy} onClick={() => setDialog("reject")}>
                    Reject
                  </button>
                  <button className="btn btn-warning" type="button" disabled={busy} onClick={() => setDialog("correction")}>
                    Request correction
                  </button>
                  <button className="btn btn-success" type="button" disabled={busy} onClick={approve}>
                    {busy ? "Saving…" : "Approve"}
                  </button>
                </>
              ) : (
                <button className="btn btn-ghost" type="button" onClick={() => setSelected(null)}>
                  Close
                </button>
              )}
            </div>
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        open={Boolean(dialog)}
        title={dialog === "correction" ? "Request document correction" : "Reject driver application"}
        requireInput
        inputLabel={dialog === "correction" ? "What should the applicant fix or re-upload?" : "Reason for rejecting"}
        defaultValue={
          dialog === "correction"
            ? flagged
              ? "The uploaded photos are not a valid driver's license and franchise / permit. Please upload clear photos of the correct documents."
              : "Please upload a clearer photo of your documents."
            : "The documents submitted are not valid."
        }
        confirmLabel={dialog === "correction" ? "Send correction request" : "Reject application"}
        danger={dialog === "reject"}
        onConfirm={handleDialogConfirm}
        onCancel={() => setDialog(null)}
      />
    </div>
  );
}
