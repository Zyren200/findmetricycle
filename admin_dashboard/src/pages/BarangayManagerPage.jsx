import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";

export default function BarangayManagerPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [barangays, setBarangays] = useState([]);
  const [updatingId, setUpdatingId] = useState(null);

  const loadBarangays = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/barangays");
      setBarangays(Array.isArray(data?.data) ? data.data : []);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load barangays.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadBarangays();
  }, [loadBarangays]);

  async function toggleBarangay(barangayId, currentStatus) {
    setUpdatingId(barangayId);
    try {
      await apiClient.put(`/admin/barangays/${barangayId}`, { is_enabled: !currentStatus });
      await loadBarangays();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to update barangay.");
    } finally {
      setUpdatingId(null);
    }
  }

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Service area"
        title="Barangay Coverage"
        description="Enable or disable barangays for booking availability. Disabled areas will not appear in the mobile app."
        actions={
          <button type="button" className="ghost-btn" onClick={loadBarangays}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {loading ? <div className="state-block">Loading barangay coverage...</div> : null}

      {!loading ? (
        <section className="panel">
          <div className="panel-header">
            <h3>Service Areas</h3>
            <span className="badge plain">
              {barangays.filter((b) => b.is_enabled).length} of {barangays.length} active
            </span>
          </div>
          {barangays.length === 0 ? (
            <div className="state-block">No barangays configured.</div>
          ) : (
            <div className="barangay-grid">
              {barangays.map((barangay) => (
                <div key={barangay.id} className={`barangay-card ${barangay.is_enabled ? "enabled" : "disabled"}`}>
                  <div className="card-header">
                    <h4>{barangay.name}</h4>
                    <span className={`status-pill status-${barangay.is_enabled ? "approved" : "rejected"}`}>
                      {barangay.is_enabled ? "Enabled" : "Disabled"}
                    </span>
                  </div>
                  <div className="card-footer">
                    <button
                      type="button"
                      className={barangay.is_enabled ? "btn btn-warning btn-sm" : "btn btn-success btn-sm"}
                      disabled={updatingId === barangay.id}
                      onClick={() => toggleBarangay(barangay.id, barangay.is_enabled)}
                    >
                      {updatingId === barangay.id
                        ? "..."
                        : barangay.is_enabled
                          ? "Disable"
                          : "Enable"}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      ) : null}

      <style>{`
        .barangay-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
          gap: 1rem;
          margin-top: 1rem;
        }

        .barangay-card {
          padding: 1rem;
          border: 1px solid var(--border-color);
          border-radius: 0.5rem;
          background: var(--surface-color);
          transition: all 0.2s ease;
        }

        .barangay-card.enabled {
          border-color: rgb(34, 197, 94);
          background: rgba(34, 197, 94, 0.05);
        }

        .barangay-card.disabled {
          border-color: rgb(239, 68, 68);
          background: rgba(239, 68, 68, 0.05);
          opacity: 0.7;
        }

        .barangay-card .card-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 1rem;
        }

        .barangay-card h4 {
          margin: 0;
          font-size: 0.95rem;
          font-weight: 600;
        }

        .barangay-card .card-footer {
          display: flex;
          gap: 0.5rem;
        }
      `}</style>
    </div>
  );
}
