import { useCallback, useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import FareSettingsCard from "../components/FareSettingsCard";
import LiveMapCard from "../components/LiveMapCard";
import PageHero from "../components/PageHero";
import PendingDriversTable from "../components/PendingDriversTable";
import SummaryCards from "../components/SummaryCards";
import ConfirmDialog from "../components/ConfirmDialog";
import { useAuth } from "../context/AuthContext";
import { useSocket } from "../hooks/useSocket";

export default function OverviewPage() {
  const { token } = useAuth();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [savingFare, setSavingFare] = useState(false);
  const [actionLoadingId, setActionLoadingId] = useState(null);
  const [rejectDriverId, setRejectDriverId] = useState(null);

  const [pendingDrivers, setPendingDrivers] = useState([]);
  const [fareSettings, setFareSettings] = useState(null);
  const [summary, setSummary] = useState(null);
  const [onlineDrivers, setOnlineDrivers] = useState([]);
  const [activeRides, setActiveRides] = useState([]);

  const onDriverLocation = useCallback((payload) => {
    const driverId = Number(payload?.driverId || 0);
    if (!driverId) return;

    setOnlineDrivers((prev) =>
      prev.map((driver) =>
        Number(driver.id) === driverId
          ? {
              ...driver,
              current_lat: payload.lat,
              current_lng: payload.lng,
              last_location_update: payload.updatedAt,
            }
          : driver
      )
    );
  }, []);

  const loadDashboardData = useCallback(async () => {
    try {
      setError(null);
      const [pendingRes, fareRes, mapRes, summaryRes] = await Promise.all([
        apiClient.get("/admin/drivers/pending"),
        apiClient.get("/admin/fare"),
        apiClient.get("/admin/live-map"),
        apiClient.get("/admin/dashboard"),
      ]);

      setPendingDrivers(pendingRes.data?.data || []);
      setFareSettings(fareRes.data?.data || null);
      setOnlineDrivers(mapRes.data?.data?.onlineDrivers || []);
      setActiveRides(mapRes.data?.data?.activeRides || []);
      setSummary(summaryRes.data?.data || null);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load dashboard.");
    } finally {
      setLoading(false);
    }
  }, []);

  const onRideUpdate = useCallback(() => {
    loadDashboardData();
  }, [loadDashboardData]);

  useSocket({ token, onDriverLocation, onRideUpdate });

  useEffect(() => {
    loadDashboardData();
    const id = setInterval(loadDashboardData, 15000);
    return () => clearInterval(id);
  }, [loadDashboardData]);

  async function handleApprove(driverId) {
    setActionLoadingId(driverId);
    try {
      await apiClient.post(`/admin/drivers/${driverId}/approve`);
      await loadDashboardData();
    } catch (err) {
      setError(err?.response?.data?.message || "Approve failed.");
    } finally {
      setActionLoadingId(null);
    }
  }

  async function submitReject(driverId, reason) {
    setActionLoadingId(driverId);
    try {
      await apiClient.post(`/admin/drivers/${driverId}/reject`, { reason });
      await loadDashboardData();
    } catch (err) {
      setError(err?.response?.data?.message || "Reject failed.");
    } finally {
      setActionLoadingId(null);
    }
  }

  async function handleSaveFare(payload) {
    setSavingFare(true);
    try {
      const { data } = await apiClient.put("/admin/fare", payload);
      setFareSettings(data?.data || null);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to save fare settings.");
    } finally {
      setSavingFare(false);
    }
  }

  const rideHistory = useMemo(() => summary?.rideHistory || [], [summary]);
  const recentBookings = useMemo(() => summary?.recentBookings || [], [summary]);
  const recentDriverRegistrations = useMemo(() => summary?.recentDriverRegistrations || [], [summary]);

  if (loading) {
    return <div className="state-block">Loading overview...</div>;
  }

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Operational overview"
        title="Dashboard Overview"
        description="Monitor live rides, approve drivers, and keep fare controls in sync from one place."
        actions={
          <button type="button" className="ghost-btn" onClick={loadDashboardData}>
            Refresh Overview
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}

      <SummaryCards summary={summary} />

      <section className="layout-row">
        <div className="left-col">
          <LiveMapCard onlineDrivers={onlineDrivers} activeRides={activeRides} />
          <PendingDriversTable
            drivers={pendingDrivers}
            onApprove={handleApprove}
            onReject={(driverId) => setRejectDriverId(driverId)}
            actionLoadingId={actionLoadingId}
          />
        </div>
        <div className="right-col">
          <FareSettingsCard fare={fareSettings} onSave={handleSaveFare} saving={savingFare} />
          <section className="panel">
            <div className="panel-header">
              <h3>Online Drivers</h3>
            </div>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Tricycle</th>
                    <th>Lat</th>
                    <th>Lng</th>
                  </tr>
                </thead>
                <tbody>
                  {onlineDrivers.length === 0 ? (
                    <tr>
                      <td colSpan="4">No online drivers.</td>
                    </tr>
                  ) : (
                    onlineDrivers.map((driver) => (
                      <tr key={driver.id}>
                        <td>{driver.full_name}</td>
                        <td>{driver.tricycle_number}</td>
                        <td>{Number(driver.current_lat || 0).toFixed(5)}</td>
                        <td>{Number(driver.current_lng || 0).toFixed(5)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </div>
      </section>

      <section className="layout-row">
        <section className="panel">
          <div className="panel-header">
            <h3>Recent Bookings</h3>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Passenger</th>
                  <th>Driver</th>
                  <th>Status</th>
                  <th>Fare</th>
                </tr>
              </thead>
              <tbody>
                {recentBookings.length === 0 ? (
                  <tr>
                    <td colSpan="5">No recent bookings.</td>
                  </tr>
                ) : (
                  recentBookings.map((ride) => (
                    <tr key={ride.id}>
                      <td>{ride.id}</td>
                      <td>{ride.passenger_name || "-"}</td>
                      <td>{ride.driver_name || "-"}</td>
                      <td>{ride.status}</td>
                      <td>{ride.final_fare || ride.estimated_fare}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </section>

        <section className="panel">
          <div className="panel-header">
            <h3>Recent Driver Registrations</h3>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Status</th>
                  <th>Submitted</th>
                </tr>
              </thead>
              <tbody>
                {recentDriverRegistrations.length === 0 ? (
                  <tr>
                    <td colSpan="3">No recent registrations.</td>
                  </tr>
                ) : (
                  recentDriverRegistrations.map((app) => (
                    <tr key={app.id}>
                      <td>{app.full_name}</td>
                      <td>{app.status}</td>
                      <td>{app.submitted_at ? new Date(app.submitted_at).toLocaleString() : "-"}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </section>
      </section>

      <section className="panel">
        <div className="panel-header">
          <h3>Ride History</h3>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Status</th>
                <th>Passenger</th>
                <th>Driver</th>
                <th>Distance KM</th>
                <th>Fare</th>
              </tr>
            </thead>
            <tbody>
              {rideHistory.length === 0 ? (
                <tr>
                  <td colSpan="6">No rides yet.</td>
                </tr>
              ) : (
                rideHistory.map((ride) => (
                  <tr key={ride.id}>
                    <td>{ride.id}</td>
                    <td>{ride.status}</td>
                    <td>{ride.passenger_name || "-"}</td>
                    <td>{ride.driver_name || "-"}</td>
                    <td>{ride.distance_km}</td>
                    <td>{ride.final_fare || ride.estimated_fare}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <ConfirmDialog
        open={Boolean(rejectDriverId)}
        title="Reject Driver Application"
        requireInput
        inputLabel="Rejection reason"
        defaultValue="Incomplete documents"
        confirmLabel="Reject Application"
        danger
        onConfirm={(reason) => {
          submitReject(rejectDriverId, reason);
          setRejectDriverId(null);
        }}
        onCancel={() => setRejectDriverId(null)}
      />
    </div>
  );
}
