import { useEffect, useRef, useState } from "react";
import { apiClient } from "../../api/client";
import { firstName } from "../../components/Layout";
import { ICON } from "../../components/Icons";
import { Alert, ConfirmModal, Head, Modal, OtpInputs } from "../../components/ui";
import DocumentsStep, { validateDocuments } from "./DocumentsStep";
import DriverInfoStep from "./DriverInfoStep";
import LivenessStep from "./LivenessStep";
import PersonalInfoStep from "./PersonalInfoStep";
import ReviewStep from "./ReviewStep";

const STEPS = [
  { t: "Personal Information", s: "Address, emergency contact" },
  { t: "Driver Information", s: "License type, plate, franchise" },
  { t: "Required Documents", s: "License and permit photos" },
  { t: "Identity Verification", s: "Live face check" },
  { t: "Review & Submit", s: "Check and confirm" },
];

const PHONE_RE = /^(09\d{9}|\+639\d{9})$/;
const cleanPhone = (v) => String(v || "").replace(/[\s-]/g, "");

function validateStep(i, d, user) {
  const e = {};
  if (i === 0) {
    if ((d.address || "").trim().length < 8) e.address = "Enter your full home address (barangay and town).";
    if ((d.emergencyContactName || "").trim().length < 3) e.emergencyContactName = "Enter the name of your emergency contact.";
    const phone = cleanPhone(d.emergencyContactPhone);
    if (!PHONE_RE.test(phone)) e.emergencyContactPhone = "Use an 11-digit mobile number like 09171234567.";
    else if (user?.phone && phone.replace(/^\+63/, "0") === cleanPhone(user.phone).replace(/^\+63/, "0")) {
      e.emergencyContactPhone = "Use someone else's number, not your own.";
    }
  }
  if (i === 1) {
    if (!d.licenseType) e.licenseType = "Choose your license type.";
    if (!(d.plateNumber || "").trim()) e.plateNumber = "Enter the plate number as shown on the tricycle, like GN 4821.";
  }
  if (i === 2) Object.assign(e, validateDocuments(d));
  if (i === 3 && !d.livenessStatus) e.face = "Do the face check, or continue without it if your camera is not working.";
  if (i === 4 && !d.confirmed) e.confirm = "Tick the box to confirm your details are correct.";
  return e;
}

function dataUrlToBlob(dataUrl) {
  const [header, base64] = dataUrl.split(",");
  const mime = header.match(/data:(.*);base64/)?.[1] || "image/jpeg";
  const bytes = atob(base64);
  const array = new Uint8Array(bytes.length);
  for (let i = 0; i < bytes.length; i += 1) array[i] = bytes.charCodeAt(i);
  return new Blob([array], { type: mime });
}

const errorText = (err, fallback) => err?.response?.data?.message || err?.message || fallback;

export default function WizardShell({ user, mode, previous, onSubmitted, onExit }) {
  const resubmit = mode === "resubmit";
  // A resubmission starts at the documents, with steps 1 and 2 filled in from
  // the previous application; new documents and a new face check are always needed.
  const [step, setStep] = useState(resubmit ? 2 : 0);
  const [maxStep, setMaxStep] = useState(resubmit ? 2 : 0);
  const [dir, setDir] = useState("fwd");
  const [errors, setErrors] = useState({});
  const [busyDocs, setBusyDocs] = useState({});
  const [formData, setFormData] = useState(() =>
    previous
      ? {
          address: previous.address || "",
          emergencyContactName: previous.emergency_contact_name || "",
          emergencyContactPhone: previous.emergency_contact_phone || "",
          licenseType: previous.license_type || "",
          plateNumber: previous.plate_number || "",
          franchiseNumber: previous.franchise_number || "",
        }
      : {}
  );
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState(null);
  const [otpOpen, setOtpOpen] = useState(false);
  const [confirmExit, setConfirmExit] = useState(false);
  const panelRef = useRef(null);

  const adminNote = previous?.correction_note || previous?.rejection_reason || "";
  const busy = Object.values(busyDocs).some(Boolean);
  const pct = Math.round((step / (STEPS.length - 1)) * 100);
  const last = step === STEPS.length - 1;

  function updateFormData(patch) {
    setFormData((prev) => ({ ...prev, ...patch }));
  }

  function goTo(n) {
    const target = Math.min(Math.max(n, 0), STEPS.length - 1);
    setDir(target >= step ? "fwd" : "back");
    setErrors({});
    setSubmitError(null);
    setStep(target);
    setMaxStep((m) => Math.max(m, target));
    window.scrollTo({ top: 0, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
  }

  function nudge() {
    const p = panelRef.current;
    if (!p) return;
    p.classList.remove("nudge");
    void p.offsetWidth;
    p.classList.add("nudge");
    requestAnimationFrame(() => p.querySelector(".bad input, .err, .alert.err")?.scrollIntoView({ block: "center", behavior: "smooth" }));
  }

  function next() {
    const errs = validateStep(step, formData, user);
    setErrors(errs);
    if (Object.keys(errs).length) {
      nudge();
      return;
    }
    if (last) submit();
    else goTo(step + 1);
  }

  async function submit() {
    setSubmitting(true);
    setSubmitError(null);
    try {
      const body = new FormData();
      if (!resubmit) body.append("plateNumber", formData.plateNumber || "");
      if (formData.franchiseNumber) body.append("franchiseNumber", formData.franchiseNumber);
      if (formData.licenseType) body.append("licenseType", formData.licenseType);
      if (formData.address) body.append("address", formData.address);
      if (formData.emergencyContactName) body.append("emergencyContactName", formData.emergencyContactName);
      if (formData.emergencyContactPhone) body.append("emergencyContactPhone", cleanPhone(formData.emergencyContactPhone));
      if (formData.licenseOcrText) body.append("licenseOcrText", formData.licenseOcrText);
      body.append("livenessStatus", formData.livenessStatus || "needs_review");
      body.append("licenseImage", formData.licenseFile, formData.licenseFile.name || "license.jpg");
      body.append("businessPermitImage", formData.permitFile, formData.permitFile.name || "permit.jpg");
      if (formData.selfieDataUrl) body.append("selfieImage", dataUrlToBlob(formData.selfieDataUrl), "selfie.jpg");

      const endpoint = resubmit ? "/auth/v2/resubmit-driver-application" : "/auth/v2/apply-driver";
      const { data } = await apiClient.post(endpoint, body, { headers: { "Content-Type": "multipart/form-data" } });
      if (!data?.success) throw new Error(data?.message || "Submission failed.");
      onSubmitted(data?.data || {}, {
        manualReview: Boolean(formData.licenseWarning || formData.permitWarning) || formData.livenessStatus !== "passed",
      });
    } catch (err) {
      // The email confirmation is more than an hour old: confirm it again.
      if (err?.response?.data?.details?.code === "OTP_REQUIRED") {
        setOtpOpen(true);
        return;
      }
      setSubmitError(errorText(err, "Submission failed. Please try again."));
    } finally {
      setSubmitting(false);
    }
  }

  const stepView = [
    <PersonalInfoStep key={0} formData={formData} updateFormData={updateFormData} user={user} errors={errors} />,
    <DriverInfoStep key={1} mode={mode} formData={formData} updateFormData={updateFormData} errors={errors} />,
    <DocumentsStep
      key={2}
      user={user}
      formData={formData}
      updateFormData={updateFormData}
      errors={errors}
      onBusyChange={(kind, value) => setBusyDocs((b) => ({ ...b, [kind]: value }))}
    />,
    <LivenessStep key={3} formData={formData} updateFormData={updateFormData} errors={errors} />,
    <ReviewStep key={4} formData={formData} updateFormData={updateFormData} user={user} errors={errors} onEdit={goTo} />,
  ][step];

  return (
    <section>
      <div className="wrap">
        <Head
          eyebrow={resubmit ? "Resubmission" : "Driver application"}
          title={resubmit ? "Update your application" : `Apply as a driver, ${firstName(user)}`}
        />
        {resubmit && adminNote ? (
          <Alert tone="warn" title="Note from the admin" style={{ marginBottom: 16 }}>
            {adminNote}
            <br />
            <span className="muted">
              Steps 1 and 2 are filled in from your last application. Open them to fix anything the admin mentioned. New
              document photos and a new face check are required.
            </span>
          </Alert>
        ) : null}
        <div className="wiz glass">
          <nav className="wiz-side" aria-label="Application steps">
            {STEPS.map((s, i) => {
              const done = i < step || (i <= maxStep && i !== step && Object.keys(validateStep(i, formData, user)).length === 0);
              return (
                <button
                  key={s.t}
                  type="button"
                  data-step={i}
                  className={`${i === step ? "on" : ""} ${done ? "done" : ""}`}
                  disabled={i > maxStep || busy || submitting}
                  aria-current={i === step ? "step" : undefined}
                  onClick={() => goTo(i)}
                >
                  <span className="n">{done && i !== step ? "✓" : i + 1}</span>
                  <span>
                    <b>{s.t}</b>
                    <small>{s.s}</small>
                  </span>
                </button>
              );
            })}
            <div className="foot">
              <p className="muted" style={{ fontSize: 12, padding: "6px 12px" }}>
                Your answers stay while this page is open.
              </p>
              <button className="btn btn-ghost btn-sm" type="button" onClick={() => setConfirmExit(true)}>
                Cancel and sign out
              </button>
            </div>
          </nav>
          <div className="wiz-main">
            <div className="row muted" style={{ justifyContent: "space-between", fontSize: 13, marginBottom: 8 }}>
              <span>
                Step {step + 1} of {STEPS.length}
              </span>
              <span>{pct}%</span>
            </div>
            <div className="progress" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100}>
              <span style={{ width: `${Math.max(6, pct)}%`, transition: "width .9s cubic-bezier(.22,1,.36,1)" }} />
            </div>
            <div className="panel" key={step} data-dir={dir} ref={panelRef}>
              {stepView}
              {last && submitError ? <Alert tone="err">{submitError}</Alert> : null}
              <div className="nav-row">
                <button
                  className="btn btn-glass"
                  type="button"
                  style={step === 0 ? { visibility: "hidden" } : undefined}
                  disabled={busy || submitting}
                  onClick={() => goTo(step - 1)}
                >
                  Back
                </button>
                <button className="btn btn-hot" type="button" disabled={busy || submitting} onClick={next}>
                  {last
                    ? submitting
                      ? "Submitting…"
                      : resubmit
                        ? "Submit Resubmission"
                        : "Submit Application"
                    : busy
                      ? "Checking photo…"
                      : `Next: ${STEPS[step + 1].t}`}{" "}
                  {ICON.arrow}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {otpOpen ? (
        <ReverifyModal
          email={user?.email}
          onClose={() => setOtpOpen(false)}
          onVerified={() => {
            setOtpOpen(false);
            submit();
          }}
        />
      ) : null}
      {confirmExit ? (
        <ConfirmModal
          title="Cancel and sign out?"
          text="Your answers on this page will be lost. You can start again any time by signing in."
          okLabel="Sign out"
          danger
          onOk={onExit}
          onClose={() => setConfirmExit(false)}
        />
      ) : null}
    </section>
  );
}

/** "Confirm it's still you": a fresh email code before an application older than an hour's sign-in is accepted. */
function ReverifyModal({ email, onClose, onVerified }) {
  const [digits, setDigits] = useState(["", "", "", "", "", ""]);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const sentOnce = useRef(false);

  async function send() {
    setError(null);
    try {
      await apiClient.post("/auth/v2/driver-application/otp/send");
      setSent(true);
    } catch (err) {
      setError(errorText(err, "Could not send the verification code."));
    }
  }

  useEffect(() => {
    if (sentOnce.current) return;
    sentOnce.current = true;
    send();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function verify(e) {
    e?.preventDefault();
    const code = digits.join("");
    if (code.length !== 6) {
      setError("Enter the 6-digit code from your email.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await apiClient.post("/auth/v2/driver-application/otp/verify", { code });
      onVerified();
    } catch (err) {
      setDigits(["", "", "", "", "", ""]);
      setError(errorText(err, "That code is not correct or has expired."));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal onClose={onClose}>
      <span className="eyebrow">Confirm it&apos;s still you</span>
      <h3 style={{ fontSize: 22, marginTop: 10 }}>Enter a new email code</h3>
      <p className="muted" style={{ marginTop: 8 }}>
        Your sign-in is more than an hour old. Your answers are kept. {sent ? `We sent a new code to ${email || "your email"}.` : "Sending a code to your email…"}
      </p>
      <form className="stack" style={{ marginTop: 18 }} onSubmit={verify}>
        <OtpInputs digits={digits} setDigits={setDigits} />
        {error ? <Alert tone="err">{error}</Alert> : null}
        <div className="row" style={{ justifyContent: "space-between" }}>
          <button className="btn btn-ghost btn-sm" type="button" onClick={send} disabled={busy}>
            Resend code
          </button>
          <div className="row">
            <button className="btn btn-glass" type="button" data-close onClick={onClose}>
              Cancel
            </button>
            <button className="btn btn-hot" type="submit" disabled={busy}>
              {busy ? "Verifying…" : "Verify and submit"}
            </button>
          </div>
        </div>
      </form>
    </Modal>
  );
}
