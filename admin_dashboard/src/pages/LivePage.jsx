import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import LiveMapCard from "../components/LiveMapCard";
import PageHero from "../components/PageHero";
import SummaryCards from "../components/SummaryCards";

export default function LivePage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [onlineDrivers, setOnlineDrivers] = useState([]);
  const [activeRides, setActiveRides] = useState([]);
  const [summary, setSummary] = useState(null);

  const loadData = useCallback(async () => {
    try {
      setError(null);
      const [mapRes, dashboardRes] = await Promise.all([
        apiClient.get("/admin/live-map"),
        apiClient.get("/admin/dashboard"),
      ]);
      setOnlineDrivers(mapRes.data?.data?.onlineDrivers || []);
      setActiveRides(mapRes.data?.data?.activeRides || []);
      setSummary(dashboardRes.data?.data || null);
    } catch (err) {
      setError(err?.response?.data?.message || "Unable to load live map data.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
    const intervalId = setInterval(loadData, 15000);
    return () => clearInterval(intervalId);
  }, [loadData]);

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Live operations"
        title="Live Monitoring"
        description="Track drivers and active rides in real time from the map feed."
        actions={
          <button type="button" className="ghost-btn" onClick={loadData}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {loading ? <div className="state-block">Loading live monitoring...</div> : null}

      {!loading ? (
        <>
          {summary ? <SummaryCards summary={summary} /> : null}
          <section className="panel">
            <div className="panel-header">
              <h3>Live Map</h3>
            </div>
            <LiveMapCard onlineDrivers={onlineDrivers} activeRides={activeRides} />
          </section>
        </>
      ) : null}
    </div>
  );
}
