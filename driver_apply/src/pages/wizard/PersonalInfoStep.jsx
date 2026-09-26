import { useState } from "react";

export default function PersonalInfoStep({ formData, updateFormData, onNext, user }) {
  const [errors, setErrors] = useState({});

  function validate() {
    const next = {};
    if (!formData.address?.trim()) next.address = "Address is required.";
    if (!formData.emergencyContactName?.trim()) next.emergencyContactName = "Emergency contact name is required.";
    if (!/^[0-9+ -]{7,20}$/.test(formData.emergencyContactPhone || "")) {
      next.emergencyContactPhone = "Enter a valid contact number.";
    }
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  return (
    <div className="card">
      <h2>Personal Information</h2>
      <p>Some details are pre-filled from your FindMeTricycle account.</p>

      <div className="field">
        <label>Full Name</label>
        <input type="text" value={user?.fullName || user?.full_name || ""} disabled />
      </div>
      <div className="field">
        <label>Email</label>
        <input type="text" value={user?.email || ""} disabled />
      </div>
      <div className="field">
        <label>Contact Number</label>
        <input type="text" value={user?.phone || ""} disabled />
      </div>

      <div className="field">
        <label htmlFor="address">Address</label>
        <input
          id="address"
          type="text"
          value={formData.address || ""}
          onChange={(e) => updateFormData({ address: e.target.value })}
          placeholder="House No., Street, Barangay, City"
        />
        {errors.address ? <span className="field-error">{errors.address}</span> : null}
      </div>

      <div className="field">
        <label htmlFor="emergencyContactName">Emergency Contact Name</label>
        <input
          id="emergencyContactName"
          type="text"
          value={formData.emergencyContactName || ""}
          onChange={(e) => updateFormData({ emergencyContactName: e.target.value })}
          placeholder="Full name"
        />
        {errors.emergencyContactName ? <span className="field-error">{errors.emergencyContactName}</span> : null}
      </div>

      <div className="field">
        <label htmlFor="emergencyContactPhone">Emergency Contact Number</label>
        <input
          id="emergencyContactPhone"
          type="text"
          value={formData.emergencyContactPhone || ""}
          onChange={(e) => updateFormData({ emergencyContactPhone: e.target.value })}
          placeholder="09XX XXX XXXX"
        />
        {errors.emergencyContactPhone ? <span className="field-error">{errors.emergencyContactPhone}</span> : null}
      </div>

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
  );
}
