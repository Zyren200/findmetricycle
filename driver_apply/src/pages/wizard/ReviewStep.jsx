import { ICON } from "../../components/Icons";
import { Alert } from "../../components/ui";

function Block({ title, step, onEdit, rows }) {
  return (
    <div className="sum-block">
      <header>
        <b>{title}</b>
        <button className="btn btn-ghost btn-sm" type="button" onClick={() => onEdit(step)}>
          {ICON.edit} Edit
        </button>
      </header>
      <div className="kv">
        {rows.map(([k, v]) => [<span key={`${k}-k`}>{k}</span>, <span key={`${k}-v`}>{v || "—"}</span>])}
      </div>
    </div>
  );
}

const pill = (tone, text) => <span className={`pill ${tone}`}>{text}</span>;

function docState(file, warning) {
  if (!file) return "Missing";
  return warning ? pill("warn", "Sent for admin review") : pill("ok", "Passed");
}

/** Everything once more, each block with Edit, and the confirmation box. */
export default function ReviewStep({ formData, updateFormData, user, errors, onEdit }) {
  const face = formData.livenessStatus;
  return (
    <>
      <h2>Review and submit</h2>
      <p className="muted">Check everything once more. You can edit any step.</p>
      <div className="summary">
        <Block
          title="Personal information"
          step={0}
          onEdit={onEdit}
          rows={[
            ["Name", user?.fullName || user?.full_name],
            ["Email", user?.email],
            ["Mobile", user?.phone],
            ["Address", formData.address],
            ["Emergency contact", `${formData.emergencyContactName || ""} · ${formData.emergencyContactPhone || ""}`],
          ]}
        />
        <Block
          title="Driver information"
          step={1}
          onEdit={onEdit}
          rows={[
            ["License type", formData.licenseType],
            ["Plate number", formData.plateNumber],
            ["Franchise / permit no.", formData.franchiseNumber],
          ]}
        />
        <Block
          title="Documents"
          step={2}
          onEdit={onEdit}
          rows={[
            ["Driver's license", docState(formData.licenseFile, formData.licenseWarning)],
            ["Franchise / permit", docState(formData.permitFile, formData.permitWarning)],
          ]}
        />
        <Block
          title="Identity"
          step={3}
          onEdit={onEdit}
          rows={[["Face check", !face ? "Missing" : face === "passed" ? pill("ok", "Passed") : pill("warn", "Needs review")]]}
        />
      </div>
      <label className="check">
        <input type="checkbox" checked={Boolean(formData.confirmed)} onChange={(e) => updateFormData({ confirmed: e.target.checked })} />
        <span>I confirm that this information is correct and that these documents are mine.</span>
      </label>
      {errors?.confirm ? <Alert tone="err">{errors.confirm}</Alert> : null}
    </>
  );
}
