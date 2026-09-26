import { useCallback, useEffect, useState } from "react";
import { apiClient } from "./api/client";
import { useAuth } from "./context/AuthContext";
import LandingPage from "./pages/LandingPage";
import CaptchaPage from "./pages/CaptchaPage";
import LoginPage from "./pages/LoginPage";
import OtpPage from "./pages/OtpPage";
import StatusPage from "./pages/StatusPage";
import SuccessPage from "./pages/SuccessPage";
import WizardShell from "./pages/wizard/WizardShell";

export default function App() {
  const { isAuthenticated, isCaptchaVerified, user, logout } = useAuth();
  const [screen, setScreen] = useState("landing");
  const [otpContext, setOtpContext] = useState(null);
  const [application, setApplication] = useState(null);
  const [wizardMode, setWizardMode] = useState("new");
  const [checkError, setCheckError] = useState(null);

  const checkApplication = useCallback(async () => {
    setScreen("checking");
    setCheckError(null);
    try {
      const { data } = await apiClient.get("/auth/v2/driver-status");
      const app = data?.data || null;
      setApplication(app);
      if (!app || app.status === "archived") {
        setWizardMode("new");
        setScreen("wizard");
      } else {
        setScreen("status");
      }
    } catch (err) {
      setCheckError(err?.response?.data?.message || "Failed to load your application status.");
      setScreen("checking");
    }
  }, []);

  useEffect(() => {
    if (isAuthenticated) {
      checkApplication();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated]);

  if (isAuthenticated) {
    if (screen === "checking") {
      return (
        <div className="screen">
          <div className="shell">
            <div className="card center-text">
              {checkError ? (
                <>
                  <div className="banner banner-error">{checkError}</div>
                  <button type="button" className="btn btn-primary" onClick={checkApplication}>
                    Retry
                  </button>
                </>
              ) : (
                <p>Checking your application status…</p>
              )}
            </div>
          </div>
        </div>
      );
    }

    if (screen === "wizard") {
      return (
        <WizardShell
          user={user}
          mode={wizardMode}
          onSubmitted={() => setScreen("success")}
          onExit={() => {
            logout();
            setScreen("landing");
          }}
        />
      );
    }

    if (screen === "success") {
      return <SuccessPage onViewStatus={checkApplication} />;
    }

    return (
      <StatusPage
        application={application}
        onUpdateApplication={() => {
          setWizardMode("resubmit");
          setScreen("wizard");
        }}
        onLogout={() => {
          logout();
          setScreen("landing");
        }}
      />
    );
  }

  if (screen === "captcha") {
    return <CaptchaPage onVerified={() => setScreen("login")} onBack={() => setScreen("landing")} />;
  }

  if (screen === "login") {
    return (
      <LoginPage
        onOtpRequired={(ctx) => {
          setOtpContext(ctx);
          setScreen("otp");
        }}
        onBack={() => setScreen(isCaptchaVerified ? "captcha" : "landing")}
      />
    );
  }

  if (screen === "otp" && otpContext) {
    return (
      <OtpPage
        email={otpContext.email}
        tempToken={otpContext.tempToken}
        user={otpContext.user}
        onVerified={() => {}}
        onBack={() => setScreen("login")}
      />
    );
  }

  return <LandingPage onStart={() => setScreen(isCaptchaVerified ? "login" : "captcha")} />;
}
