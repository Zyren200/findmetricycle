import { FieldError } from "./fields";

export default function PersonalInfoStep({ formData, updateFormData, user, errors }) {
  const bad = (k) => (errors?.[k] ? "bad" : "");
  return (
    <>
      <h2>Personal information</h2>
      <p className="muted">Your name, email and phone come from your account. Change them in the app if they are wrong.</p>
      <div className="two">
        <div className="fld">
          <label htmlFor="fName">Full name</label>
          <input id="fName" value={user?.fullName || user?.full_name || ""} readOnly />
        </div>
        <div className="fld">
          <label htmlFor="fPhone">Mobile number</label>
          <input id="fPhone" value={user?.phone || ""} readOnly />
        </div>
      </div>
      <div className="fld">
        <label htmlFor="fEmail">Email</label>
        <input id="fEmail" value={user?.email || ""} readOnly />
      </div>
      <div className={`fld ${bad("address")}`}>
        <label htmlFor="fAddress">Home address</label>
        <input
          id="fAddress"
          value={formData.address || ""}
          onChange={(e) => updateFormData({ address: e.target.value })}
          placeholder="House no., street, barangay, Guiuan"
          autoComplete="street-address"
        />
        <FieldError errors={errors} k="address" />
      </div>
      <div className="two">
        <div className={`fld ${bad("emergencyContactName")}`}>
          <label htmlFor="fEmName">Emergency contact name</label>
          <input
            id="fEmName"
            value={formData.emergencyContactName || ""}
            onChange={(e) => updateFormData({ emergencyContactName: e.target.value })}
            placeholder="Full name"
          />
          <FieldError errors={errors} k="emergencyContactName" />
        </div>
        <div className={`fld ${bad("emergencyContactPhone")}`}>
          <label htmlFor="fEmPhone">Emergency contact number</label>
          <input
            id="fEmPhone"
            value={formData.emergencyContactPhone || ""}
            onChange={(e) => updateFormData({ emergencyContactPhone: e.target.value })}
            inputMode="tel"
            placeholder="09XXXXXXXXX"
          />
          <FieldError errors={errors} k="emergencyContactPhone" />
        </div>
      </div>
    </>
  );
}
