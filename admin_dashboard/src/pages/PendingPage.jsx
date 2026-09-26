import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";
import PendingDriversTable from "../components/PendingDriversTable";
import ConfirmDialog from "../components/ConfirmDialog";
import { formatDateTime, resolveDriverDocumentUrl } from "../utils/admin-formatters";

export default function PendingPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [drivers, setDrivers] = useState([]);
  const [actionLoadingId, setActionLoadingId] = useState(null);
  const [selectedDriver, setSelectedDriver] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [timeline, setTimeline] = useState([]);
  const [dialog, setDialog] = useState(null); // { type: "reject" | "correction", driverId }

  const loadPending = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/drivers/pending");
      setDrivers(Array.isArray(data?.data) ? data.data : []);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load pending drivers.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadPending();
  }, [loadPending]);

  async function handleApprove(driverId) {
    setActionLoadingId(driverId);
    try {
      await apiClient.post(`/admin/drivers/${driverId}/approve`);
      await loadPending();
    } catch (err) {
      setError(err?.response?.data?.message || "Approval failed.");
    } finally {
      setActionLoadingId(null);
    }
  }

  async function submitReject(driverId, reason) {
    setActionLoadingId(driverId);
    try {
      await apiClient.post(`/admin/drivers/${driverId}/reject`, { reason });
      setShowModal(false);
      await loadPending();
    } catch (err) {
      setError(err?.response?.data?.message || "Reject failed.");
    } finally {
      setActionLoadingId(null);
    }
  }

  async function submitRequestCorrection(driverId, note) {
    setActionLoadingId(driverId);
    try {
      await apiClient.post(`/admin/drivers/${driverId}/request-correction`, { note });
      setShowModal(false);
      await loadPending();
    } catch (err) {
      setError(err?.response?.data?.message || "Request correction failed.");
    } finally {
      setActionLoadingId(null);
    }
  }

  function handleDialogConfirm(value) {
    if (!dialog) return;
    if (dialog.type === "reject") submitReject(dialog.driverId, value);
    if (dialog.type === "correction") submitRequestCorrection(dialog.driverId, value);
    setDialog(null);
  }

  async function openReview(driverId) {
    try {
      const [detailRes, timelineRes] = await Promise.all([
        apiClient.get(`/admin/drivers/${driverId}`),
        apiClient.get(`/admin/drivers/${driverId}/timeline`).catch(() => ({ data: { data: [] } })),
      ]);
      setSelectedDriver(detailRes.data?.data || null);
      setTimeline(Array.isArray(timelineRes.data?.data) ? timelineRes.data.data : []);
      setShowModal(true);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load driver details.");
    }
  }

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Approvals"
        title="Pending Drivers"
        description="Review and approve driver applications before they go live."
        actions={
          <button type="button" className="ghost-btn" onClick={loadPending}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {loading ? <div className="state-block">Loading pending drivers...</div> : null}

      {!loading ? (
        <PendingDriversTable
          drivers={drivers}
          onApprove={handleApprove}
          onReject={(driverId) => setDialog({ type: "reject", driverId })}
          onView={openReview}
          actionLoadingId={actionLoadingId}
        />
      ) : null}

      {showModal && selectedDriver ? (
        <div className="modal-overlay open">
          <div className="modal">
            <div className="modal-header">
              <div className="modal-title">Driver Application Review</div>
              <button className="modal-close" type="button" onClick={() => setShowModal(false)}>
                ×
              </button>
            </div>
            <div className="modal-body">
              <div className="detail-list">
                <div className="detail-row"><span>Full Name</span><strong>{selectedDriver.fullName}</strong></div>
                <div className="detail-row"><span>Email</span><strong>{selectedDriver.email || "-"}</strong></div>
                <div className="detail-row"><span>Mobile Number</span><strong>{selectedDriver.phone || "-"}</strong></div>
                <div className="detail-row"><span>Plate Number</span><strong>{selectedDriver.tricycleNumber || "-"}</strong></div>
                <div className="detail-row"><span>Submitted</span><strong>{formatDateTime(selectedDriver.createdAt)}</strong></div>
                <div className="detail-row"><span>Status</span><strong>{selectedDriver.approvalStatus || "pending"}</strong></div>
              </div>

              <div style={{ marginTop: 16 }} className="detail-list">
                <div className="detail-row">
                  <span>Driver License</span>
                  <a href={resolveDriverDocumentUrl(selectedDriver.licenseImageUrl) || "#"} target="_blank" rel="noreferrer">View</a>
                </div>
                <div className="detail-row">
                  <span>Business Permit</span>
                  <a href={resolveDriverDocumentUrl(selectedDriver.businessPermitImageUrl) || "#"} target="_blank" rel="noreferrer">View</a>
                </div>
                <div className="detail-row">
                  <span>Selfie</span>
                  {selectedDriver.selfieImageUrl ? (
                    <a href={resolveDriverDocumentUrl(selectedDriver.selfieImageUrl)} target="_blank" rel="noreferrer">View</a>
                  ) : (
                    <strong>-</strong>
                  )}
                </div>
                <div className="detail-row">
                  <span>License Expiry</span>
                  <strong>{formatDateTime(selectedDriver.licenseExpiresAt)}</strong>
                </div>
                <div className="detail-row">
                  <span>OCR Status</span>
                  <strong>{selectedDriver.ocrStatus || "-"}</strong>
                </div>
                {selectedDriver.ocrFailureReason ? (
                  <div className="detail-row">
                    <span>OCR Note</span>
                    <strong>{selectedDriver.ocrFailureReason}</strong>
                  </div>
                ) : null}
                <div className="detail-row">
                  <span>Liveness Status</span>
                  <strong>{selectedDriver.livenessStatus || "-"}</strong>
                </div>
                <div className="detail-row">
                  <span>Rejection Reason</span>
                  <strong>{selectedDriver.rejectionReason || "-"}</strong>
                </div>
                <div className="detail-row">
                  <span>Correction Note</span>
                  <strong>{selectedDriver.correctionNote || "-"}</strong>
                </div>
                <div className="detail-row">
                  <span>Reviewed By</span>
                  <strong>{selectedDriver.reviewedByName || "-"}</strong>
                </div>
                <div className="detail-row">
                  <span>Reviewed At</span>
                  <strong>{selectedDriver.reviewedAt ? formatDateTime(selectedDriver.reviewedAt) : "-"}</strong>
                </div>
              </div>

              {timeline.length > 0 ? (
                <div style={{ marginTop: 16 }}>
                  <h4 style={{ margin: "0 0 8px" }}>Application Timeline</h4>
                  <div className="timeline">
                    {timeline.map((item) => (
                      <div className="tl-item" key={item.id}>
                        <div className="tl-dot" />
                        <div className="tl-content">
                          <div className="tl-title">{item.status}</div>
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
              <button className="btn btn-danger" type="button" onClick={() => setDialog({ type: "reject", driverId: selectedDriver.id })}>Reject</button>
              <button className="btn btn-warning" type="button" onClick={() => setDialog({ type: "correction", driverId: selectedDriver.id })}>Request Correction</button>
              <button className="btn btn-success" type="button" onClick={() => handleApprove(selectedDriver.id)}>Approve</button>
            </div>
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        open={Boolean(dialog)}
        title={dialog?.type === "correction" ? "Request Document Correction" : "Reject Driver Application"}
        requireInput
        inputLabel={dialog?.type === "correction" ? "What should the driver correct or re-upload?" : "Rejection reason"}
        defaultValue={dialog?.type === "correction" ? "License photo is blurry, please re-upload." : "Incomplete documents"}
        confirmLabel={dialog?.type === "correction" ? "Send Correction Request" : "Reject Application"}
        danger={dialog?.type === "reject"}
        onConfirm={handleDialogConfirm}
        onCancel={() => setDialog(null)}
      />
    </div>
  );
}
