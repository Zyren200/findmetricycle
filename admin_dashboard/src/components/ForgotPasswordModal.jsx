import { useState } from "react";
import { apiClient } from "../api/client";

// Each admin resets their own password: the code goes to the email of the
// admin account typed in here.
export default function ForgotPasswordModal({ onClose, initialEmail = "" }) {
  const [step, setStep] = useState("request"); // "request" | "otp" | "password" | "done"
  const [email, setEmail] = useState(initialEmail);
  const [code, setCode] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [info, setInfo] = useState(null);

  async function handleRequestCode(e) {
    e?.preventDefault();
    setError(null);

    const trimmedEmail = email.trim();
    if (!trimmedEmail) {
      setError("Enter the email of your admin account.");
      return;
    }

    setLoading(true);
    try {
      await apiClient.post(
        "/auth/admin/forgot-password/request",
        { email: trimmedEmail },
        { skipAuthRedirect: true }
      );
      setInfo(`A 6-digit code was sent to ${trimmedEmail}. It expires in 5 minutes.`);
      setStep("otp");
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to send reset code. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  async function handleVerifyOtp(e) {
    e.preventDefault();
    setError(null);

    if (code.length !== 6) {
      setError("Enter the 6-digit code.");
      return;
    }

    setLoading(true);
    try {
      await apiClient.post(
        "/auth/admin/forgot-password/verify-otp",
        { email: email.trim(), code },
        { skipAuthRedirect: true }
      );
      setInfo(null);
      setStep("password");
    } catch (err) {
      setError(err?.response?.data?.message || "Invalid or expired code.");
    } finally {
      setLoading(false);
    }
  }

  async function handleResetPassword(e) {
    e.preventDefault();
    setError(null);

    if (newPassword.length < 8) {
      setError("New password must be at least 8 characters.");
      return;
    }
    if (newPassword !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);
    try {
      await apiClient.post(
        "/auth/admin/forgot-password/reset",
        { email: email.trim(), code, newPassword },
        { skipAuthRedirect: true }
      );
      setStep("done");
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to reset password.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="modal-overlay open">
      <div className="modal" style={{ maxWidth: 400 }}>
        <div className="modal-header">
          <div className="modal-title">Reset Password</div>
          <button className="modal-close" type="button" onClick={onClose}>
            ×
          </button>
        </div>

        <div className="modal-body">
        {step === "request" ? (
          <form onSubmit={handleRequestCode} className="login-form">
            <p className="muted" style={{ fontSize: 13, marginBottom: 4 }}>
              Enter the email of your admin account. We'll send a 6-digit code there to reset your password.
            </p>
            <label>
              <span className="field-label-text">Admin email</span>
              <input
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                autoFocus
                autoComplete="email"
              />
            </label>
            {error ? <p className="error-text">{error}</p> : null}
            <button type="submit" className="btn-primary" disabled={loading}>
              {loading ? "Sending…" : "Send Reset Code"}
            </button>
          </form>
        ) : null}

        {step === "otp" ? (
          <form onSubmit={handleVerifyOtp} className="login-form">
            {info ? <p className="success-banner" style={{ fontSize: 13 }}>{info}</p> : null}
            <label>
              <span className="field-label-text">6-digit code</span>
              <input
                type="text"
                inputMode="numeric"
                pattern="\d{6}"
                maxLength={6}
                placeholder="123456"
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
                required
                autoFocus
              />
            </label>
            {error ? <p className="error-text">{error}</p> : null}
            <button type="submit" disabled={loading || code.length !== 6}>
              {loading ? "Verifying…" : "Verify Code"}
            </button>
            <button
              type="button"
              className="login-link-btn"
              style={{ justifySelf: "center" }}
              onClick={() => {
                setStep("request");
                setCode("");
                setError(null);
              }}
            >
              Didn't get a code? Try again
            </button>
          </form>
        ) : null}

        {step === "password" ? (
          <form onSubmit={handleResetPassword} className="login-form">
            <p className="success-banner" style={{ fontSize: 13 }}>Email verified. Set your new password.</p>
            <label>
              <span className="field-label-text">New password</span>
              <input
                type="password"
                placeholder="At least 8 characters"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
                minLength={8}
                autoFocus
              />
            </label>
            <label>
              <span className="field-label-text">Confirm new password</span>
              <input
                type="password"
                placeholder="Re-enter new password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                minLength={8}
              />
            </label>
            {error ? <p className="error-text">{error}</p> : null}
            <button type="submit" disabled={loading}>
              {loading ? "Resetting…" : "Reset Password"}
            </button>
          </form>
        ) : null}

        {step === "done" ? (
          <div className="login-form">
            <p className="success-banner">Your password has been reset. You can now sign in with your new password.</p>
            <button type="button" className="btn-primary" onClick={onClose}>
              Back to Sign In
            </button>
          </div>
        ) : null}
        </div>
      </div>
    </div>
  );
}
