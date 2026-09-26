import { useCallback, useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";

const STATUS_META = {
  pending: { label: "Pending", bg: "rgba(240,180,41,0.2)", color: "var(--yellow, #f0b429)" },
  searching: { label: "Pending", bg: "rgba(240,180,41,0.2)", color: "var(--yellow, #f0b429)" },
  accepted: { label: "Accepted", bg: "rgba(79,163,232,0.2)", color: "var(--blue)" },
  assigned: { label: "Accepted", bg: "rgba(79,163,232,0.2)", color: "var(--blue)" },
  arriving: { label: "Driver Arriving", bg: "rgba(155,110,232,0.2)", color: "#9b6ee8" },
  ongoing: { label: "In Progress", bg: "rgba(79,163,232,0.2)", color: "var(--blue)" },
  on_ride: { label: "In Progress", bg: "rgba(79,163,232,0.2)", color: "var(--blue)" },
  completed: { label: "Completed", bg: "rgba(62,207,120,0.2)", color: "var(--green)" },
  cancelled: { label: "Cancelled", bg: "rgba(240,92,92,0.2)", color: "var(--red)" },
  archived: { label: "Archived", bg: "rgba(255,255,255,0.08)", color: "var(--muted)" },
};

function statusMeta(rawStatus) {
  const key = String(rawStatus || "").toLowerCase();
  return STATUS_META[key] || { label: rawStatus || "Unknown", bg: "rgba(255,255,255,0.08)", color: "var(--muted)" };
}

function StatusBadge({ status }) {
  const meta = statusMeta(status);
  return (
    <span
      style={{
        display: "inline-block",
        padding: "4px 8px",
        borderRadius: 4,
        fontSize: 12,
        fontWeight: 500,
        background: meta.bg,
        color: meta.color,
      }}
    >
      {meta.label}
    </span>
  );
}

export default function RidesPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [rides, setRides] = useState([]);
  const [filter, setFilter] = useState("all");
  const [dateFilter, setDateFilter] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedRide, setSelectedRide] = useState(null);
  const [showModal, setShowModal] = useState(false);

  const loadRides = useCallback(async () => {
    try {
      setError(null);
      const limit = 100;
      const { data } = await apiClient.get(`/admin/rides/history?limit=${limit}`);
      const ridesArray = Array.isArray(data?.data) ? data.data : [];
      const formattedRides = ridesArray.map((ride) => ({
        id: ride.id,
        rideId: ride.ride_id || `#R-${ride.id}`,
        passenger: ride.passenger_name || "Unknown",
        driver: ride.driver_name || "Unknown",
        pickup: ride.pickup_location || "-",
        dropoff: ride.dropoff_location || "-",
        distance: ride.distance_km || 0,
        fare: ride.final_fare || ride.estimated_fare || 0,
        rating: ride.rating || null,
        status: ride.status || "Unknown",
        date: ride.completed_at ? new Date(ride.completed_at).toLocaleDateString() : "Unknown",
        time: ride.completed_at ? new Date(ride.completed_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "",
      }));
      setRides(formattedRides);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load rides.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadRides();
  }, [loadRides]);

  const filteredRides = useMemo(() => {
    let result = rides;

    if (filter !== "all") {
      result = result.filter((r) => statusMeta(r.status).label === filter);
    }

    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (r) =>
          r.rideId.toLowerCase().includes(query) ||
          r.passenger.toLowerCase().includes(query) ||
          r.driver.toLowerCase().includes(query)
      );
    }

    if (dateFilter) {
      result = result.filter((r) => r.date === dateFilter);
    }

    return result;
  }, [rides, filter, searchQuery, dateFilter]);

  function openRideModal(ride) {
    setSelectedRide(ride);
    setShowModal(true);
  }

  function closeModal() {
    setShowModal(false);
    setSelectedRide(null);
  }

  if (loading) {
    return <div className="state-block">Loading rides...</div>;
  }

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Ride tracking"
        title="Ride History"
        description="View completed, ongoing, and cancelled rides."
        actions={
          <button type="button" className="ghost-btn" onClick={loadRides}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}

      <section className="panel">
        <div className="panel-header section-header">
          <div>
            <p className="panel-label">Complete ride records</p>
            <h3>Ride History</h3>
          </div>
          <div className="section-metrics">
            <div className="mini-metric">
              <span>Total</span>
              <strong className="metric-compact">{rides.length}</strong>
            </div>
            <div className="mini-metric">
              <span>Completed</span>
              <strong className="metric-compact">{rides.filter((r) => statusMeta(r.status).label === "Completed").length}</strong>
            </div>
          </div>
        </div>

        <div className="table-wrap">
          <div className="filter-bar" style={{ marginBottom: 16, display: "flex", gap: 8, flexWrap: "wrap" }}>
            {[
              ["all", "All"],
              ["Pending", "Pending"],
              ["Accepted", "Accepted"],
              ["Driver Arriving", "Driver Arriving"],
              ["In Progress", "In Progress"],
              ["Completed", "Completed"],
              ["Cancelled", "Cancelled"],
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
              type="date"
              className="form-input"
              value={dateFilter}
              onChange={(e) => setDateFilter(e.target.value)}
              style={{ padding: "5px 10px", fontSize: 12, width: "auto" }}
            />
            <input
              type="text"
              className="search-box"
              placeholder="Search ride ID, passenger, driver..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ marginLeft: "auto", flex: 1, maxWidth: 300 }}
            />
          </div>

          <table>
            <thead>
              <tr>
                <th>Ride ID</th>
                <th>Passenger</th>
                <th>Driver</th>
                <th>Pickup</th>
                <th>Drop-off</th>
                <th>Distance</th>
                <th>Fare</th>
                <th>Rating</th>
                <th>Status</th>
                <th>Date & Time</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredRides.length === 0 ? (
                <tr>
                  <td colSpan="11" style={{ textAlign: "center", color: "var(--muted)" }}>
                    No rides found.
                  </td>
                </tr>
              ) : (
                filteredRides.map((ride) => (
                  <tr key={ride.id}>
                    <td style={{ fontFamily: "monospace", color: "var(--muted)", fontSize: 12 }}>{ride.rideId}</td>
                    <td>{ride.passenger}</td>
                    <td>{ride.driver}</td>
                    <td style={{ color: "var(--muted)", fontSize: 12 }}>{ride.pickup}</td>
                    <td style={{ color: "var(--muted)", fontSize: 12 }}>{ride.dropoff}</td>
                    <td>{ride.distance.toFixed(1)} km</td>
                    <td style={{ fontWeight: 500, color: "var(--accent)" }}>₱{ride.fare}</td>
                    <td className="rating">{ride.rating ? `★ ${ride.rating}` : "—"}</td>
                    <td>
                      <StatusBadge status={ride.status} />
                    </td>
                    <td style={{ color: "var(--muted)", fontSize: 12 }}>
                      {ride.date} {ride.time}
                    </td>
                    <td>
                      <button
                        className="btn btn-ghost btn-sm"
                        type="button"
                        onClick={() => openRideModal(ride)}
                      >
                        View
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      {showModal && selectedRide && (
        <div className="modal-overlay open">
          <div className="modal">
            <div className="modal-header">
              <div className="modal-title">Ride Details</div>
              <button className="modal-close" type="button" onClick={closeModal}>
                ×
              </button>
            </div>
            <div className="modal-body">
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, fontSize: 13, marginBottom: 16 }}>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>RIDE ID</div>
                  <span style={{ fontFamily: "monospace" }}>{selectedRide.rideId}</span>
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>STATUS</div>
                  <StatusBadge status={selectedRide.status} />
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>PASSENGER</div>
                  {selectedRide.passenger}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>DRIVER</div>
                  {selectedRide.driver}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8, gridColumn: "1 / -1" }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>PICKUP LOCATION</div>
                  {selectedRide.pickup}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8, gridColumn: "1 / -1" }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>DROP-OFF LOCATION</div>
                  {selectedRide.dropoff}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>DISTANCE</div>
                  {selectedRide.distance.toFixed(1)} km
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>FARE</div>
                  <span style={{ color: "var(--accent)", fontWeight: 500 }}>₱{selectedRide.fare}</span>
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>RATING</div>
                  {selectedRide.rating ? `★ ${selectedRide.rating}` : "No rating"}
                </div>
                <div style={{ background: "var(--bg3)", padding: 12, borderRadius: 8 }}>
                  <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 4 }}>DATE & TIME</div>
                  {selectedRide.date} {selectedRide.time}
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
    </div>
  );
}
