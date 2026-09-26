import { useCallback, useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";
import StatusPill from "../components/StatusPill";
import ConfirmDialog from "../components/ConfirmDialog";
import DocumentCheckBadge, { hasDocumentWarning } from "../components/DocumentCheckBadge";
import { formatDateTime, formatMoney, resolveDriverDocumentUrl as resolveAssetUrl } from "../utils/admin-formatters";

const STATUS_STYLE = {
  Online: ["rgba(62,207,120,0.2)", "var(--green)"],
  Offline: ["rgba(255,255,255,0.1)", "var(--muted)"],
  "License expired": ["rgba(245,166,35,0.2)", "var(--amber, #f5a623)"],
  Suspended: ["rgba(240,92,92,0.2)", "var(--red)"],
};

function StatusBadge({ status }) {
  const [background, color] = STATUS_STYLE[status] || STATUS_STYLE.Offline;
  return (
    <span style={{ display: "inline-block", padding: "4px 8px", borderRadius: 4, fontSize: 12, fontWeight: 500, background, color }}>
      {status}
    </span>
  );
}

export default function DriversPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [drivers, setDrivers] = useState([]);
  const [filter, setFilter] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [actionLoadingId, setActionLoadingId] = useState(null);
  const [selectedDriver, setSelectedDriver] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [expiring, setExpiring] = useState([]);
  const [dialog, setDialog] = useState(null); // { type: "suspend" | "reinstate" | "revoke", driver }

  const loadDrivers = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/drivers");
      const driversArray = Array.isArray(data?.data) ? data.data : [];
      const formattedDrivers = driversArray.map((driver) => {
        const statusLabel =
          driver.approval_status === "suspended"
            ? "Suspended"
            : driver.approval_status === "license_expired"
            ? "License expired"
            : driver.is_online
            ? "Online"
            : "Offline";
        const [color, textColor] = STATUS_STYLE[statusLabel];

        return {
          id: driver.id,
          name: driver.full_name || "Unknown",
          phone: driver.phone || "",
          plate: driver.tricycle_number || "N/A",
          rating: Number(driver.rating_avg || 0).toFixed(1),
          rating_count: Number(driver.rating_count || 0),
          rides: Number(driver.total_rides || 0),
          cancelled_rides: Number(driver.cancelled_rides || 0),
          last_ride_at: driver.last_ride_at,
          created_at: driver.created_at,
          status: statusLabel,
          color,
          textColor,
          initials: (driver.full_name || "")
            .split(" ")
            .map((segment) => segment[0] || "")
            .join("")
            .toUpperCase()
            .slice(0, 2),
          email: driver.email,
          approval_status: driver.approval_status,
          is_online: driver.is_online,
          user_status: driver.user_status,
          total_earnings: driver.total_earnings || 0,
          license_number: driver.license_number,
          license_expires_at: driver.license_expires_at,
          license_image_url: driver.license_image_url,
          business_permit_image_url: driver.business_permit_image_url,
          license_check_status: driver.license_check_status || null,
          permit_check_status: driver.permit_check_status || null,
        };
      });
      setDrivers(formattedDrivers);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load drivers.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadDrivers();
    // load license expirations (next 30 days)
    (async () => {
      try {
        const res = await apiClient.get(`/admin/drivers/licenses?days=30`);
        const list = Array.isArray(res?.data?.data) ? res.data.data : [];
        setExpiring(list);
      } catch (e) {
        // ignore
      }
    })();
  }, [loadDrivers]);

  const filteredDrivers = useMemo(() => {
    let result = drivers;

    if (filter !== "all") {
      result = result.filter((driver) =>
        filter === "flagged"
          ? hasDocumentWarning(driver.license_check_status, driver.permit_check_status)
          : driver.status === filter
      );
    }

    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (driver) =>
          driver.name.toLowerCase().includes(query) ||
          driver.phone.toLowerCase().includes(query) ||
          driver.plate.toLowerCase().includes(query) ||
          String(driver.email || "").toLowerCase().includes(query)
      );
    }

    return result;
  }, [drivers, filter, searchQuery]);

  // Takes a rider out of the approved list (e.g. wrong documents): driver
  // mode off, application back to "needs correction" so they can resubmit.
  async function handleRevoke(driver, note) {
    try {
      setError(null);
      await apiClient.post(`/admin/drivers/${driver.id}/revoke`, { note });
      closeModal();
      await loadDrivers();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to revoke approval.");
    }
  }

  async function handleSuspend(driverId) {
    setActionLoadingId(driverId);
    try {
      setError(null);
      await apiClient.post(`/admin/drivers/${driverId}/suspend`);
      closeModal();
      await loadDrivers();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to suspend driver.");
    } finally {
      setActionLoadingId(null);
    }
  }

  async function handleReinstate(driverId) {
    setActionLoadingId(driverId);
    try {
      setError(null);
      await apiClient.post(`/admin/drivers/${driverId}/reinstate`);
      closeModal();
      await loadDrivers();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to reinstate driver.");
    } finally {
      setActionLoadingId(null);
    }
  }

  function handleDialogConfirm(value) {
    if (!dialog) return;
    if (dialog.type === "suspend") handleSuspend(dialog.driver.id);
    if (dialog.type === "reinstate") handleReinstate(dialog.driver.id);
    if (dialog.type === "revoke") handleRevoke(dialog.driver, value);
    setDialog(null);
  }

  function openDriverModal(driver) {
    setSelectedDriver(driver);
    setShowModal(true);
  }

  function closeModal() {
    setShowModal(false);
    setSelectedDriver(null);
  }

  if (loading) {
    return <div className="state-block">Loading drivers...</div>;
  }

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Fleet management"
        title="Approved Drivers"
        description="Riders cleared to drive. Suspend, reinstate, or revoke approval when documents aren't right."
        actions={
          <button type="button" className="ghost-btn" onClick={loadDrivers}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}

      {expiring.length > 0 && (
        <div className="warning-banner">
          <strong>{expiring.length} driver(s)</strong> have licenses expiring within 30 days. Please notify them.
        </div>
      )}

      {expiring.length > 0 && (
        <section className="panel">
          <div className="panel-header section-header">
            <div>
              <p className="panel-label">License expiration</p>
              <h3>Drivers with upcoming license expiry</h3>
            </div>
            <button type="button" className="btn btn-ghost btn-sm" onClick={loadDrivers}>
              Refresh list
            </button>
          </div>
          <div className="table-wrap">
            <table className="compact-table">
              <thead>
                <tr>
                  <th>Driver</th>
                  <th>Phone</th>
                  <th>Expires</th>
                  <th>Document</th>
                </tr>
              </thead>
              <tbody>
                {expiring.map((driver) => (
                  <tr key={driver.id}>
                    <td>{driver.name}</td>
                    <td>{driver.phone || "-"}</td>
                    <td>{driver.license_expires_at ? new Date(driver.license_expires_at).toLocaleDateString() : "-"}</td>
                    <td>
                      {drivers.some((d) => d.id === driver.id) ? (
                        <button
                          type="button"
                          className="btn btn-ghost btn-sm"
                          onClick={() => openDriverModal(drivers.find((d) => d.id === driver.id))}
                        >
                          View profile
                        </button>
                      ) : (
                        "-"
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <section className="panel">
        <div className="panel-header section-header">
          <div>
            <p className="panel-label">Approved drivers</p>
            <h3>Driver List</h3>
          </div>
          <div className="section-metrics">
            <div className="mini-metric">
              <span>Total</span>
              <strong className="metric-compact">{drivers.length}</strong>
            </div>
            <div className="mini-metric">
              <span>Online now</span>
              <strong className="metric-compact">{drivers.filter((d) => d.status === "Online").length}</strong>
            </div>
          </div>
        </div>

        <div className="table-wrap">
          <div className="filter-bar" style={{ marginBottom: 16 }}>
            {[
              ["all", "All"],
              ["Online", "Online"],
              ["Offline", "Offline"],
              ["Suspended", "Suspended"],
              ["License expired", "License expired"],
              ["flagged", "⚠ Docs flagged"],
            ].map(([value, label]) => [value, label, value === "all" ? drivers.length : drivers.filter((d) =>
              value === "flagged" ? hasDocumentWarning(d.license_check_status, d.permit_check_status) : d.status === value
            ).length]).filter(([value, , count]) => value === "all" || count > 0).map(([value, label, count]) => (
              <button
                key={value}
                type="button"
                className={filter === value ? "filter-btn active" : "filter-btn"}
                onClick={() => setFilter(value)}
              >
                {label} ({count})
              </button>
            ))}
            <input
              type="text"
              className="search-box"
              placeholder="Search name, phone, email, plate..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ marginLeft: "auto", width: 250, maxWidth: "100%" }}
            />
          </div>

          <table>
            <thead>
              <tr>
                <th>Driver</th>
                <th>Phone</th>
                <th>Tricycle No.</th>
                <th>Rating</th>
                <th>Rides</th>
                <th>Earnings</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredDrivers.length === 0 ? (
                <tr>
                  <td colSpan="8" style={{ textAlign: "center", color: "var(--muted)" }}>
                    No drivers found.
                  </td>
                </tr>
              ) : (
                filteredDrivers.map((driver) => (
                  <tr key={driver.id}>
                    <td>
                      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                        <div
                          style={{
                            width: 32,
                            height: 32,
                            borderRadius: 50,
                            background: driver.color,
                            color: driver.textColor,
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            fontSize: 12,
                            fontWeight: 600,
                          }}
                        >
                          {driver.initials}
                        </div>
                        <div>
                          <div style={{ fontWeight: 500 }}>{driver.name}</div>
                          <div style={{ fontSize: 12, color: "var(--muted)" }}>{driver.email || "-"}</div>
                        </div>
                      </div>
                    </td>
                    <td style={{ color: "var(--muted)" }}>{driver.phone}</td>
                    <td style={{ fontFamily: "monospace", fontSize: 12 }}>
                      {driver.plate}
                      {hasDocumentWarning(driver.license_check_status, driver.permit_check_status) ? (
                        <span title="Documents flagged by the automatic check" style={{ color: "var(--red)", marginLeft: 6 }}>
                          ⚠ docs
                        </span>
                      ) : null}
                    </td>
                    <td className="rating" title={`${driver.rating_count} rating(s)`}>
                      {driver.rating_count ? `★ ${driver.rating}` : <span style={{ color: "var(--muted)" }}>No ratings</span>}
                    </td>
                    <td>
                      {driver.rides} completed
                      {driver.cancelled_rides ? <div style={{ fontSize: 12, color: "var(--muted)" }}>{driver.cancelled_rides} cancelled</div> : null}
                    </td>
                    <td>{formatMoney(driver.total_earnings)}</td>
                    <td><StatusBadge status={driver.status} /></td>
                    <td>
                      <div style={{ display: "flex", gap: 6 }}>
                        <button
                          className="btn btn-ghost btn-sm"
                          type="button"
                          onClick={() => openDriverModal(driver)}
                        >
                          View
                        </button>
                        {driver.status !== "Suspended" && (
                          <button
                            className="btn btn-danger btn-sm"
                            type="button"
                            disabled={actionLoadingId === driver.id}
                            onClick={() => setDialog({ type: "suspend", driver })}
                          >
                            {actionLoadingId === driver.id ? "..." : "Suspend"}
                          </button>
                        )}
                        {driver.status === "Suspended" && (
                          <button
                            className="btn btn-success btn-sm"
                            type="button"
                            disabled={actionLoadingId === driver.id}
                            onClick={() => setDialog({ type: "reinstate", driver })}
                          >
                            {actionLoadingId === driver.id ? "..." : "Reinstate"}
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      {showModal && selectedDriver && (
        <div className="modal-overlay open">
          <div className="modal" style={{ width: 720 }}>
            <div className="modal-header">
              <div className="modal-title">Driver Profile</div>
              <button className="modal-close" type="button" onClick={closeModal}>
                ×
              </button>
            </div>
            <div className="modal-body">
              <div style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 20 }}>
                <div
                  style={{
                    width: 56,
                    height: 56,
                    borderRadius: 50,
                    background: selectedDriver.color,
                    color: selectedDriver.textColor,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontSize: 18,
                    fontWeight: 600,
                  }}
                >
                  {selectedDriver.initials}
                </div>
                <div>
                  <div style={{ fontSize: 16, fontWeight: 600 }}>{selectedDriver.name}</div>
                  <div style={{ color: "var(--muted)", fontSize: 13, marginTop: 3 }}>{selectedDriver.email || "Driver account"}</div>
                  <div style={{ marginTop: 6 }}>
                    <StatusBadge status={selectedDriver.status} />
                  </div>
                </div>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, fontSize: 13 }}>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>PHONE</div>
                  {selectedDriver.phone}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>TRICYCLE PLATE</div>
                  {selectedDriver.plate}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>RATING</div>
                  {selectedDriver.rating_count ? `★ ${selectedDriver.rating} (${selectedDriver.rating_count})` : "No ratings yet"}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>COMPLETED RIDES</div>
                  {selectedDriver.rides}
                  {selectedDriver.cancelled_rides ? ` · ${selectedDriver.cancelled_rides} cancelled` : ""}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>EARNINGS</div>
                  {formatMoney(selectedDriver.total_earnings)}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>LAST RIDE</div>
                  {selectedDriver.last_ride_at ? formatDateTime(selectedDriver.last_ride_at) : "None yet"}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>LICENSE NUMBER</div>
                  {selectedDriver.license_number || "-"}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>LICENSE EXPIRY</div>
                  {selectedDriver.license_expires_at
                    ? new Date(selectedDriver.license_expires_at).toLocaleDateString()
                    : "-"}
                </div>
              </div>

              {hasDocumentWarning(selectedDriver.license_check_status, selectedDriver.permit_check_status) ? (
                <div className="warning-banner" style={{ marginTop: 16 }}>
                  The automatic document check flagged this driver's documents. Open them and confirm
                  they're a real driver's license and franchise / permit — suspend the driver if not.
                </div>
              ) : null}

              <div className="detail-list" style={{ marginTop: 16 }}>
                <div className="detail-row">
                  <span>License check</span>
                  <DocumentCheckBadge kind="license" status={selectedDriver.license_check_status} />
                </div>
                <div className="detail-row">
                  <span>Permit check</span>
                  <DocumentCheckBadge kind="permit" status={selectedDriver.permit_check_status} />
                </div>
              </div>

              <div className="doc-preview-grid" style={{ marginTop: 16 }}>
                {[
                  ["Driver's license", selectedDriver.license_image_url],
                  ["Franchise / permit", selectedDriver.business_permit_image_url],
                ].map(([label, url]) => (
                  <figure className="doc-preview-card" key={label}>
                    <figcaption><span>{label}</span></figcaption>
                    {resolveAssetUrl(url) ? (
                      <a href={resolveAssetUrl(url)} target="_blank" rel="noreferrer" title="Open full size">
                        <img src={resolveAssetUrl(url)} alt={label} loading="lazy" />
                      </a>
                    ) : (
                      <div className="doc-preview-missing">Not uploaded</div>
                    )}
                  </figure>
                ))}
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-danger" type="button" onClick={() => setDialog({ type: "revoke", driver: selectedDriver })}>
                Revoke approval
              </button>
              {selectedDriver.status === "Suspended" ? (
                <button className="btn btn-success" type="button" onClick={() => setDialog({ type: "reinstate", driver: selectedDriver })}>
                  Reinstate
                </button>
              ) : (
                <button className="btn btn-warning" type="button" onClick={() => setDialog({ type: "suspend", driver: selectedDriver })}>
                  Suspend
                </button>
              )}
              <button className="btn btn-ghost" type="button" onClick={closeModal}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={Boolean(dialog)}
        title={
          dialog?.type === "revoke"
            ? `Revoke ${dialog.driver.name}'s approval`
            : dialog?.type === "suspend"
            ? `Suspend ${dialog?.driver.name}`
            : `Reinstate ${dialog?.driver.name}`
        }
        message={
          dialog?.type === "revoke"
            ? "They lose driver mode and their application goes back to “needs correction” so they can resubmit documents."
            : dialog?.type === "suspend"
            ? "They'll be taken offline and can't accept rides until reinstated. Their passenger account keeps working."
            : "They'll be able to go online and accept rides again."
        }
        requireInput={dialog?.type === "revoke"}
        inputLabel="Reason shown to the driver"
        defaultValue="The uploaded documents are not a valid driver's license and franchise / permit."
        confirmLabel={dialog?.type === "revoke" ? "Revoke approval" : dialog?.type === "suspend" ? "Suspend" : "Reinstate"}
        danger={dialog?.type !== "reinstate"}
        onConfirm={handleDialogConfirm}
        onCancel={() => setDialog(null)}
      />
    </div>
  );
}
