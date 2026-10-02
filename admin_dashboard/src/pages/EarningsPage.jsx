import { useCallback, useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";
import { formatDateTime, formatPlace } from "../utils/admin-formatters";
import { exportCsv } from "../utils/export";

const peso = (value) =>
  `₱${Number(value || 0).toLocaleString("en-PH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

/// Cash earnings: today / 7 / 30 days, a daily chart, the top-earning
/// drivers and the latest completed rides. All ride fares are paid in cash
/// directly to drivers — these are totals of completed bookings.
export default function EarningsPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [analytics, setAnalytics] = useState(null);
  const [activity, setActivity] = useState([]);
  const [drivers, setDrivers] = useState([]);
  const [rides, setRides] = useState([]);

  const loadAnalytics = useCallback(async () => {
    try {
      setError(null);
      const [dashRes, activityRes, driversRes, ridesRes] = await Promise.all([
        apiClient.get("/admin/dashboard"),
        apiClient.get("/admin/reports/ride-activity?days=30"),
        apiClient.get("/admin/drivers"),
        apiClient.get("/admin/rides/history?limit=200"),
      ]);
      setAnalytics(dashRes.data?.data || null);
      setActivity(Array.isArray(activityRes.data?.data) ? activityRes.data.data : []);
      setDrivers(Array.isArray(driversRes.data?.data) ? driversRes.data.data : []);
      setRides(Array.isArray(ridesRes.data?.data) ? ridesRes.data.data : []);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load earnings.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAnalytics();
  }, [loadAnalytics]);

  const totals = useMemo(() => {
    const sinceDays = (days) => {
      const cutoff = new Date();
      cutoff.setHours(0, 0, 0, 0);
      cutoff.setDate(cutoff.getDate() - (days - 1));
      return activity.filter((row) => new Date(row.date) >= cutoff);
    };
    const sum = (rows, key) => rows.reduce((acc, row) => acc + Number(row[key] || 0), 0);
    const week = sinceDays(7);
    return {
      weekEarnings: sum(week, "earnings"),
      weekRides: sum(week, "completed"),
      monthEarnings: sum(activity, "earnings"),
      monthRides: sum(activity, "completed"),
    };
  }, [activity]);

  const chart = useMemo(() => {
    // One bar per day for the last 14 days, including days with no rides.
    const byDate = new Map(activity.map((row) => [new Date(row.date).toDateString(), row]));
    const days = [];
    for (let i = 13; i >= 0; i -= 1) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const row = byDate.get(d.toDateString());
      days.push({
        label: d.toLocaleDateString("en-PH", { month: "short", day: "numeric" }),
        earnings: Number(row?.earnings || 0),
        rides: Number(row?.completed || 0),
      });
    }
    return days;
  }, [activity]);
  const maxEarning = Math.max(1, ...chart.map((d) => d.earnings));

  const topDrivers = useMemo(
    () =>
      [...drivers]
        .filter((d) => Number(d.total_earnings) > 0)
        .sort((a, b) => Number(b.total_earnings) - Number(a.total_earnings))
        .slice(0, 10),
    [drivers]
  );
  const completedRides = rides.filter((ride) => ride.status === "completed").slice(0, 25);

  function exportEarnings() {
    exportCsv("findmetricycle-earnings", [
      {
        title: "Daily Earnings (last 30 days)",
        columns: [
          { key: "date", label: "Date" },
          { key: "completed", label: "Completed rides" },
          { key: "earnings", label: "Earnings (PHP)" },
        ],
        rows: activity.map((row) => ({ ...row, date: new Date(row.date).toLocaleDateString("en-PH") })),
      },
      {
        title: "Earnings per Driver (all time)",
        columns: [
          { key: "full_name", label: "Driver" },
          { key: "tricycle_number", label: "Tricycle" },
          { key: "total_rides", label: "Completed rides" },
          { key: "total_earnings", label: "Earnings (PHP)" },
        ],
        rows: [...drivers].sort((a, b) => Number(b.total_earnings) - Number(a.total_earnings)),
      },
    ]);
  }

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Cash reporting"
        title="Earnings"
        description="Cash collected by drivers from completed rides."
        actions={
          <>
            <button type="button" className="ghost-btn" onClick={exportEarnings} disabled={loading}>
              Export CSV
            </button>
            <button type="button" className="ghost-btn" onClick={loadAnalytics}>
              Refresh
            </button>
          </>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {loading ? <div className="state-block">Loading earnings...</div> : null}

      {!loading ? (
        <>
          <section className="panel">
            <div className="panel-header">
              <h3>Cash performance</h3>
            </div>
            <div className="summary-grid">
              <article className="summary-card">
                <p className="panel-label">Today</p>
                <h3 className="metric-value">{peso(analytics?.dailyEarnings)}</h3>
                <small className="muted">{analytics?.completedRidesToday ?? 0} completed rides</small>
              </article>
              <article className="summary-card">
                <p className="panel-label">Last 7 days</p>
                <h3 className="metric-value">{peso(totals.weekEarnings)}</h3>
                <small className="muted">{totals.weekRides} completed rides</small>
              </article>
              <article className="summary-card">
                <p className="panel-label">Last 30 days</p>
                <h3 className="metric-value">{peso(totals.monthEarnings)}</h3>
                <small className="muted">{totals.monthRides} completed rides</small>
              </article>
              <article className="summary-card">
                <p className="panel-label">Average per ride (30 days)</p>
                <h3 className="metric-value">
                  {totals.monthRides ? peso(totals.monthEarnings / totals.monthRides) : "—"}
                </h3>
                <small className="muted">{analytics?.activeDrivers ?? 0} drivers online now</small>
              </article>
            </div>
          </section>

          <section className="panel">
            <div className="panel-header">
              <h3>Daily earnings (last 14 days)</h3>
            </div>
            <div style={{ display: "flex", alignItems: "flex-end", gap: 6, height: 220, padding: "12px 4px 0" }}>
              {chart.map((day) => (
                <div
                  key={day.label}
                  title={`${day.label}: ${peso(day.earnings)} · ${day.rides} rides`}
                  style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 6, minWidth: 0 }}
                >
                  <small className="muted" style={{ fontSize: 10, whiteSpace: "nowrap" }}>
                    {day.earnings ? `₱${Math.round(day.earnings)}` : ""}
                  </small>
                  <div
                    style={{
                      width: "100%",
                      maxWidth: 36,
                      height: `${Math.max(3, (day.earnings / maxEarning) * 160)}px`,
                      borderRadius: "6px 6px 0 0",
                      background: day.earnings ? "var(--green)" : "var(--border)",
                    }}
                  />
                  <small className="muted" style={{ fontSize: 10, whiteSpace: "nowrap" }}>{day.label}</small>
                </div>
              ))}
            </div>
          </section>

          <section className="panel">
            <div className="panel-header">
              <h3>Top earning drivers (all time)</h3>
            </div>
            <div className="table-wrap">
              <table className="compact-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Driver</th>
                    <th>Tricycle</th>
                    <th>Completed rides</th>
                    <th>Earnings</th>
                    <th>Last ride</th>
                  </tr>
                </thead>
                <tbody>
                  {topDrivers.length === 0 ? (
                    <tr>
                      <td colSpan={6}>No completed rides yet.</td>
                    </tr>
                  ) : (
                    topDrivers.map((driver, i) => (
                      <tr key={driver.id}>
                        <td>{i + 1}</td>
                        <td>{driver.full_name}</td>
                        <td>{driver.tricycle_number || "-"}</td>
                        <td>{driver.total_rides}</td>
                        <td><b>{peso(driver.total_earnings)}</b></td>
                        <td>{formatDateTime(driver.last_ride_at)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>

          <section className="panel">
            <div className="panel-header">
              <h3>Latest completed rides</h3>
            </div>
            <div className="table-wrap">
              <table className="compact-table">
                <thead>
                  <tr>
                    <th>Booking</th>
                    <th>Driver</th>
                    <th>Passenger</th>
                    <th>Route</th>
                    <th>Fare</th>
                    <th>Completed</th>
                  </tr>
                </thead>
                <tbody>
                  {completedRides.length === 0 ? (
                    <tr>
                      <td colSpan={6}>No completed rides yet.</td>
                    </tr>
                  ) : (
                    completedRides.map((ride) => (
                      <tr key={ride.id}>
                        <td>#{ride.id}</td>
                        <td>{ride.driverName || "-"}</td>
                        <td>{ride.passengerName || "-"}</td>
                        <td>
                          {formatPlace(ride.pickupAddress)} → {formatPlace(ride.dropoffAddress)}
                        </td>
                        <td>{peso(ride.fare)}</td>
                        <td>{formatDateTime(ride.completedAt)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </>
      ) : null}
    </div>
  );
}
