import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";

export default function EarningsPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [analytics, setAnalytics] = useState(null);

  const loadAnalytics = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/dashboard");
      setAnalytics(data?.data || null);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load earnings analytics.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAnalytics();
  }, [loadAnalytics]);

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Cash reporting"
        title="Earnings"
        description="Review cash-only earnings and ride throughput."
        actions={
          <button type="button" className="ghost-btn" onClick={loadAnalytics}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {loading ? <div className="state-block">Loading earnings analytics...</div> : null}

      {!loading ? (
        <section className="panel">
          <div className="panel-header">
            <h3>Cash performance</h3>
          </div>
          <div className="summary-grid">
            <article className="summary-card">
              <p className="panel-label">Today</p>
              <h3 className="metric-value">PHP {analytics?.dailyEarnings ?? 0}</h3>
            </article>
            <article className="summary-card">
              <p className="panel-label">Active Drivers</p>
              <h3 className="metric-value">{analytics?.activeDrivers ?? 0}</h3>
            </article>
            <article className="summary-card">
              <p className="panel-label">Total Rides</p>
              <h3 className="metric-value">{analytics?.totalRides ?? 0}</h3>
            </article>
          </div>
        </section>
      ) : null}
    </div>
  );
}
