import { FieldError } from "./fields";

const LICENSE_TYPES = ["Professional", "Non-Professional"];

export default function DriverInfoStep({ mode, formData, updateFormData, errors }) {
  // The plate number is set by the first application and kept on a
  // resubmission (it can be changed later in the app, Edit Profile).
  const plateLocked = mode === "resubmit" && Boolean(formData.plateNumber);
  const bad = (k) => (errors?.[k] ? "bad" : "");

  return (
    <>
      <h2>Driver information</h2>
      <p className="muted">Use the details on your license and franchise permit. You&apos;ll upload photos of them next.</p>
      <div className={`fld ${bad("licenseType")}`}>
        <span className="lbl">License type</span>
        <div className="choice" role="radiogroup" aria-label="License type">
          {LICENSE_TYPES.map((t) => (
            <label key={t}>
              <input
                type="radio"
                name="licenseType"
                value={t}
                checked={formData.licenseType === t}
                onChange={() => updateFormData({ licenseType: t })}
              />
              {t}
            </label>
          ))}
        </div>
        <FieldError errors={errors} k="licenseType" />
      </div>
      <div className="two">
        <div className={`fld ${bad("plateNumber")}`}>
          <label htmlFor="fPlate">Plate number</label>
          <input
            id="fPlate"
            value={formData.plateNumber || ""}
            onChange={(e) => updateFormData({ plateNumber: e.target.value.toUpperCase() })}
            placeholder="GN 4821"
            readOnly={plateLocked}
            style={{ textTransform: "uppercase" }}
          />
          {plateLocked ? (
            <span className="hint">The plate stays the same on a resubmission. Change it in the app after approval.</span>
          ) : null}
          <FieldError errors={errors} k="plateNumber" />
        </div>
        <div className="fld">
          <label htmlFor="fFranchise">Franchise / permit number (optional)</label>
          <input
            id="fFranchise"
            value={formData.franchiseNumber || ""}
            onChange={(e) => updateFormData({ franchiseNumber: e.target.value.toUpperCase() })}
            placeholder="GUI-CPC-0457"
            style={{ textTransform: "uppercase" }}
          />
          <span className="hint">As shown on your permit, if it has one.</span>
        </div>
      </div>
    </>
  );
}
