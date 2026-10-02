import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../../api/client";
import { useAuth } from "../../context/AuthContext";
import { Link, navigate, useDocumentTitle } from "../../router";
import CaptchaPage from "../CaptchaPage";
import LoginPage from "../LoginPage";
import OtpPage from "../OtpPage";
import WizardShell from "../wizard/WizardShell";

const PRE_STEP_LABELS = {
  captcha: "Verification",
  login: "Account",
  otp: "Email OTP",
  checking: "Account",
};

/// Driver application: CAPTCHA → sign in → email OTP → the application
/// wizard. A signed-in rider who already has an application is sent to
/// the status page instead, unless they're updating / resubmitting it.
export default function ApplyPage() {
  useDocumentTitle("Driver Application — FindMeTricycle");
  const { isAuthenticated, isCaptchaVerified, user, logout } = useAuth();
  const resubmit = new URLSearchParams(window.location.search).get("resubmit") === "1";

  const [step, setStep] = useState(isAuthenticated ? "checking" : isCaptchaVerified ? "login" : "captcha");
  const [otpContext, setOtpContext] = useState(null);
  const [wizardMode, setWizardMode] = useState("new");
  const [checkError, setCheckError] = useState(null);
  const [submitted, setSubmitted] = useState(null);

  const checkApplication = useCallback(async () => {
    setStep("checking");
    setCheckError(null);
    try {
      const { data } = await apiClient.get("/auth/v2/driver-status");
      const app = data?.data || null;
      if (!app || app.status === "archived") {
        setWizardMode("new");
        setStep("wizard");
      } else if (resubmit && (app.status === "needs_correction" || app.status === "rejected")) {
        setWizardMode("resubmit");
        setStep("wizard");
      } else {
        navigate("/driver/status", { replace: true });
      }
    } catch (err) {
      setCheckError(err?.response?.data?.message || "Failed to load your application status.");
    }
  }, [resubmit]);

  useEffect(() => {
    if (isAuthenticated && !submitted) checkApplication();
    if (!isAuthenticated && step !== "captcha" && step !== "login" && step !== "otp") {
      setStep(isCaptchaVerified ? "login" : "captcha");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated]);

  const preForm = PRE_STEP_LABELS[step];

  return (
    <div className="form-page">
      <div className="container container-form">
        <div className="form-page-head">
          <Link to="/driver" className="back-link">
            ← Back to Driver Information
          </Link>
          <h1>Driver Application</h1>
          <p>FindMeTricycle · Guiuan, Eastern Samar</p>
        </div>

        {preForm && !submitted ? (
          <div className="progress-head" style={{ marginBottom: 24 }}>
            <span>{preForm}</span>
          </div>
        ) : null}

        <div className="embed">
          {submitted ? (
            <Submitted application={submitted} />
          ) : step === "captcha" ? (
            <CaptchaPage onVerified={() => setStep("login")} onBack={() => navigate("/driver")} />
          ) : step === "login" ? (
            <>
              <LoginPage
                onOtpRequired={(ctx) => {
                  setOtpContext(ctx);
                  setStep("otp");
                }}
                onBack={() => setStep("captcha")}
              />
              <p className="field-hint center-text" style={{ marginTop: 16 }}>
                Don&apos;t have an account yet? <Link to="/download">Download the app</Link> and sign up
                there first — it&apos;s the same account you&apos;ll use to drive.
              </p>
            </>
          ) : step === "otp" && otpContext ? (
            <OtpPage
              email={otpContext.email}
              tempToken={otpContext.tempToken}
              user={otpContext.user}
              onVerified={() => {}}
              onBack={() => setStep("login")}
            />
          ) : step === "wizard" ? (
            <WizardShell
              user={user}
              mode={wizardMode}
              onSubmitted={(app) => setSubmitted(app || {})}
              onExit={() => {
                logout();
                navigate("/driver");
              }}
            />
          ) : (
            <div className="card center-text">
              {checkError ? (
                <>
                  <div className="banner banner-error">{checkError}</div>
                  <button type="button" className="btn btn-primary" onClick={checkApplication}>
                    Retry
                  </button>
                </>
              ) : (
                <>
                  <div className="spinner" />
                  <p className="muted" style={{ margin: "0 auto" }}>Checking your application status…</p>
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function Submitted({ application }) {
  return (
    <div className="center-block" style={{ paddingTop: 16 }}>
      <div
        style={{
          width: 80,
          height: 80,
          borderRadius: "50%",
          margin: "0 auto 24px",
          display: "grid",
          placeItems: "center",
          fontSize: "2.2rem",
          background: "var(--teal-bg)",
          border: "2px solid color-mix(in srgb, var(--teal) 40%, transparent)",
        }}
      >
        ✅
      </div>
      <h1 style={{ fontSize: "1.9rem" }}>Application Submitted!</h1>
      <p style={{ fontSize: "1.05rem", marginBottom: 4 }}>Your driver application has been received.</p>
      {application?.id ? (
        <p>
          Reference: <strong style={{ color: "var(--ink)" }}>#{application.id}</strong>
        </p>
      ) : null}
      <div className="info-box primary" style={{ maxWidth: 380, margin: "0 auto 32px", textAlign: "left" }}>
        <b style={{ display: "block", marginBottom: 8 }}>What happens next?</b>
        <ol style={{ margin: 0, paddingLeft: 18, color: "var(--ink-2)", fontSize: ".88rem" }}>
          <li>Our admin team reviews your application</li>
          <li>Your documents are verified</li>
          <li>You receive an email at each step</li>
          <li>If approved, Driver Mode activates in your app</li>
        </ol>
      </div>
      <div className="cta-row center">
        <Link to="/driver/status" className="cta cta-primary">
          Check Application Status
        </Link>
        <Link to="/" className="cta cta-outline">
          Go Home
        </Link>
      </div>
    </div>
  );
}
