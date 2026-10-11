import { useEffect, useRef, useState } from "react";
import { apiClient } from "../api/client";
import { ICON } from "../components/Icons";
import { Alert, OtpInputs, useToast } from "../components/ui";
import { useAuth } from "../context/AuthContext";
import { Link } from "../router";

const SITE_KEY = import.meta.env.VITE_RECAPTCHA_SITE_KEY || "";
const CODE_MINUTES = 5;
const RESEND_SECONDS = 60;

const maskEmail = (e) => String(e || "").replace(/^(.)(.*)(@.*)$/, (m, a, b, c) => a + "•".repeat(Math.max(2, b.length)) + c);
const errorText = (err, fallback) => err?.response?.data?.message || err?.message || fallback;

function themeNow() {
  const set = document.documentElement.dataset.theme;
  if (set === "dark" || set === "light") return set;
  return matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

/** Google reCAPTCHA in the design's captcha box; reports a verified session token. */
function Captcha({ verified, onVerified, onError }) {
  const boxRef = useRef(null);
  const widgetId = useRef(null);
  const [state, setState] = useState(verified ? "ok" : "loading"); // loading | ready | busy | ok
  const { setCaptchaSessionToken } = useAuth();

  useEffect(() => {
    if (verified) {
      setState("ok");
      return undefined;
    }
    if (!SITE_KEY) return undefined;
    let cancelled = false;
    let attempts = 0;
    widgetId.current = null;
    setState("loading");

    async function handleToken(token) {
      setState("busy");
      try {
        const { data } = await apiClient.post("/auth/v2/verify-captcha", { token });
        if (!data?.success) throw new Error(data?.message || "CAPTCHA verification failed.");
        setCaptchaSessionToken(data.captchaSessionToken);
        setState("ok");
        onVerified();
      } catch (err) {
        onError(errorText(err, "CAPTCHA verification failed. Please try again."));
        setState("ready");
        if (window.grecaptcha && widgetId.current !== null) window.grecaptcha.reset(widgetId.current);
      }
    }

    function tryRender() {
      if (cancelled) return;
      if (window.grecaptcha?.render && boxRef.current && widgetId.current === null) {
        // A fresh element every time: reCAPTCHA refuses to render twice into
        // the same one (React runs this effect twice in development), and an
        // uncaught throw here blanked the whole page.
        const slot = document.createElement("div");
        boxRef.current.replaceChildren(slot);
        try {
          widgetId.current = window.grecaptcha.render(slot, {
            sitekey: SITE_KEY,
            theme: themeNow(),
            callback: handleToken,
            "expired-callback": () => onError("The CAPTCHA expired. Tick it again."),
          });
          setState("ready");
        } catch {
          onError("Could not load the CAPTCHA. Refresh the page and try again.");
        }
        return;
      }
      attempts += 1;
      if (attempts < 100) setTimeout(tryRender, 200);
      else onError("Could not load the CAPTCHA. Refresh the page and try again.");
    }
    tryRender();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [verified]);

  if (!SITE_KEY) {
    return <Alert tone="warn">CAPTCHA is not configured on this site (missing VITE_RECAPTCHA_SITE_KEY).</Alert>;
  }
  if (state === "ok") {
    return (
      <div key="ok" className="captcha ok" role="status">
        <div className="row" style={{ gap: 12 }}>
          <span className="box" />
          <b style={{ fontSize: 15 }}>I&apos;m not a robot</b>
        </div>
        <small>
          reCAPTCHA
          <br />
          verified
        </small>
      </div>
    );
  }
  return (
    <div key="widget" className={`captcha recaptcha ${state === "busy" ? "busy" : ""}`}>
      <div ref={boxRef} />
      {state === "loading" ? <small style={{ textAlign: "left" }}>Loading the CAPTCHA…</small> : null}
      {state === "busy" ? <small>Checking…</small> : null}
    </div>
  );
}

/**
 * Sign-in gate for the driver application, in two steps:
 * 1. passenger account + CAPTCHA, 2. the 6-digit code sent to the account's email.
 */
export default function GatePage() {
  const { login, captchaSessionToken, isCaptchaVerified, setCaptchaSessionToken } = useAuth();
  const toast = useToast();
  const [step, setStep] = useState(1);
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState(null); // { email, tempToken, user }

  async function sendCode(email) {
    await apiClient.post(
      "/auth/v2/send-otp",
      { email, purpose: "driver_application" },
      { headers: { "X-Captcha-Token": captchaSessionToken } }
    );
  }

  async function handleSignIn(e) {
    e.preventDefault();
    if (!identifier.trim() || !password) {
      setError("Enter your email or mobile number and your password.");
      return;
    }
    if (!isCaptchaVerified) {
      setError('Tick "I\'m not a robot" first.');
      return;
    }
    setBusy(true);
    setError("");
    try {
      const isEmail = identifier.includes("@");
      const { data } = await apiClient.post("/auth/login", {
        [isEmail ? "email" : "phone"]: identifier.trim(),
        password,
      });
      if (!data?.success) throw new Error(data?.message || "Sign-in failed.");
      const user = data.data?.user;
      const tempToken = data.data?.token || data.data?.accessToken;
      if (user?.role !== "passenger") {
        throw new Error("This is not a passenger account. Sign in with the passenger account you use in the app.");
      }
      if (!user?.email) {
        throw new Error("Your account has no email address yet. Add an email in the app under Profile, then try again.");
      }
      try {
        await sendCode(user.email);
      } catch (err) {
        // The CAPTCHA session ran out: ask for the tick again.
        if (err?.response?.status === 403) setCaptchaSessionToken("");
        throw err;
      }
      setPending({ email: user.email, tempToken, user, sentAt: Date.now() });
      setStep(2);
    } catch (err) {
      setError(errorText(err, "Sign-in failed."));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section>
      <div className="wrap">
        <div className="form-card glass">
          <div className="gate-steps" aria-hidden="true">
            <span className="on" />
            <span className={step === 2 ? "on" : ""} />
          </div>
          {step === 1 ? (
            <div key="signin">
              <span className="eyebrow">Step 1 of 2 · Sign in</span>
              <h2 style={{ marginTop: 10 }}>Sign in with your passenger account</h2>
              <p className="muted" style={{ marginTop: 8 }}>
                Use the same email or mobile number and password you use in the FindMeTricycle app.
              </p>
              <form className="stack" style={{ marginTop: 22 }} onSubmit={handleSignIn} noValidate>
                <div className="fld">
                  <label htmlFor="sId">Email or mobile number</label>
                  <input
                    id="sId"
                    autoComplete="username"
                    placeholder="juan@example.com or 09171234567"
                    value={identifier}
                    onChange={(e) => setIdentifier(e.target.value)}
                  />
                </div>
                <div className="fld">
                  <label htmlFor="sPw">Password</label>
                  <div className="pw">
                    <input
                      id="sPw"
                      type={showPassword ? "text" : "password"}
                      autoComplete="current-password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                    />
                    <button
                      type="button"
                      className="pw-toggle"
                      onClick={() => setShowPassword((s) => !s)}
                      aria-label={showPassword ? "Hide password" : "Show password"}
                    >
                      {showPassword ? ICON.eye : ICON.eyeOff}
                    </button>
                  </div>
                </div>
                <Captcha verified={isCaptchaVerified} onVerified={() => setError("")} onError={setError} />
                {error ? <Alert tone="err">{error}</Alert> : null}
                <button className="btn btn-hot btn-block" type="submit" disabled={busy}>
                  {busy ? "Signing in…" : "Continue"} {ICON.arrow}
                </button>
                <p className="muted" style={{ fontSize: 14, textAlign: "center" }}>
                  No account yet? <Link to="/download">Download the app</Link> and sign up as a passenger first.
                </p>
              </form>
            </div>
          ) : (
            <CodeStep
              key="code"
              pending={pending}
              onResend={async () => {
                await sendCode(pending.email);
                setPending((p) => ({ ...p, sentAt: Date.now() }));
              }}
              onBack={() => {
                setPending(null);
                setPassword("");
                setError("");
                setStep(1);
              }}
              onVerified={() => {
                login(pending.tempToken, pending.user);
                toast("Signed in", `Welcome, ${String(pending.user?.full_name || pending.user?.fullName || "").split(" ")[0]}.`);
              }}
            />
          )}
        </div>
      </div>
    </section>
  );
}

function CodeStep({ pending, onResend, onBack, onVerified }) {
  const [digits, setDigits] = useState(["", "", "", "", "", ""]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  const resendIn = Math.ceil((pending.sentAt + RESEND_SECONDS * 1000 - now) / 1000);
  const expiresIn = Math.max(0, pending.sentAt + CODE_MINUTES * 60000 - now);

  async function verify(code) {
    if (code.length !== 6) {
      setError("Enter all 6 digits.");
      return;
    }
    if (expiresIn <= 0) {
      setError("This code has expired. Tap Resend code to get a new one.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      const { data } = await apiClient.post("/auth/v2/verify-otp", {
        email: pending.email,
        code,
        purpose: "driver_application",
      });
      if (!data?.success) throw new Error(data?.message || "That code is not correct.");
      onVerified();
    } catch (err) {
      setDigits(["", "", "", "", "", ""]);
      setError(errorText(err, "That code is not correct. Check the latest email and try again."));
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    setError("");
    setDigits(["", "", "", "", "", ""]);
    try {
      await onResend();
    } catch (err) {
      setError(errorText(err, "Couldn't send a new code."));
    }
  }

  return (
    <div>
      <span className="eyebrow">Step 2 of 2 · Confirm your email</span>
      <h2 style={{ marginTop: 10 }}>Enter the 6-digit code</h2>
      <p className="muted" style={{ marginTop: 8 }}>
        We sent it to <b style={{ color: "var(--fg)" }}>{maskEmail(pending.email)}</b>. It works for {CODE_MINUTES} minutes.
      </p>
      <form
        className="stack"
        style={{ marginTop: 22 }}
        noValidate
        onSubmit={(e) => {
          e.preventDefault();
          verify(digits.join(""));
        }}
      >
        <OtpInputs digits={digits} setDigits={setDigits} onComplete={(code) => !busy && verify(code)} />
        <div className="row muted" style={{ justifyContent: "space-between", fontSize: 13 }}>
          <span>
            {expiresIn > 0
              ? `Code expires in ${Math.floor(expiresIn / 60000)}:${String(Math.floor(expiresIn / 1000) % 60).padStart(2, "0")}`
              : "Code expired"}
          </span>
          <button className="btn btn-ghost btn-sm" type="button" disabled={resendIn > 0} onClick={resend}>
            {resendIn > 0 ? `Resend code in ${resendIn}s` : "Resend code"}
          </button>
        </div>
        {error ? <Alert tone="err">{error}</Alert> : null}
        <button className="btn btn-hot btn-block" type="submit" disabled={busy}>
          {busy ? "Verifying…" : "Verify and continue"}
        </button>
        <button className="btn btn-ghost" type="button" onClick={onBack}>
          Use a different account
        </button>
      </form>
    </div>
  );
}
