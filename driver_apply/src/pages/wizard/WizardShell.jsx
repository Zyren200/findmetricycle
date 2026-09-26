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

        <div className="route" aria-label="Application progress">
          <div className="route-track">
            <div
              className="route-fill"
              style={{ width: `${((step - 1) / (STEP_TITLES.length - 1)) * 100}%` }}
            />
          </div>
          <ol className="route-stops">
            {STEP_TITLES.map((title, i) => {
              const n = i + 1;
              const done = n < step;
              const current = n === step;
              return (
                <li key={n}>
                  <button
                    type="button"
                    className={`stop ${done ? "done" : ""} ${current ? "current" : ""}`}
                    disabled={n > maxStep}
                    onClick={() => n <= maxStep && n !== step && goTo(n)}
                  >
                    <span className="stop-dot">{done ? "✓" : n}</span>
                    <span className="stop-label">{title.split(" ")[0]}</span>
                  </button>
                </li>
              );
            })}
          </ol>
        </div>

        <p className="progress-label center-text">
          Step {step} of {STEP_TITLES.length} — {STEP_TITLES[step - 1]}
        </p>

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
