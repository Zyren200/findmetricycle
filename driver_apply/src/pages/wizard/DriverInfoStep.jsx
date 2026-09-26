import { useState } from "react";

export default function DriverInfoStep({ formData, updateFormData, onNext, onBack }) {
  const [errors, setErrors] = useState({});

  function validate() {
    const next = {};
    if (!formData.plateNumber?.trim()) next.plateNumber = "Plate number is required.";
    if (!formData.licenseType) next.licenseType = "Select a license type.";
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  return (
    <div className="card">
      <h2>Driver Information</h2>
      <p>Tell us about your license and vehicle. You'll upload photos of these documents next.</p>

      <div className="field">
        <label htmlFor="licenseType">License Type</label>
        <select
          id="licenseType"
          value={formData.licenseType || ""}
          onChange={(e) => updateFormData({ licenseType: e.target.value })}
        >
          <option value="">Select license type</option>
          <option value="Non-Professional">Non-Professional</option>
          <option value="Professional">Professional</option>
        </select>
        {errors.licenseType ? <span className="field-error">{errors.licenseType}</span> : null}
      </div>

      <div className="field">
        <label htmlFor="plateNumber">Tricycle / Vehicle Plate Number</label>
        <input
          id="plateNumber"
          type="text"
          value={formData.plateNumber || ""}
          onChange={(e) => updateFormData({ plateNumber: e.target.value.toUpperCase() })}
          placeholder="e.g. ABC 1234"
        />
        {errors.plateNumber ? <span className="field-error">{errors.plateNumber}</span> : null}
      </div>

      <div className="field">
        <label htmlFor="franchiseNumber">Franchise / Permit Number (optional)</label>
        <input
          id="franchiseNumber"
          type="text"
          value={formData.franchiseNumber || ""}
          onChange={(e) => updateFormData({ franchiseNumber: e.target.value })}
          placeholder="If available"
        />
        <span className="field-hint">You'll confirm your license number automatically from the photo in the next step.</span>
      </div>

      <div className="btn-row">
        <button type="button" className="btn btn-ghost" onClick={onBack}>
          Back
        </button>
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => {
            if (validate()) onNext();
          }}
        >
          Continue
        </button>
      </div>
    </div>
  );
}
