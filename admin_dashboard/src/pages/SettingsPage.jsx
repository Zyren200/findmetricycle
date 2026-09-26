import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";

export default function SettingsPage() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [settings, setSettings] = useState({
    appName: "",
    supportEmail: "",
    contactNumber: "",
    operatingHours: "",
  });

  const loadSettings = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/settings");
      setSettings(data?.data || {
        appName: "FindMeTricycle",
        supportEmail: "support@findme.local",
        contactNumber: "+63 9XX XXX XXXX",
        operatingHours: "5:00 AM - 10:00 PM",
      });
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load settings.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  function handleChange(field, value) {
    setSettings((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSave() {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await apiClient.put("/admin/settings", settings);
      setSuccess("Settings saved successfully!");
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to save settings.");
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
                  placeholder="support@findme.local"
                />
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
              </div>

              <div className="form-group">
                <label htmlFor="operatingHours">Operating Hours</label>
                <input
                  id="operatingHours"
                  type="text"
                  value={settings.operatingHours || ""}
                  onChange={(e) => handleChange("operatingHours", e.target.value)}
                  placeholder="5:00 AM - 10:00 PM"
                />
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
            <div className="info-grid">
              <div className="info-card">
                <p className="panel-label">Base Fare</p>
                <h4>PHP 20.00</h4>
                <p className="muted text-sm">Minimum starting fare for any ride</p>
              </div>
              <div className="info-card">
                <p className="panel-label">Per Kilometer</p>
                <h4>PHP 12.00</h4>
                <p className="muted text-sm">Additional charge per km traveled</p>
              </div>
              <div className="info-card">
                <p className="panel-label">Minimum Fare</p>
                <h4>PHP 0.00</h4>
                <p className="muted text-sm">Absolute minimum ride cost</p>
              </div>
              <div className="info-card">
                <p className="panel-label">Night Fee</p>
                <h4>PHP 0.00</h4>
                <p className="muted text-sm">Optional premium for evening rides</p>
              </div>
            </div>
            <p className="muted text-sm" style={{ marginTop: "1rem" }}>
              📝 <strong>Note:</strong> Manage fares from the dedicated Fare Settings page in the Settings menu.
            </p>
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
