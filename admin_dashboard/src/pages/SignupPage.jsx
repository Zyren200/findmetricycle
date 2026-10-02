import AuthShell from "../components/AuthShell";
import { useState } from "react";
import { useAuth } from "../context/AuthContext";

const STEPS = {
  USERNAME: "username",
  PHONE: "phone",
  EMAIL: "email",
  OTP: "otp",
  PASSWORD: "password",
};

export default function SignupPage() {
  const { sendAdminOtp, verifyAdminOtp, registerAdmin, loading, error } = useAuth();
  const [step, setStep] = useState(STEPS.USERNAME);
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [formError, setFormError] = useState(null);

  function next(e, targetStep) {
    e.preventDefault();
    setFormError(null);
    setStep(targetStep);
  }

  async function handleEmailSubmit(e) {
    e.preventDefault();
    setFormError(null);
    const ok = await sendAdminOtp({ email });
    if (ok) setStep(STEPS.OTP);
  }

  async function handleOtpSubmit(e) {
    e.preventDefault();
    setFormError(null);
    const ok = await verifyAdminOtp({ email, code });
    if (ok) setStep(STEPS.PASSWORD);
  }

  async function handlePasswordSubmit(e) {
    e.preventDefault();
    setFormError(null);

    if (password !== confirmPassword) {
      setFormError("Passwords do not match.");
      return;
    }

    await registerAdmin({ fullName, phone, email, password });
  }

  return (
    <AuthShell>
    <main className="login-page">
      <section className="login-card">
        <div className="login-hero">
          <div className="login-hero-icon">🛺</div>
          <h1>Create account</h1>
          <p className="login-eyebrow">Set up the first FindMeTricycle admin account</p>
        </div>

        {step === STEPS.USERNAME && (
          <form onSubmit={(e) => next(e, STEPS.PHONE)} className="login-form">
            <label>
              <span className="field-label-text">Username</span>
              <input
                type="text"
                placeholder="Juan Dela Cruz"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                required
                autoFocus
              />
            </label>
            <button type="submit">Next</button>
          </form>
        )}

        {step === STEPS.PHONE && (
          <form onSubmit={(e) => next(e, STEPS.EMAIL)} className="login-form">
            <label>
              <span className="field-label-text">Phone number</span>
              <input
                type="text"
                inputMode="tel"
                placeholder="09990000000"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                required
                autoFocus
              />
            </label>
            <div className="login-row">
              <button type="button" className="login-link-btn" onClick={() => setStep(STEPS.USERNAME)}>
                Back
              </button>
            </div>
            <button type="submit">Next</button>
          </form>
        )}

        {step === STEPS.EMAIL && (
          <form onSubmit={handleEmailSubmit} className="login-form">
            <label>
              <span className="field-label-text">Email</span>
              <input
                type="email"
                placeholder="admin@findmetricycle.local"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                autoFocus
              />
            </label>
            <p className="login-footnote">We'll send a 6-digit code to this email to verify it's yours.</p>

            {error ? <p className="error-text">{error}</p> : null}

            <div className="login-row">
              <button type="button" className="login-link-btn" onClick={() => setStep(STEPS.PHONE)}>
                Back
              </button>
            </div>
            <button type="submit" disabled={loading}>
              {loading ? "Sending code…" : "Send Verification Code"}
            </button>
          </form>
        )}

        {step === STEPS.OTP && (
          <form onSubmit={handleOtpSubmit} className="login-form">
            <label>
              <span className="field-label-text">Verification code</span>
              <input
                type="text"
                inputMode="numeric"
                placeholder="6-digit code"
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
                required
                minLength={6}
                maxLength={6}
                autoFocus
              />
            </label>
            <p className="login-footnote">Sent to {email}. Valid for 5 minutes.</p>

            {error ? <p className="error-text">{error}</p> : null}

            <div className="login-row">
              <button type="button" className="login-link-btn" onClick={() => setStep(STEPS.EMAIL)}>
                Back
              </button>
              <button
                type="button"
                className="login-link-btn"
                onClick={() => sendAdminOtp({ email })}
                disabled={loading}
              >
                Resend code
              </button>
            </div>
            <button type="submit" disabled={loading}>
              {loading ? "Verifying…" : "Verify Email"}
            </button>
          </form>
        )}

        {step === STEPS.PASSWORD && (
          <form onSubmit={handlePasswordSubmit} className="login-form">
            <p className="login-footnote">Email verified. Now set your password.</p>
            <label>
              <span className="field-label-text">Password</span>
              <div className="password-row">
                <input
                  type={showPassword ? "text" : "password"}
                  placeholder="At least 8 characters"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  minLength={8}
                  autoFocus
                />
                <button
                  type="button"
                  className="password-toggle"
                  onClick={() => setShowPassword((s) => !s)}
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? (
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
                      <circle cx="12" cy="12" r="3" />
                      <line x1="3" y1="21" x2="21" y2="3" />
                    </svg>
                  ) : (
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
                      <circle cx="12" cy="12" r="3" />
                    </svg>
                  )}
                </button>
              </div>
            </label>
            <label>
              <span className="field-label-text">Confirm password</span>
              <input
                type={showPassword ? "text" : "password"}
                placeholder="Re-enter password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                minLength={8}
              />
            </label>

            {formError || error ? <p className="error-text">{formError || error}</p> : null}

            <button type="submit" disabled={loading}>
              {loading ? "Creating account…" : "Create Admin Account"}
            </button>
          </form>
        )}

        <p className="login-footnote">This is a one-time setup. Only one admin account can be created.</p>
      </section>
    </main>
    </AuthShell>
  );
}
