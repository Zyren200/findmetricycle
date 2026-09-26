import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";

export default function AnalyticsPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [analytics, setAnalytics] = useState(null);
  const [rideActivity, setRideActivity] = useState([]);

  const loadAnalytics = useCallback(async () => {
    try {
      setError(null);
      const [dashRes, activityRes] = await Promise.all([
        apiClient.get("/admin/dashboard"),
        apiClient.get("/admin/reports/ride-activity?days=7"),
      ]);

      setAnalytics(dashRes.data?.data || null);
      const activityArray = Array.isArray(activityRes.data?.data) ? activityRes.data.data : [];
      setRideActivity(activityArray);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load analytics.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAnalytics();
  }, [loadAnalytics]);

  const dailyRides = rideActivity.map((row) => ({
    label: new Date(row.date).toLocaleDateString("en-US", { weekday: "short" }),
    count: row.total,
  }));

  const maxDaily = Math.max(1, ...dailyRides.map((d) => d.count));

  // Calculate metrics
  const totalRides = analytics?.totalRides || 0;
  const completedToday = analytics?.completedRidesToday || 0;
  const avgRideValue = totalRides > 0 ? Math.round(analytics?.dailyEarnings || 0 / (completedToday || 1)) : 0;

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Reports & insights"
        title="Analytics"
        description="Review municipal rides, bookings, drivers, and operational trends."
        actions={
          <button type="button" className="ghost-btn" onClick={loadAnalytics}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {loading ? <div className="state-block">Loading analytics...</div> : null}

      {!loading && analytics ? (
        <>
          <section className="panel">
            <div className="panel-header">
              <h3>Key Metrics</h3>
            </div>
            <div className="metrics-grid">
              <div className="metric-card">
                <p className="metric-label">Total Rides</p>
                <h3 className="metric-value">{totalRides}</h3>
                <p className="metric-delta">Live total</p>
              </div>
              <div className="metric-card">
                <p className="metric-label">Today's Rides</p>
                <h3 className="metric-value">{completedToday}</h3>
                <p className="metric-delta accent">Active service</p>
              </div>
              <div className="metric-card">
                <p className="metric-label">Avg Ride Value</p>
                <h3 className="metric-value">PHP {avgRideValue}</h3>
                <p className="metric-delta">Cash only</p>
              </div>
              <div className="metric-card">
                <p className="metric-label">Active Drivers</p>
                <h3 className="metric-value">{analytics?.activeDrivers || 0}</h3>
                <p className="metric-delta">Online now</p>
              </div>
            </div>
          </section>

          <section className="panel">
            <div className="panel-header">
              <h3>7-Day Ride Activity</h3>
            </div>
            <div className="chart-container">
              <div className="chart-bars-lg">
                {dailyRides.map((day, idx) => (
                  <div key={idx} className="bar-column">
                    <div
                      className="bar"
                      style={{
                        height: `${(day.count / maxDaily) * 200}px`,
                        animation: `slideUp 0.5s ease-out ${idx * 0.05}s both`,
                      }}
                    />
                    <div className="bar-label">{day.label}</div>
                    <div className="bar-value">{day.count}</div>
                  </div>
                ))}
              </div>
            </div>
          </section>

          <section className="panel">
            <div className="panel-header">
              <h3>Operational Summary</h3>
            </div>
            <div className="summary-items">
              <div className="summary-item">
                <div className="summary-icon">👥</div>
                <div className="summary-content">
                  <p className="summary-label">Total Passengers</p>
                  <p className="summary-value">{analytics?.totalPassengers || 0}</p>
                </div>
              </div>
              <div className="summary-item">
                <div className="summary-icon">🚨</div>
                <div className="summary-content">
                  <p className="summary-label">SOS Alerts</p>
                  <p className="summary-value">{analytics?.sosAlerts || 0}</p>
                </div>
              </div>
              <div className="summary-item">
                <div className="summary-icon">⏳</div>
                <div className="summary-content">
                  <p className="summary-label">Pending Applications</p>
                  <p className="summary-value">{analytics?.pendingApplications || 0}</p>
                </div>
              </div>
              <div className="summary-item">
                <div className="summary-icon">💰</div>
                <div className="summary-content">
                  <p className="summary-label">Daily Earnings</p>
                  <p className="summary-value">PHP {analytics?.dailyEarnings || 0}</p>
                </div>
              </div>
            </div>
          </section>

          <section className="panel">
            <div className="panel-header">
              <h3>Export Data</h3>
            </div>
            <div className="export-options">
              <button type="button" className="export-btn" title="Export as PDF">
                <span className="export-icon">📄</span>
                <span>PDF Report</span>
              </button>
              <button type="button" className="export-btn" title="Export as Excel">
                <span className="export-icon">📊</span>
                <span>Excel Spreadsheet</span>
              </button>
              <button type="button" className="export-btn" title="Export as CSV">
                <span className="export-icon">📋</span>
                <span>CSV File</span>
              </button>
            </div>
            <p className="muted text-sm" style={{ marginTop: "1rem" }}>
              💡 Export formats ready for import into business intelligence tools.
            </p>
          </section>
        </>
      ) : null}

      <style>{`
        @keyframes slideUp {
          from {
            height: 0;
            opacity: 0;
          }
          to {
            height: var(--final-height);
            opacity: 1;
          }
        }

        .metrics-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 1rem;
          margin-top: 1rem;
        }

        .metric-card {
          padding: 1.5rem;
          border: 1px solid var(--border-color);
          border-radius: 0.5rem;
          background: linear-gradient(135deg, rgba(59, 130, 246, 0.05) 0%, rgba(139, 92, 246, 0.05) 100%);
        }

        .metric-label {
          font-size: 0.75rem;
          text-transform: uppercase;
          letter-spacing: 0.05em;
          color: var(--text-muted);
          margin: 0;
        }

        .metric-value {
          margin: 0.5rem 0;
          font-size: 2rem;
          font-weight: 700;
          color: var(--text-primary);
        }

        .metric-delta {
          margin: 0;
          font-size: 0.875rem;
          color: var(--text-muted);
        }

        .metric-delta.accent {
          color: rgb(34, 197, 94);
        }

        .chart-container {
          margin-top: 1rem;
          padding: 1rem 0;
        }

        .chart-bars-lg {
          display: flex;
          justify-content: space-around;
          align-items: flex-end;
          gap: 0.5rem;
          height: 300px;
          padding: 1rem;
          background: rgba(59, 130, 246, 0.02);
          border-radius: 0.375rem;
        }

        .bar-column {
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 0.5rem;
          flex: 1;
          max-width: 60px;
        }

        .bar {
          width: 100%;
          background: linear-gradient(to top, rgb(59, 130, 246), rgb(99, 102, 241));
          border-radius: 0.25rem 0.25rem 0 0;
          box-shadow: 0 -2px 8px rgba(59, 130, 246, 0.2);
          min-height: 2px;
        }

        .bar-label {
          font-size: 0.75rem;
          font-weight: 600;
          color: var(--text-muted);
        }

        .bar-value {
          font-size: 0.85rem;
          font-weight: 700;
          color: var(--text-primary);
        }

        .summary-items {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 1rem;
          margin-top: 1rem;
        }

        .summary-item {
          display: flex;
          gap: 1rem;
          padding: 1rem;
          border: 1px solid var(--border-color);
          border-radius: 0.375rem;
          background: rgba(139, 92, 246, 0.02);
        }

        .summary-icon {
          font-size: 2rem;
        }

        .summary-content {
          flex: 1;
        }

        .summary-label {
          margin: 0;
          font-size: 0.875rem;
          color: var(--text-muted);
        }

        .summary-value {
          margin: 0.5rem 0 0 0;
          font-size: 1.5rem;
          font-weight: 700;
          color: var(--text-primary);
        }

        .export-options {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
          gap: 1rem;
          margin-top: 1rem;
        }

        .export-btn {
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 0.5rem;
          padding: 1rem;
          border: 1px solid var(--border-color);
          border-radius: 0.375rem;
          background: var(--surface-color);
          cursor: pointer;
          transition: all 0.2s ease;
          font-size: 0.875rem;
          font-weight: 600;
        }

        .export-btn:hover {
          border-color: rgb(59, 130, 246);
          background: rgba(59, 130, 246, 0.05);
          transform: translateY(-2px);
        }

        .export-icon {
          font-size: 1.75rem;
        }

        .text-sm {
          font-size: 0.875rem;
        }
      `}</style>
    </div>
  );
}
