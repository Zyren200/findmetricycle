import { useCallback, useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";

const MAX_PASSENGERS = 5;

export default function FareSettingsPage() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [fares, setFares] = useState({
    baseFare: 20.0,
    perKmRate: 12.0,
    minimumFare: 0.0,
    nightFee: 0.0,
    additionalPassengerFee: 0.0,
  });

  const loadFares = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/fare");
      if (data?.data) {
        setFares({
          baseFare: parseFloat(data.data.base_fare) || 20.0,
          perKmRate: parseFloat(data.data.per_km_rate) || 12.0,
          minimumFare: parseFloat(data.data.minimum_fare) || 0.0,
          nightFee: parseFloat(data.data.night_fee) || 0.0,
          additionalPassengerFee: parseFloat(data.data.additional_passenger_fee) || 0.0,
        });
      }
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load fare settings.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadFares();
  }, [loadFares]);

  function handleChange(field, value) {
    const numValue = parseFloat(value) || 0;
    setFares((prev) => ({ ...prev, [field]: numValue }));
  }

  async function handleSave() {
    if (fares.additionalPassengerFee < 0) {
      setError("Additional Passenger Fee cannot be negative.");
      return;
    }

    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await apiClient.put("/admin/fare", {
        baseFare: parseFloat(fares.baseFare),
        perKmRate: parseFloat(fares.perKmRate),
        minimumFare: parseFloat(fares.minimumFare),
        nightFee: parseFloat(fares.nightFee),
        additionalPassengerFee: parseFloat(fares.additionalPassengerFee),
      });
      setSuccess("Fare settings updated successfully!");
      setTimeout(() => setSuccess(null), 3000);
      loadFares();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to save fare settings.");
    } finally {
      setSaving(false);
    }
  }

  function handleCancel() {
    loadFares();
    setError(null);
  }

  const onePassengerFare = useMemo(
    () => Math.max(Number(fares.baseFare) || 0, Number(fares.minimumFare) || 0),
    [fares.baseFare, fares.minimumFare]
  );

  const passengerPreviewRows = useMemo(() => {
    const fee = Number(fares.additionalPassengerFee) || 0;
    return Array.from({ length: MAX_PASSENGERS }, (_, idx) => {
      const passengers = idx + 1;
      const additionalFee = (passengers - 1) * fee;
      const total = onePassengerFare + additionalFee;
      return { passengers, additionalFee, total };
    });
  }, [fares.additionalPassengerFee, onePassengerFare]);

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Pricing configuration"
        title="Fare Settings"
        description="Adjust base fare, per-kilometer rate, and premium charges for rides."
        actions={
          <button type="button" className="ghost-btn" onClick={loadFares} disabled={loading}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {success ? <div className="success-banner">{success}</div> : null}
      {loading ? <div className="state-block">Loading fare settings...</div> : null}

      {!loading ? (
        <>
          <section className="panel">
            <div className="panel-header">
              <h3>Fare Configuration</h3>
            </div>
            <form className="form-grid" onSubmit={(e) => e.preventDefault()}>
              <div className="form-group">
                <label htmlFor="baseFare">Base Fare (PHP)</label>
                <input
                  id="baseFare"
                  type="number"
                  step="0.50"
                  min="0"
                  value={fares.baseFare}
                  onChange={(e) => handleChange("baseFare", e.target.value)}
                  placeholder="20.00"
                />
                <small>Starting fare for every ride</small>
              </div>

              <div className="form-group">
                <label htmlFor="perKmRate">Per Kilometer (PHP)</label>
                <input
                  id="perKmRate"
                  type="number"
                  step="0.50"
                  min="0"
                  value={fares.perKmRate}
                  onChange={(e) => handleChange("perKmRate", e.target.value)}
                  placeholder="12.00"
                />
                <small>Charge per km distance</small>
              </div>

              <div className="form-group">
                <label htmlFor="minimumFare">Minimum Fare (PHP)</label>
                <input
                  id="minimumFare"
                  type="number"
                  step="0.50"
                  min="0"
                  value={fares.minimumFare}
                  onChange={(e) => handleChange("minimumFare", e.target.value)}
                  placeholder="0.00"
                />
                <small>Lowest possible fare regardless of distance</small>
              </div>

              <div className="form-group">
                <label htmlFor="nightFee">Night Premium (PHP)</label>
                <input
                  id="nightFee"
                  type="number"
                  step="0.50"
                  min="0"
                  value={fares.nightFee}
                  onChange={(e) => handleChange("nightFee", e.target.value)}
                  placeholder="0.00"
                />
                <small>Additional charge for evening/night rides</small>
              </div>

              <div className="form-group">
                <label htmlFor="additionalPassengerFee">Additional Passenger Fee (PHP)</label>
                <input
                  id="additionalPassengerFee"
                  type="number"
                  step="0.50"
                  min="0"
                  value={fares.additionalPassengerFee}
                  onChange={(e) => handleChange("additionalPassengerFee", e.target.value)}
                  placeholder="5.00"
                />
                <small>Charged for each passenger after the first (max {MAX_PASSENGERS} passengers)</small>
              </div>
            </form>
          </section>

          <section className="panel">
            <div className="panel-header">
              <h3>👥 Passenger Fee Preview</h3>
            </div>
            <p style={{ padding: "0 16px", marginTop: 0 }}>
              Maximum passenger capacity is fixed at {MAX_PASSENGERS}. Preview based on the current
              1-passenger fare of PHP {onePassengerFare.toFixed(2)}.
            </p>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Passengers</th>
                    <th>Additional Fee</th>
                    <th>Example Total</th>
                  </tr>
                </thead>
                <tbody>
                  {passengerPreviewRows.map((row) => (
                    <tr key={row.passengers}>
                      <td>{row.passengers}</td>
                      <td>PHP {row.additionalFee.toFixed(2)}</td>
                      <td>PHP {row.total.toFixed(2)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className="panel">
            <div className="panel-header">
              <h3>💡 Fare Calculation Examples</h3>
            </div>
            <div className="detail-list">
              <div className="detail-row">
                <span>Short Ride (2 km)</span>
                <span>PHP {Math.max(fares.baseFare + 2 * fares.perKmRate, fares.minimumFare).toFixed(2)}</span>
              </div>
              <div className="detail-row">
                <span>Medium Ride (5 km)</span>
                <span>PHP {Math.max(fares.baseFare + 5 * fares.perKmRate, fares.minimumFare).toFixed(2)}</span>
              </div>
              <div className="detail-row">
                <span>Long Ride (10 km)</span>
                <span>PHP {Math.max(fares.baseFare + 10 * fares.perKmRate, fares.minimumFare).toFixed(2)}</span>
              </div>
            </div>
          </section>

          <div style={{ display: "flex", gap: "12px", justifyContent: "flex-end", padding: "0 16px" }}>
            <button type="button" className="ghost-btn" onClick={handleCancel} disabled={saving}>
              Cancel
            </button>
            <button
              type="button"
              className="primary-btn"
              onClick={handleSave}
              disabled={saving}
              style={{ opacity: saving ? 0.6 : 1 }}
            >
              {saving ? "Saving..." : "Save Fare Settings"}
            </button>
          </div>
        </>
      ) : null}
    </div>
  );
}
