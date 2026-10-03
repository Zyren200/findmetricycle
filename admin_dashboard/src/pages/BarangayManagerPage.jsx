import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";
import ServiceAreaMap from "../components/ServiceAreaMap";
import { isInsideServiceArea, useServiceArea } from "../utils/service-area";

const OUTSIDE_PIN_MESSAGE = "That spot is outside Guiuan's boundary — a barangay pin must be inside Guiuan.";

// "11.0736, 125.7276" → { lat, lng }, or null.
function parsePin(text) {
  const match = String(text).trim().match(/^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/);
  if (!match) return null;
  return { lat: Number(match[1]), lng: Number(match[2]) };
}

function formatPin(barangay) {
  if (barangay.lat == null || barangay.lng == null) return "";
  return `${Number(barangay.lat).toFixed(4)}, ${Number(barangay.lng).toFixed(4)}`;
}

function errorMessage(err, fallback) {
  return err?.response?.data?.details?.issues?.[0]?.message || err?.response?.data?.message || fallback;
}

export default function BarangayManagerPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [barangays, setBarangays] = useState([]);
  const [updatingId, setUpdatingId] = useState(null);
  const [search, setSearch] = useState("");
  const [editingId, setEditingId] = useState(null);
  const [pinDraft, setPinDraft] = useState("");
  const area = useServiceArea();
  const mapPanelRef = useRef(null);

  const loadBarangays = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/barangays");
      setBarangays(Array.isArray(data?.data) ? data.data : []);
    } catch (err) {
      setError(errorMessage(err, "Failed to load barangays."));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadBarangays();
  }, [loadBarangays]);

  const visible = useMemo(() => {
    const term = search.trim().toLowerCase();
    return term ? barangays.filter((b) => b.name.toLowerCase().includes(term)) : barangays;
  }, [barangays, search]);

  async function saveBarangay(barangayId, changes) {
    setUpdatingId(barangayId);
    setError(null);
    try {
      const { data } = await apiClient.put(`/admin/barangays/${barangayId}`, changes);
      setBarangays((prev) => prev.map((b) => (b.id === barangayId ? { ...b, ...data?.data } : b)));
      return true;
    } catch (err) {
      setError(errorMessage(err, "Failed to update barangay."));
      return false;
    } finally {
      setUpdatingId(null);
    }
  }

  function startEditingPin(barangay) {
    setEditingId(barangay.id);
    setPinDraft(formatPin(barangay));
    // The map is above the list: bring it into view to place the pin.
    mapPanelRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  async function savePin(barangayId) {
    const pin = parsePin(pinDraft);
    if (!pin) {
      setError("Enter the pin as latitude, longitude — e.g. 11.0311, 125.7235.");
      return;
    }
    // The server checks this too; this just says so straight away.
    if (isInsideServiceArea(area, pin.lat, pin.lng, { bufferMeters: 0 }) === false) {
      setError(OUTSIDE_PIN_MESSAGE);
      return;
    }
    if (await saveBarangay(barangayId, pin)) setEditingId(null);
  }

  // While a pin is being moved, a click on the map places it — never
  // outside Guiuan.
  function placePinFromMap(lat, lng) {
    if (editingId == null) return;
    if (isInsideServiceArea(area, lat, lng, { bufferMeters: 0 }) === false) {
      setError(OUTSIDE_PIN_MESSAGE);
      return;
    }
    setError(null);
    setPinDraft(`${lat.toFixed(5)}, ${lng.toFixed(5)}`);
  }

  const editing = barangays.find((b) => b.id === editingId) || null;
  const draftPin = editing ? parsePin(pinDraft) : null;

  const mapPoints = useMemo(
    () =>
      barangays
        .filter((b) => b.lat != null && b.lng != null)
        .map((b) => {
          const isEditing = b.id === editingId;
          const point = isEditing && draftPin ? draftPin : { lat: b.lat, lng: b.lng };
          return {
            id: b.id,
            lat: point.lat,
            lng: point.lng,
            label: isEditing ? b.name : "",
            color: isEditing ? "#D97706" : b.is_enabled ? "#16A34A" : "#DC2626",
            highlight: isEditing,
          };
        }),
    [barangays, editingId, draftPin?.lat, draftPin?.lng]
  );

  const enabledCount = barangays.filter((b) => b.is_enabled).length;

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Service area"
        title="Barangay Coverage"
        description="Disable a barangay to stop new bookings with a pickup or drop-off there. Each location counts as the barangay whose pin is nearest, so keep pins in the barangay's centre."
        actions={
          <button type="button" className="ghost-btn" onClick={loadBarangays}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {loading ? <div className="state-block">Loading barangay coverage...</div> : null}

      {!loading ? (
        <section className="panel" ref={mapPanelRef}>
          <div className="panel-header">
            <h3>Coverage map</h3>
            <span className="muted small-text">
              <span style={{ color: "#16A34A" }}>●</span> enabled &nbsp;
              <span style={{ color: "#DC2626" }}>●</span> disabled &nbsp;
              <span style={{ color: "#0E8C46" }}>- -</span> Guiuan&apos;s boundary
            </span>
          </div>
          <p className="muted small-text" style={{ margin: "0 0 10px" }}>
            {editing
              ? `Click the map to place the pin for ${editing.name}, then press Save pin.`
              : "Press Move pin on a barangay below, then click the map to place its pin. Pins must be inside Guiuan's boundary."}
          </p>
          <ServiceAreaMap
            points={mapPoints}
            focus={editing && editing.lat != null ? { lat: editing.lat, lng: editing.lng } : null}
            onMapClick={editing ? placePinFromMap : null}
            height={340}
            ariaLabel="Barangay coverage map"
          />
        </section>
      ) : null}

      {!loading ? (
        <section className="panel">
          <div className="panel-header">
            <h3>Service Areas</h3>
            <span className="badge plain">
              {enabledCount} of {barangays.length} active
            </span>
          </div>
          <input
            type="search"
            className="barangay-search"
            placeholder="Search barangay"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {barangays.length === 0 ? (
            <div className="state-block">
              No barangays yet. Restart the backend after running <code>npm run migrate</code> to load Guiuan&apos;s 60 barangays.
            </div>
          ) : visible.length === 0 ? (
            <div className="state-block">No barangay matches &ldquo;{search}&rdquo;.</div>
          ) : (
            <div className="barangay-grid">
              {visible.map((barangay) => {
                const busy = updatingId === barangay.id;
                const pin = formatPin(barangay);
                return (
                  <div key={barangay.id} className={`barangay-card ${barangay.is_enabled ? "enabled" : "disabled"}`}>
                    <div className="card-header">
                      <h4>{barangay.name}</h4>
                      <span className={`status-pill status-${barangay.is_enabled ? "approved" : "rejected"}`}>
                        {barangay.is_enabled ? "Enabled" : "Disabled"}
                      </span>
                    </div>

                    {editingId === barangay.id ? (
                      <div className="pin-editor">
                        <input
                          type="text"
                          value={pinDraft}
                          onChange={(e) => setPinDraft(e.target.value)}
                          placeholder="11.0311, 125.7235"
                          aria-label={`Pin for ${barangay.name}`}
                          autoFocus
                        />
                        <div className="pin-actions">
                          <button type="button" className="btn btn-primary btn-sm" disabled={busy} onClick={() => savePin(barangay.id)}>
                            {busy ? "..." : "Save pin"}
                          </button>
                          <button type="button" className="btn btn-secondary btn-sm" onClick={() => setEditingId(null)}>
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <p className="pin-line">
                        {pin ? (
                          <a
                            href={`https://www.openstreetmap.org/?mlat=${barangay.lat}&mlon=${barangay.lng}#map=16/${barangay.lat}/${barangay.lng}`}
                            target="_blank"
                            rel="noreferrer"
                          >
                            📍 {pin}
                          </a>
                        ) : (
                          <span className="pin-missing">No pin — this barangay can&apos;t be matched</span>
                        )}
                      </p>
                    )}

                    <div className="card-footer">
                      <button
                        type="button"
                        className={barangay.is_enabled ? "btn btn-warning btn-sm" : "btn btn-success btn-sm"}
                        disabled={busy}
                        onClick={() => saveBarangay(barangay.id, { is_enabled: !barangay.is_enabled })}
                      >
                        {busy ? "..." : barangay.is_enabled ? "Disable" : "Enable"}
                      </button>
                      {editingId !== barangay.id ? (
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => startEditingPin(barangay)}>
                          {pin ? "Move pin" : "Set pin"}
                        </button>
                      ) : null}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>
      ) : null}

      <style>{`
        .barangay-search {
          width: 100%;
          max-width: 320px;
          margin-top: 1rem;
          padding: 0.6rem 0.75rem;
          border: 1px solid var(--border-color);
          border-radius: 0.375rem;
          background: var(--input-bg);
          color: var(--text-primary);
        }

        .barangay-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
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
        }

        .barangay-card .card-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 0.5rem;
          margin-bottom: 0.5rem;
        }

        .barangay-card h4 {
          margin: 0;
          font-size: 0.95rem;
          font-weight: 600;
        }

        .barangay-card .pin-line {
          margin: 0 0 0.75rem;
          font-size: 0.8rem;
        }

        .barangay-card .pin-missing {
          color: rgb(217, 119, 6);
        }

        .barangay-card .pin-editor {
          display: flex;
          flex-direction: column;
          gap: 0.5rem;
          margin-bottom: 0.75rem;
        }

        .barangay-card .pin-editor input {
          padding: 0.45rem 0.6rem;
          border: 1px solid var(--border-color);
          border-radius: 0.375rem;
          background: var(--input-bg);
          color: var(--text-primary);
          font-size: 0.85rem;
        }

        .barangay-card .pin-actions,
        .barangay-card .card-footer {
          display: flex;
          gap: 0.5rem;
          flex-wrap: wrap;
        }
      `}</style>
    </div>
  );
}
