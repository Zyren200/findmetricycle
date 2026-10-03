import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { SIGN_OUT_NOTICE_KEY } from "../api/client";
import ForgotPasswordModal from "../components/ForgotPasswordModal";
import AuthShell from "../components/AuthShell";

export default function LoginPage() {
  const { login, loading, error } = useAuth();
  const [identifier, setIdentifier] = useState("");
  // Why the dashboard signed this admin out (disabled, role changed), once.
  const [notice] = useState(() => sessionStorage.getItem(SIGN_OUT_NOTICE_KEY));
  useEffect(() => sessionStorage.removeItem(SIGN_OUT_NOTICE_KEY), []);
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [showPassword, setShowPassword] = useState(false);
  const [showForgotPassword, setShowForgotPassword] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    await login({ identifier, password, remember });
  }

  return (
    <AuthShell>
    <main className="login-page">
      <section className="login-card">
        <div className="login-hero">
          <div className="login-hero-icon">🛺</div>
          <h1>Sign in</h1>
          <p className="login-eyebrow">Access the FindMeTricycle admin dashboard</p>
        </div>

        <form onSubmit={handleSubmit} className="login-form">
          {notice ? <p className="error-banner" role="status">{notice}</p> : null}
          <label>
            <span className="field-label-text">Admin number or email</span>
            <input
              type="text"
              inputMode="email"
              placeholder="09990000000 or admin@findmetricycle.local"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              required
              autoFocus
            />
          </label>
          <label>
            <span className="field-label-text">Password</span>
            <div className="password-row">
              <input
                type={showPassword ? "text" : "password"}
                placeholder="Enter password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
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
          </label>

          <div className="login-row">
            <label className="remember-row">
              <input type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} />
              <span>Remember me</span>
            </label>
            <button type="button" className="login-link-btn" onClick={() => setShowForgotPassword(true)}>
              Forgot password?
            </button>
          </div>

          {error ? <p className="error-text">{error}</p> : null}

          <button type="submit" disabled={loading}>
            {loading ? "Signing in…" : "Sign In"}
          </button>
        </form>

        <p className="login-footnote">Need access? Contact your system administrator.</p>
      </section>

      {showForgotPassword ? (
        <ForgotPasswordModal
          initialEmail={identifier.includes("@") ? identifier.trim() : ""}
          onClose={() => setShowForgotPassword(false)}
        />
      ) : null}
    </main>
    </AuthShell>
  );
}
