import { useState } from "react";
import PersonalInfoStep from "./PersonalInfoStep";
import DriverInfoStep from "./DriverInfoStep";
import DocumentsStep from "./DocumentsStep";
import LivenessStep from "./LivenessStep";
import ReviewStep from "./ReviewStep";

const STEP_TITLES = [
  "Personal Information",
  "Driver Information",
  "Required Documents",
  "Identity Verification",
  "Review & Submit",
];

export default function WizardShell({ user, mode, onSubmitted, onExit }) {
  const [step, setStep] = useState(1);
  const [maxStep, setMaxStep] = useState(1);
  const [formData, setFormData] = useState({});

  function updateFormData(patch) {
    setFormData((prev) => ({ ...prev, ...patch }));
  }

  function goTo(n) {
    const clamped = Math.min(Math.max(n, 1), STEP_TITLES.length);
    setStep(clamped);
    setMaxStep((prev) => Math.max(prev, clamped));
  }

  return (
    <div className="screen">
      <div className="shell shell-wide">
        <div className="brand">
          <span className="brand-emoji">🛺</span>
          <span className="brand-title">FindMeTricycle</span>
        </div>

        <div aria-label="Application progress">
          <div className="progress-head">
            <span>
              Step {step} of {STEP_TITLES.length} — {STEP_TITLES[step - 1]}
            </span>
            <span style={{ fontWeight: 500 }}>{Math.round((step / STEP_TITLES.length) * 100)}%</span>
          </div>
          <div className="progress-bar">
            <div style={{ width: `${(step / STEP_TITLES.length) * 100}%` }} />
          </div>
          {maxStep > 1 ? (
            <div style={{ display: "flex", gap: 6, flexWrap: "wrap", marginTop: -12, marginBottom: 8 }}>
              {STEP_TITLES.slice(0, maxStep).map((title, i) =>
                i + 1 === step ? null : (
                  <button key={title} type="button" className="link-btn" style={{ fontSize: ".78rem" }} onClick={() => goTo(i + 1)}>
                    {i + 1 < step ? "✓ " : ""}
                    {title}
                  </button>
                )
              )}
            </div>
          ) : null}
        </div>

        {step === 1 ? (
          <PersonalInfoStep formData={formData} updateFormData={updateFormData} user={user} onNext={() => goTo(2)} />
        ) : null}

        {step === 2 ? (
          <DriverInfoStep
            formData={formData}
            updateFormData={updateFormData}
            onNext={() => goTo(3)}
            onBack={() => goTo(1)}
          />
        ) : null}

        {step === 3 ? (
          <DocumentsStep
            user={user}
            formData={formData}
            updateFormData={updateFormData}
            onNext={() => goTo(4)}
            onBack={() => goTo(2)}
          />
        ) : null}

        {step === 4 ? (
          <LivenessStep
            onComplete={({ status, selfieDataUrl }) => {
              updateFormData({ livenessStatus: status, selfieDataUrl });
              goTo(5);
            }}
            onSkipToReview={(status) => {
              updateFormData({ livenessStatus: status, selfieDataUrl: null });
              goTo(5);
            }}
          />
        ) : null}

        {step === 4 ? (
          <div style={{ marginTop: 12 }}>
            <button type="button" className="btn btn-ghost" onClick={() => goTo(3)}>
              Back
            </button>
          </div>
        ) : null}

        {step === 5 ? (
          <ReviewStep formData={formData} user={user} mode={mode} onBack={() => goTo(4)} onSubmitted={onSubmitted} />
        ) : null}

        <div className="center-text" style={{ marginTop: 4 }}>
          <button type="button" className="link-btn" onClick={onExit}>
            Cancel and sign out
          </button>
        </div>
      </div>
    </div>
  );
}
