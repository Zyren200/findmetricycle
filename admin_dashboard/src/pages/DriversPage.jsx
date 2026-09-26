import { useCallback, useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";
import StatusPill from "../components/StatusPill";
import ConfirmDialog from "../components/ConfirmDialog";
import DocumentCheckBadge, { hasDocumentWarning } from "../components/DocumentCheckBadge";
import { resolveDriverDocumentUrl as resolveAssetUrl } from "../utils/admin-formatters";

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
  const [dialog, setDialog] = useState(null); // { type: "suspend" | "reinstate", driverId }

  const loadDrivers = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/drivers");
      const driversArray = Array.isArray(data?.data) ? data.data : [];
      const formattedDrivers = driversArray.map((driver) => {
        const isSuspended = driver.user_status === "suspended" || driver.approval_status === "suspended";
        const statusLabel = isSuspended
          ? "Suspended"
          : driver.approval_status === "approved"
          ? driver.is_online
            ? "Active"
            : "Inactive"
          : driver.approval_status === "rejected"
          ? "Rejected"
          : "Pending";

        return {
          id: driver.id,
          name: driver.full_name || "Unknown",
          phone: driver.phone || "",
          plate: driver.tricycle_number || "N/A",
          rating: parseFloat(driver.rating_avg) || 0,
          rides: driver.total_rides || 0,
          status: statusLabel,
          color:
            statusLabel === "Active"
              ? "rgba(62,207,120,0.15)"
              : statusLabel === "Inactive"
              ? "rgba(255,255,255,0.06)"
              : "rgba(240,92,92,0.15)",
          textColor:
            statusLabel === "Active"
              ? "var(--green)"
              : statusLabel === "Inactive"
              ? "var(--muted)"
              : "var(--red)",
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
      result = result.filter((driver) => driver.status.toLowerCase() === filter.toLowerCase());
    }

    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (driver) =>
          driver.name.toLowerCase().includes(query) ||
          driver.phone.toLowerCase().includes(query) ||
          driver.plate.toLowerCase().includes(query)
      );
    }

    return result;
  }, [drivers, filter, searchQuery]);

  async function handleSuspend(driverId) {
    setActionLoadingId(driverId);
    try {
      await apiClient.post(`/admin/drivers/${driverId}/suspend`);
      await loadDrivers();
    } catch (err) {
      alert(err?.response?.data?.message || "Failed to suspend driver.");
    } finally {
      setActionLoadingId(null);
    }
  }

  async function handleReinstate(driverId) {
    setActionLoadingId(driverId);
    try {
      await apiClient.post(`/admin/drivers/${driverId}/reinstate`);
      await loadDrivers();
    } catch (err) {
      alert(err?.response?.data?.message || "Failed to reinstate driver.");
    } finally {
      setActionLoadingId(null);
    }
  }

  function handleDialogConfirm() {
    if (!dialog) return;
    if (dialog.type === "suspend") handleSuspend(dialog.driverId);
    if (dialog.type === "reinstate") handleReinstate(dialog.driverId);
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
        title="Drivers"
        description="Manage driver accounts, approvals, and suspensions."
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
                      <a href={`#/drivers/${driver.id}`} className="btn btn-ghost btn-sm">
                        View profile
                      </a>
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
            <p className="panel-label">Active drivers</p>
            <h3>Driver List</h3>
          </div>
          <div className="section-metrics">
            <div className="mini-metric">
              <span>Total</span>
              <strong className="metric-compact">{drivers.length}</strong>
            </div>
            <div className="mini-metric">
              <span>Active</span>
              <strong className="metric-compact">{drivers.filter((d) => d.status === "Active").length}</strong>
            </div>
          </div>
        </div>

        <div className="table-wrap">
          <div className="filter-bar" style={{ marginBottom: 16 }}>
            {[
              ["all", `All (${drivers.length})`],
              ["active", "Active"],
              ["inactive", "Inactive"],
              ["suspended", "Suspended"],
            ].map(([value, label]) => (
              <button
                key={value}
                type="button"
                className={filter === value ? "filter-btn active" : "filter-btn"}
                onClick={() => setFilter(value)}
              >
                {label}
              </button>
            ))}
            <input
              type="text"
              className="search-box"
              placeholder="Search by name, phone, plate..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ marginLeft: "auto", width: 250 }}
            />
          </div>

          <table>
            <thead>
              <tr>
                <th>Driver</th>
                <th>Phone</th>
                <th>Tricycle No.</th>
                <th>Rating</th>
                <th>Total Rides</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredDrivers.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: "center", color: "var(--muted)" }}>
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
                    <td className="rating">★ {driver.rating}</td>
                    <td>{driver.rides}</td>
                    <td>
                      <span
                        style={{
                          display: "inline-block",
                          padding: "4px 8px",
                          borderRadius: 4,
                          fontSize: 12,
                          fontWeight: 500,
                          background:
                            driver.status === "Active"
                              ? "rgba(62,207,120,0.2)"
                              : driver.status === "Inactive"
                              ? "rgba(255,255,255,0.1)"
                              : "rgba(240,92,92,0.2)",
                          color:
                            driver.status === "Active"
                              ? "var(--green)"
                              : driver.status === "Inactive"
                              ? "var(--muted)"
                              : "var(--red)",
                        }}
                      >
                        {driver.status}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: "flex", gap: 6 }}>
                        <button
                          className="btn btn-ghost btn-sm"
                          type="button"
                          onClick={() => openDriverModal(driver)}
                        >
                          View
                        </button>
                        {driver.status === "Active" && (
                          <button
                            className="btn btn-danger btn-sm"
                            type="button"
                            disabled={actionLoadingId === driver.id}
                            onClick={() => setDialog({ type: "suspend", driverId: driver.id })}
                          >
                            {actionLoadingId === driver.id ? "..." : "Suspend"}
                          </button>
                        )}
                        {driver.status === "Suspended" && (
                          <button
                            className="btn btn-success btn-sm"
                            type="button"
                            disabled={actionLoadingId === driver.id}
                            onClick={() => setDialog({ type: "reinstate", driverId: driver.id })}
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
          <div className="modal">
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
                  <div style={{ color: "var(--muted)", fontSize: 13, marginTop: 3 }}>Driver Account</div>
                  <div style={{ marginTop: 6 }}>
                    <span
                      style={{
                        display: "inline-block",
                        padding: "4px 8px",
                        borderRadius: 4,
                        fontSize: 12,
                        fontWeight: 500,
                        background:
                          selectedDriver.status === "Active"
                            ? "rgba(62,207,120,0.2)"
                            : selectedDriver.status === "Inactive"
                            ? "rgba(255,255,255,0.1)"
                            : "rgba(240,92,92,0.2)",
                        color:
                          selectedDriver.status === "Active"
                            ? "var(--green)"
                            : selectedDriver.status === "Inactive"
                            ? "var(--muted)"
                            : "var(--red)",
                      }}
                    >
                      {selectedDriver.status}
                    </span>
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
                  ★ {selectedDriver.rating}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>TOTAL RIDES</div>
                  {selectedDriver.rides}
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
                <div className="detail-row">
                  <span>Driver License</span>
                  {resolveAssetUrl(selectedDriver.license_image_url) ? (
                    <a href={resolveAssetUrl(selectedDriver.license_image_url)} target="_blank" rel="noreferrer">
                      View document
                    </a>
                  ) : (
                    <strong>Not uploaded</strong>
                  )}
                </div>
                <div className="detail-row">
                  <span>Business Permit</span>
                  {resolveAssetUrl(selectedDriver.business_permit_image_url) ? (
                    <a href={resolveAssetUrl(selectedDriver.business_permit_image_url)} target="_blank" rel="noreferrer">
                      View document
                    </a>
                  ) : (
                    <strong>Not uploaded</strong>
                  )}
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" type="button" onClick={closeModal}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={Boolean(dialog)}
        title={dialog?.type === "suspend" ? "Suspend Driver" : "Reinstate Driver"}
        message={
          dialog?.type === "suspend"
            ? "This driver will be taken offline and blocked from accepting rides until reinstated. Continue?"
            : "This driver will regain access to go online and accept rides. Continue?"
        }
        confirmLabel={dialog?.type === "suspend" ? "Suspend" : "Reinstate"}
        danger={dialog?.type === "suspend"}
        onConfirm={handleDialogConfirm}
        onCancel={() => setDialog(null)}
      />
    </div>
  );
}
