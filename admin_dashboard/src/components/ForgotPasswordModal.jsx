import { useState } from "react";
import { apiClient } from "../api/client";

export default function ForgotPasswordModal({ onClose }) {
  const [step, setStep] = useState("request"); // "request" | "otp" | "password" | "done"
  const [code, setCode] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [info, setInfo] = useState(null);

  async function handleRequestCode() {
    setLoading(true);
    setError(null);
    try {
      await apiClient.post("/auth/admin/forgot-password/request", {}, { skipAuthRedirect: true });
      setInfo("A 6-digit code was sent to the registered admin email. It expires in 5 minutes.");
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
      await apiClient.post("/auth/admin/forgot-password/verify-otp", { code }, { skipAuthRedirect: true });
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
        { newPassword },
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

        {step === "request" ? (
          <div className="login-form">
            <p className="muted" style={{ fontSize: 13, marginBottom: 4 }}>
              We'll send a 6-digit code to the registered admin email to reset your password.
            </p>
            {error ? <p className="error-text">{error}</p> : null}
            <button type="button" className="btn-primary" onClick={handleRequestCode} disabled={loading}>
              {loading ? "Sending…" : "Send Reset Code"}
            </button>
          </div>
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
  );
}
