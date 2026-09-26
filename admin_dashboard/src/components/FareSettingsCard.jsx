import { useEffect, useState } from "react";

export default function FareSettingsCard({ fare, onSave, saving }) {
  const [baseFare, setBaseFare] = useState(fare?.base_fare ?? 20);
  const [perKmRate, setPerKmRate] = useState(fare?.per_km_rate ?? 12);
  const [additionalPassengerFee, setAdditionalPassengerFee] = useState(
    fare?.additional_passenger_fee ?? 0
  );

  useEffect(() => {
    setBaseFare(fare?.base_fare ?? 20);
    setPerKmRate(fare?.per_km_rate ?? 12);
    setAdditionalPassengerFee(fare?.additional_passenger_fee ?? 0);
  }, [fare]);

  function submit(e) {
    e.preventDefault();
    if (Number(additionalPassengerFee) < 0) return;
    onSave({
      baseFare: Number(baseFare),
      perKmRate: Number(perKmRate),
      additionalPassengerFee: Number(additionalPassengerFee),
    });
  }

  return (
    <section className="panel">
      <div className="panel-header">
        <h3>Fare Settings</h3>
      </div>
      <form onSubmit={submit} className="fare-form">
        <label>
          Base Fare
          <input
            type="number"
            min="0"
            step="0.01"
            value={baseFare}
            onChange={(e) => setBaseFare(e.target.value)}
          />
        </label>
        <label>
          Per KM Rate
          <input
            type="number"
            min="0"
            step="0.01"
            value={perKmRate}
            onChange={(e) => setPerKmRate(e.target.value)}
          />
        </label>
        <label>
          Additional Passenger Fee
          <input
            type="number"
            min="0"
            step="0.01"
            value={additionalPassengerFee}
            onChange={(e) => setAdditionalPassengerFee(e.target.value)}
          />
        </label>
        <button type="submit" disabled={saving}>
          {saving ? "Saving..." : "Save Fare"}
        </button>
      </form>
    </section>
  );
}
