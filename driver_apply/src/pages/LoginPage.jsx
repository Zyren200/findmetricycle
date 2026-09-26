import { useState } from "react";
import { apiClient } from "../api/client";
import { useAuth } from "../context/AuthContext";

export default function LoginPage({ onOtpRequired, onBack }) {
  const { captchaSessionToken } = useAuth();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!identifier.trim() || !password) {
      setError("Please fill in both fields.");
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const isEmail = identifier.includes("@");
      const { data: loginResult } = await apiClient.post("/auth/login", {
        [isEmail ? "email" : "phone"]: identifier.trim(),
        password,
      });

      if (!loginResult?.success) {
        throw new Error(loginResult?.message || "Login failed.");
      }

      const user = loginResult.data?.user;
      const tempToken = loginResult.data?.token || loginResult.data?.accessToken;
      const email = user?.email;

      if (user?.role !== "passenger") {
        throw new Error(
          "Only passenger accounts can apply to become a driver. Please sign in with your passenger account."
        );
      }

      if (!email) {
        throw new Error(
          "Your account has no registered email — an email is required for driver application verification."
        );
      }

      await apiClient.post(
        "/auth/v2/send-otp",
        { email, purpose: "driver_application" },
        { headers: { "X-Captcha-Token": captchaSessionToken } }
      );

      onOtpRequired({ email, tempToken, user });
    } catch (err) {
      setError(err?.response?.data?.message || err.message || "Login failed.");
    } finally {
      setLoading(false);
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
          <h2>Sign in to continue</h2>
          <p>Use your existing FindMeTricycle passenger account. No separate driver account is created.</p>

          {error ? <div className="banner banner-error">{error}</div> : null}

          <form onSubmit={handleSubmit}>
            <div className="field">
              <label htmlFor="identifier">Email or Mobile Number</label>
              <input
                id="identifier"
                type="text"
                value={identifier}
                onChange={(e) => setIdentifier(e.target.value)}
                placeholder="name@example.com or 09XX XXX XXXX"
                autoComplete="username"
              />
            </div>
            <div className="field">
              <label htmlFor="password">Password</label>
              <div className="pw">
                <input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter password"
                  autoComplete="current-password"
                />
                <button
                  type="button"
                  className="pw-toggle"
                  onClick={() => setShowPassword((s) => !s)}
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? (
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
                      <circle cx="12" cy="12" r="3" />
                    </svg>
                  ) : (
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
                      <circle cx="12" cy="12" r="3" />
                      <line x1="3" y1="21" x2="21" y2="3" />
                    </svg>
                  )}
                </button>
              </div>
            </div>

            <button type="submit" className="btn btn-primary" disabled={loading} style={{ marginBottom: 10 }}>
              {loading ? "Signing in…" : "Continue"}
            </button>
            <button type="button" className="btn btn-ghost" onClick={onBack} style={{ width: "100%" }}>
              Back
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
