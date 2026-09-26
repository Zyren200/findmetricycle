import { useCallback, useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";
import ConfirmDialog from "../components/ConfirmDialog";

export default function PassengersPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [passengers, setPassengers] = useState([]);
  const [filter, setFilter] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedPassenger, setSelectedPassenger] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [actionLoadingId, setActionLoadingId] = useState(null);
  const [dialog, setDialog] = useState(null); // { type: "suspend" | "reinstate", passengerId }

  const loadPassengers = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/passengers");
      const passengersArray = Array.isArray(data?.data) ? data.data : [];
      const formattedPassengers = passengersArray.map((passenger) => ({
        id: passenger.id,
        name: passenger.full_name || "Unknown",
        phone: passenger.phone || "",
        email: passenger.email || "",
        rides: passenger.total_rides || 0,
        joined: passenger.created_at ? new Date(passenger.created_at).toLocaleDateString() : "Unknown",
        status: passenger.status === "suspended" ? "Suspended" : "Active",
        initials: (passenger.full_name || "")
          .split(" ")
          .map((segment) => segment[0] || "")
          .join("")
          .toUpperCase()
          .slice(0, 2),
      }));
      setPassengers(formattedPassengers);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load passengers.");
    } finally {
      setLoading(false);
    }
  }, []);

  async function handleSuspend(passengerId) {
    setActionLoadingId(passengerId);
    try {
      await apiClient.post(`/admin/passengers/${passengerId}/suspend`);
      setShowModal(false);
      await loadPassengers();
    } catch (err) {
      setError(err?.response?.data?.message || "Suspend failed.");
    } finally {
      setActionLoadingId(null);
    }
  }

  async function handleReinstate(passengerId) {
    setActionLoadingId(passengerId);
    try {
      await apiClient.post(`/admin/passengers/${passengerId}/reinstate`);
      setShowModal(false);
      await loadPassengers();
    } catch (err) {
      setError(err?.response?.data?.message || "Reactivate failed.");
    } finally {
      setActionLoadingId(null);
    }
  }

  function handleDialogConfirm() {
    if (!dialog) return;
    if (dialog.type === "suspend") handleSuspend(dialog.passengerId);
    if (dialog.type === "reinstate") handleReinstate(dialog.passengerId);
    setDialog(null);
  }

  useEffect(() => {
    loadPassengers();
  }, [loadPassengers]);

  const filteredPassengers = useMemo(() => {
    let result = passengers;

    if (filter !== "all") {
      result = result.filter((p) => p.status.toLowerCase() === filter.toLowerCase());
    }

    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (p) =>
          p.name.toLowerCase().includes(query) ||
          p.phone.toLowerCase().includes(query) ||
          p.email.toLowerCase().includes(query)
      );
    }

    return result;
  }, [passengers, filter, searchQuery]);

  function openPassengerModal(passenger) {
    setSelectedPassenger(passenger);
    setShowModal(true);
  }

  function closeModal() {
    setShowModal(false);
    setSelectedPassenger(null);
  }

  if (loading) {
    return <div className="state-block">Loading passengers...</div>;
  }

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="User management"
        title="Passengers"
        description="Monitor passenger accounts and activity."
        actions={
          <button type="button" className="ghost-btn" onClick={loadPassengers}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}

      <section className="panel">
        <div className="panel-header section-header">
          <div>
            <p className="panel-label">Registered users</p>
            <h3>Passenger List</h3>
          </div>
          <div className="section-metrics">
            <div className="mini-metric">
              <span>Total</span>
              <strong className="metric-compact">{passengers.length}</strong>
            </div>
            <div className="mini-metric">
              <span>Active</span>
              <strong className="metric-compact">{passengers.filter((p) => p.status === "Active").length}</strong>
            </div>
          </div>
        </div>

        <div className="table-wrap">
          <div className="filter-bar" style={{ marginBottom: 16 }}>
            {[
              ["all", "All"],
              ["active", "Active"],
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
              placeholder="Search by name, phone, email..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ marginLeft: "auto", width: 250 }}
            />
          </div>

          <table>
            <thead>
              <tr>
                <th>Passenger</th>
                <th>Phone</th>
                <th>Email</th>
                <th>Total Rides</th>
                <th>Joined</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredPassengers.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: "center", color: "var(--muted)" }}>
                    No passengers found.
                  </td>
                </tr>
              ) : (
                filteredPassengers.map((passenger) => (
                  <tr key={passenger.id}>
                    <td>
                      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                        <div
                          style={{
                            width: 32,
                            height: 32,
                            borderRadius: 50,
                            background: "rgba(255,255,255,0.06)",
                            color: "var(--muted)",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            fontSize: 12,
                            fontWeight: 600,
                          }}
                        >
                          {passenger.initials}
                        </div>
                        <div style={{ fontWeight: 500 }}>{passenger.name}</div>
                      </div>
                    </td>
                    <td style={{ color: "var(--muted)" }}>{passenger.phone}</td>
                    <td style={{ color: "var(--muted)", fontSize: 12 }}>{passenger.email || "-"}</td>
                    <td>{passenger.rides}</td>
                    <td style={{ color: "var(--muted)" }}>{passenger.joined}</td>
                    <td>
                      <span
                        style={{
                          display: "inline-block",
                          padding: "4px 8px",
                          borderRadius: 4,
                          fontSize: 12,
                          fontWeight: 500,
                          background:
                            passenger.status === "Active"
                              ? "rgba(62,207,120,0.2)"
                              : "rgba(240,92,92,0.2)",
                          color: passenger.status === "Active" ? "var(--green)" : "var(--red)",
                        }}
                      >
                        {passenger.status}
                      </span>
                    </td>
                    <td className="inline-actions">
                      <button
                        className="btn btn-ghost btn-sm"
                        type="button"
                        onClick={() => openPassengerModal(passenger)}
                      >
                        View
                      </button>
                      {passenger.status === "Active" ? (
                        <button
                          className="btn btn-danger btn-sm"
                          type="button"
                          disabled={actionLoadingId === passenger.id}
                          onClick={() => setDialog({ type: "suspend", passengerId: passenger.id })}
                        >
                          Suspend
                        </button>
                      ) : (
                        <button
                          className="btn btn-success btn-sm"
                          type="button"
                          disabled={actionLoadingId === passenger.id}
                          onClick={() => setDialog({ type: "reinstate", passengerId: passenger.id })}
                        >
                          Reactivate
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      {showModal && selectedPassenger && (
        <div className="modal-overlay open">
          <div className="modal">
            <div className="modal-header">
              <div className="modal-title">Passenger Profile</div>
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
                    background: "rgba(255,255,255,0.06)",
                    color: "var(--muted)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontSize: 18,
                    fontWeight: 600,
                  }}
                >
                  {selectedPassenger.initials}
                </div>
                <div>
                  <div style={{ fontSize: 16, fontWeight: 600 }}>{selectedPassenger.name}</div>
                  <div style={{ color: "var(--muted)", fontSize: 13, marginTop: 3 }}>Passenger Account</div>
                  <div style={{ marginTop: 6 }}>
                    <span
                      style={{
                        display: "inline-block",
                        padding: "4px 8px",
                        borderRadius: 4,
                        fontSize: 12,
                        fontWeight: 500,
                        background:
                          selectedPassenger.status === "Active"
                            ? "rgba(62,207,120,0.2)"
                            : "rgba(240,92,92,0.2)",
                        color: selectedPassenger.status === "Active" ? "var(--green)" : "var(--red)",
                      }}
                    >
                      {selectedPassenger.status}
                    </span>
                  </div>
                </div>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, fontSize: 13 }}>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>PHONE</div>
                  {selectedPassenger.phone}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>EMAIL</div>
                  {selectedPassenger.email || "-"}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>TOTAL RIDES</div>
                  {selectedPassenger.rides}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>JOINED</div>
                  {selectedPassenger.joined}
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" type="button" onClick={closeModal}>
                Close
              </button>
              {selectedPassenger.status === "Active" ? (
                <button
                  className="btn btn-danger"
                  type="button"
                  disabled={actionLoadingId === selectedPassenger.id}
                  onClick={() => setDialog({ type: "suspend", passengerId: selectedPassenger.id })}
                >
                  Suspend
                </button>
              ) : (
                <button
                  className="btn btn-success"
                  type="button"
                  disabled={actionLoadingId === selectedPassenger.id}
                  onClick={() => setDialog({ type: "reinstate", passengerId: selectedPassenger.id })}
                >
                  Reactivate
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={Boolean(dialog)}
        title={dialog?.type === "suspend" ? "Suspend Passenger" : "Reactivate Passenger"}
        message={
          dialog?.type === "suspend"
            ? "This passenger will not be able to book rides until reactivated. Continue?"
            : "This passenger will regain full access to the app. Continue?"
        }
        confirmLabel={dialog?.type === "suspend" ? "Suspend" : "Reactivate"}
        danger={dialog?.type === "suspend"}
        onConfirm={handleDialogConfirm}
        onCancel={() => setDialog(null)}
      />
    </div>
  );
}
