import { useEffect, useRef, useState } from "react";
import { apiClient } from "../api/client";
import { useAuth } from "../context/AuthContext";

const SITE_KEY = import.meta.env.VITE_RECAPTCHA_SITE_KEY || "";

export default function CaptchaPage({ onVerified, onBack }) {
  const { setCaptchaSessionToken } = useAuth();
  const widgetRef = useRef(null);
  const widgetIdRef = useRef(null);
  const [error, setError] = useState(null);
  const [verifying, setVerifying] = useState(false);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    let attempts = 0;

    function tryRender() {
      if (cancelled) return;
      if (window.grecaptcha && window.grecaptcha.render && widgetRef.current && widgetIdRef.current === null) {
        widgetIdRef.current = window.grecaptcha.render(widgetRef.current, {
          sitekey: SITE_KEY,
          callback: handleToken,
          "expired-callback": () => setError("CAPTCHA expired — please verify again."),
        });
        setReady(true);
        return;
      }
      attempts += 1;
      if (attempts < 100) {
        setTimeout(tryRender, 200);
      } else {
        setError("Could not load the CAPTCHA widget. Please refresh the page.");
      }
    }

    tryRender();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleToken(token) {
    setVerifying(true);
    setError(null);
    try {
      const { data } = await apiClient.post("/auth/v2/verify-captcha", { token });
      if (data?.success) {
        setCaptchaSessionToken(data.captchaSessionToken);
        onVerified();
      } else {
        throw new Error(data?.message || "CAPTCHA verification failed.");
      }
    } catch (err) {
      setError(err?.response?.data?.message || err.message || "CAPTCHA verification failed.");
      if (window.grecaptcha && widgetIdRef.current !== null) {
        window.grecaptcha.reset(widgetIdRef.current);
      }
    } finally {
      setVerifying(false);
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
          <h2>Quick human check</h2>
          <p>Please confirm you're not a robot before continuing your driver application.</p>

          {error ? <div className="banner banner-error">{error}</div> : null}
          {!SITE_KEY ? (
            <div className="banner banner-warning">
              CAPTCHA is not configured (missing VITE_RECAPTCHA_SITE_KEY).
            </div>
          ) : null}

          <div style={{ display: "flex", justifyContent: "center", margin: "16px 0" }}>
            <div ref={widgetRef} />
          </div>

          {!ready && SITE_KEY ? <p className="center-text">Loading CAPTCHA…</p> : null}
          {verifying ? <p className="center-text">Verifying…</p> : null}

          <button type="button" className="btn btn-ghost" onClick={onBack} style={{ width: "100%" }}>
            Back
          </button>
        </div>
      </div>
    </div>
  );
}
