import { useEffect, useRef, useState } from "react";
import { apiClient } from "../api/client";
import { useAuth } from "../context/AuthContext";

const RESEND_COOLDOWN_SECONDS = 60;

export default function OtpPage({ email, tempToken, user, onVerified, onBack }) {
  const { login, captchaSessionToken } = useAuth();
  const [digits, setDigits] = useState(["", "", "", "", "", ""]);
  const [error, setError] = useState(null);
  const [verifying, setVerifying] = useState(false);
  const [resending, setResending] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const inputRefs = useRef([]);

  useEffect(() => {
    if (cooldown <= 0) return;
    const timer = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(timer);
  }, [cooldown]);

  useEffect(() => {
    setCooldown(RESEND_COOLDOWN_SECONDS);
  }, []);

  function handleDigitChange(index, value) {
    const clean = value.replace(/\D/g, "").slice(-1);
    const next = [...digits];
    next[index] = clean;
    setDigits(next);
    if (clean && index < 5) {
      inputRefs.current[index + 1]?.focus();
    }
  }

  function handleKeyDown(index, e) {
    if (e.key === "Backspace" && !digits[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  }

  async function handleVerify(e) {
    e?.preventDefault();
    const code = digits.join("");
    if (code.length !== 6) {
      setError("Enter the full 6-digit code.");
      return;
    }

    setVerifying(true);
    setError(null);
    try {
      const { data } = await apiClient.post("/auth/v2/verify-otp", {
        email,
        code,
        purpose: "driver_application",
      });
      if (!data?.success) {
        throw new Error(data?.message || "Invalid or expired code.");
      }
      login(tempToken, user);
      onVerified();
    } catch (err) {
      setError(err?.response?.data?.message || err.message || "Invalid or expired code.");
    } finally {
      setVerifying(false);
    }
  }

  async function handleResend() {
    setResending(true);
    setError(null);
    try {
      await apiClient.post(
        "/auth/v2/send-otp",
        { email, purpose: "driver_application" },
        { headers: { "X-Captcha-Token": captchaSessionToken } }
      );
      setCooldown(RESEND_COOLDOWN_SECONDS);
      setDigits(["", "", "", "", "", ""]);
      inputRefs.current[0]?.focus();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to resend code.");
    } finally {
      setResending(false);
    }
  }

  return (
    <div className="screen">
      <div className="shell">
        <div className="brand">
          <span className="brand-emoji">🛺</span>
          <span className="brand-title">FindMeTricycle</span>
        </div>

        <div className="card">
          <h2>Verification Code</h2>
          <p>
            We sent a verification code to your registered email (<strong>{email}</strong>). Code expires in
            5 minutes.
          </p>

          {error ? <div className="banner banner-error">{error}</div> : null}

          <form onSubmit={handleVerify}>
            <div className="otp-inputs">
              {digits.map((d, i) => (
                <input
                  key={i}
                  ref={(el) => (inputRefs.current[i] = el)}
                  type="text"
                  inputMode="numeric"
                  maxLength={1}
                  value={d}
                  onChange={(e) => handleDigitChange(i, e.target.value)}
                  onKeyDown={(e) => handleKeyDown(i, e)}
                />
              ))}
            </div>

            <button type="submit" className="btn btn-primary" disabled={verifying} style={{ marginBottom: 12 }}>
              {verifying ? "Verifying…" : "Verify"}
            </button>
          </form>

          <div className="center-text" style={{ marginBottom: 12 }}>
            <button
              type="button"
              className="link-btn"
              disabled={cooldown > 0 || resending}
              onClick={handleResend}
            >
              {cooldown > 0 ? `Resend Code (${cooldown}s)` : resending ? "Resending…" : "Resend Code"}
            </button>
          </div>

          <button type="button" className="btn btn-ghost" onClick={onBack} style={{ width: "100%" }}>
            Back
          </button>
        </div>
      </div>
    </div>
  );
}
