import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";

export default function SettingsPage({ onOpenFares }) {
  const [fare, setFare] = useState(null);
  const [fareError, setFareError] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [settings, setSettings] = useState({
    appName: "",
    supportEmail: "",
    contactNumber: "",
    operatingHoursStart: "05:00",
    operatingHoursEnd: "22:00",
    enforceOperatingHours: false,
  });

  const loadSettings = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/settings");
      if (data?.data) setSettings(data.data);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load settings.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSettings();
    apiClient
      .get("/admin/fare")
      .then(({ data }) => setFare(data?.data || null))
      .catch((err) => setFareError(err?.response?.data?.message || "Failed to load fares."));
  }, [loadSettings]);

  function handleChange(field, value) {
    setSettings((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSave() {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const { data } = await apiClient.put("/admin/settings", settings);
      if (data?.data) setSettings(data.data);
      setSuccess("Settings saved. The apps pick up the change within a minute.");
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      // Validation errors name the field that needs fixing.
      const issue = err?.response?.data?.details?.issues?.[0]?.message;
      setError(issue || err?.response?.data?.message || "Failed to save settings.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="System configuration"
        title="Settings"
        description="Adjust application name, contact details, operating hours, and fare rules."
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {success ? <div className="success-banner">{success}</div> : null}
      {loading ? <div className="state-block">Loading settings...</div> : null}

      {!loading ? (
        <>
          <section className="panel">
            <div className="panel-header">
              <h3>Application Details</h3>
            </div>
            <form className="form-grid" onSubmit={(e) => e.preventDefault()}>
              <div className="form-group">
                <label htmlFor="appName">App Name</label>
                <input
                  id="appName"
                  type="text"
                  value={settings.appName || ""}
                  onChange={(e) => handleChange("appName", e.target.value)}
                  placeholder="FindMeTricycle"
                />
              </div>

              <div className="form-group">
                <label htmlFor="supportEmail">Support Email</label>
                <input
                  id="supportEmail"
                  type="email"
                  value={settings.supportEmail || ""}
                  onChange={(e) => handleChange("supportEmail", e.target.value)}
                  placeholder="help@yourdomain.com"
                />
                <span className="field-hint">Shown under Help &amp; Support in the passenger and driver apps. Leave blank to hide.</span>
              </div>

              <div className="form-group">
                <label htmlFor="contactNumber">Contact Number</label>
                <input
                  id="contactNumber"
                  type="tel"
                  value={settings.contactNumber || ""}
                  onChange={(e) => handleChange("contactNumber", e.target.value)}
                  placeholder="+63 9XX XXX XXXX"
                />
                <span className="field-hint">Users can tap it to call. Leave blank to hide.</span>
              </div>

              <div className="form-group">
                <label htmlFor="operatingHoursStart">Operating Hours (Philippine time)</label>
                <div className="hours-row">
                  <input
                    id="operatingHoursStart"
                    type="time"
                    value={settings.operatingHoursStart || ""}
                    onChange={(e) => handleChange("operatingHoursStart", e.target.value)}
                    aria-label="Opens at"
                  />
                  <span className="muted">to</span>
                  <input
                    id="operatingHoursEnd"
                    type="time"
                    value={settings.operatingHoursEnd || ""}
                    onChange={(e) => handleChange("operatingHoursEnd", e.target.value)}
                    aria-label="Closes at"
                  />
                </div>
                <label className="checkbox-row" htmlFor="enforceOperatingHours">
                  <input
                    id="enforceOperatingHours"
                    type="checkbox"
                    checked={Boolean(settings.enforceOperatingHours)}
                    onChange={(e) => handleChange("enforceOperatingHours", e.target.checked)}
                  />
                  Block new bookings outside these hours
                </label>
                <span className="field-hint">
                  {settings.enforceOperatingHours
                    ? "Passengers can only book during these hours. Rides already in progress are not affected."
                    : "Hours are shown in the apps only; booking stays open 24 hours."}
                </span>
              </div>

              <div className="form-group form-actions">
                <button
                  type="button"
                  className="btn btn-primary"
                  disabled={saving}
                  onClick={handleSave}
                >
                  {saving ? "Saving..." : "Save Settings"}
                </button>
                <button type="button" className="btn btn-secondary" onClick={loadSettings}>
                  Cancel
                </button>
              </div>
            </form>
          </section>

          <section className="panel">
            <div className="panel-header">
              <h3>Fare Management</h3>
            </div>
            {fare ? (
              <div className="info-grid">
                {[
                  ["Base Fare", fare.base_fare, "Starting fare for any ride"],
                  ["Per Kilometer", fare.per_km_rate, "Additional charge per km traveled"],
                  ["Minimum Fare", fare.minimum_fare, "Absolute minimum ride cost"],
                  ["Night Fee", fare.night_fee, "Premium for evening rides"],
                  ["Extra Passenger Fee", fare.additional_passenger_fee, "Per passenger after the first"],
                ].map(([label, value, hint]) => (
                  <div className="info-card" key={label}>
                    <p className="panel-label">{label}</p>
                    <h4>PHP {Number(value || 0).toFixed(2)}</h4>
                    <p className="muted text-sm">{hint}</p>
                  </div>
                ))}
              </div>
            ) : (
              <div className="state-block">{fareError || "Loading current fares..."}</div>
            )}
            <div style={{ marginTop: "1rem", display: "flex", gap: 12, alignItems: "center", flexWrap: "wrap" }}>
              {onOpenFares ? (
                <button type="button" className="btn btn-primary" onClick={onOpenFares}>
                  Edit Fares
                </button>
              ) : null}
              <span className="muted text-sm">These are the live fares used by the app. Change them in Fare Settings.</span>
            </div>
          </section>
        </>
      ) : null}

      <style>{`
        .form-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
          gap: 1.5rem;
          margin-top: 1rem;
        }

        .form-group {
          display: flex;
          flex-direction: column;
        }

        .form-group label {
          font-size: 0.875rem;
          font-weight: 600;
          margin-bottom: 0.5rem;
          color: var(--text-muted);
        }

        .form-group input {
          padding: 0.75rem;
          border: 1px solid var(--border-color);
          border-radius: 0.375rem;
          background: var(--input-bg);
          color: var(--text-primary);
          font-size: 0.95rem;
        }

        .form-group input:focus {
          outline: none;
          border-color: rgb(59, 130, 246);
          box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }

        .field-hint {
          margin-top: 0.4rem;
          font-size: 0.8rem;
          color: var(--text-muted);
        }

        .hours-row {
          display: flex;
          align-items: center;
          gap: 0.5rem;
        }

        .hours-row input {
          flex: 1;
          min-width: 0;
        }

        .form-group .checkbox-row {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          margin: 0.75rem 0 0;
          font-weight: 500;
          color: var(--text-primary);
          cursor: pointer;
        }

        .form-group .checkbox-row input {
          padding: 0;
          width: 1rem;
          height: 1rem;
        }

        .form-group.form-actions {
          grid-column: 1 / -1;
          display: flex;
          gap: 1rem;
          margin-top: 1rem;
        }

        .info-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 1rem;
          margin-top: 1rem;
        }

        .info-card {
          padding: 1rem;
          border: 1px solid var(--border-color);
          border-radius: 0.375rem;
          background: rgba(59, 130, 246, 0.02);
        }

        .info-card .panel-label {
          font-size: 0.75rem;
          text-transform: uppercase;
          letter-spacing: 0.05em;
          color: var(--text-muted);
          margin: 0 0 0.5rem 0;
        }

        .info-card h4 {
          margin: 0 0 0.5rem 0;
          font-size: 1.5rem;
          color: var(--text-primary);
        }

        .text-sm {
          font-size: 0.875rem;
        }
      `}</style>
    </div>
  );
}
