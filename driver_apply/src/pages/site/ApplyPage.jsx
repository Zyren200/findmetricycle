import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../../api/client";
import { ICON } from "../../components/Icons";
import { Alert, useToast } from "../../components/ui";
import { useAuth } from "../../context/AuthContext";
import { Link, navigate, useDocumentTitle } from "../../router";
import GatePage from "../GatePage";
import WizardShell from "../wizard/WizardShell";

/// Driver application: sign in (account + CAPTCHA, then the email code) →
/// the application wizard. A signed-in rider who already has an application
/// is sent to the status page instead, unless they're updating it.
export default function ApplyPage() {
  useDocumentTitle("FindMeTricycle · Apply");
  const { isAuthenticated, user, logout } = useAuth();
  const toast = useToast();
  const params = new URLSearchParams(window.location.search);
  const resubmit = params.get("resubmit") === "1";
  const returnToStatus = params.get("return") === "status";

  const [phase, setPhase] = useState("checking"); // checking | wizard | error
  const [wizardMode, setWizardMode] = useState("new");
  // The application being corrected, so the wizard starts from its answers.
  const [previousApp, setPreviousApp] = useState(null);
  const [checkError, setCheckError] = useState(null);
  const [submitted, setSubmitted] = useState(null);

  const checkApplication = useCallback(async () => {
    if (returnToStatus) {
      navigate("/driver/status", { replace: true });
      return;
    }
    setPhase("checking");
    setCheckError(null);
    try {
      const { data } = await apiClient.get("/auth/v2/driver-status");
      const app = data?.data || null;
      if (!app || app.status === "archived") {
        setWizardMode("new");
        setPhase("wizard");
      } else if (resubmit && (app.status === "needs_correction" || app.status === "rejected")) {
        setWizardMode("resubmit");
        setPreviousApp(app);
        setPhase("wizard");
      } else {
        navigate("/driver/status", { replace: true });
      }
    } catch (err) {
      setCheckError(err?.response?.data?.message || "Failed to load your application status.");
      setPhase("error");
    }
  }, [resubmit, returnToStatus]);

  useEffect(() => {
    if (isAuthenticated && !submitted) checkApplication();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated]);

  if (submitted) return <Submitted application={submitted.app} manualReview={submitted.manualReview} />;
  if (!isAuthenticated) return <GatePage />;

  if (phase === "wizard") {
    return (
      <WizardShell
        user={user}
        mode={wizardMode}
        previous={previousApp}
        onSubmitted={(app, { manualReview }) => {
          setSubmitted({ app, manualReview });
          toast("Application received", app?.id ? `Reference #${app.id}. We emailed you a copy.` : "We emailed you a copy.");
          window.scrollTo({ top: 0 });
        }}
        onExit={() => {
          logout();
          toast("Signed out", "You can start again any time by signing in.");
          navigate("/driver");
        }}
      />
    );
  }

  return (
    <section>
      <div className="wrap">
        <div className="form-card glass" style={{ textAlign: "center" }}>
          {phase === "error" ? (
            <div className="stack">
              <Alert tone="err">{checkError}</Alert>
              <button type="button" className="btn btn-hot" onClick={checkApplication}>
                Retry
              </button>
            </div>
          ) : (
            <>
              <div className="spinner" aria-hidden="true" />
              <p className="muted" style={{ marginTop: 14 }}>
                Checking your application status…
              </p>
            </>
          )}
        </div>
      </div>
    </section>
  );
}

function Submitted({ application, manualReview }) {
  return (
    <section>
      <div className="wrap">
        <div className="form-card glass" style={{ maxWidth: 620, textAlign: "center" }}>
          <span
            className="status-ic"
            style={{ margin: "0 auto", background: "linear-gradient(135deg,#34E3A5,#0E9E6E)", width: 72, height: 72, display: "grid", placeItems: "center", color: "#fff" }}
          >
            {ICON.check}
          </span>
          <h2 style={{ marginTop: 18, fontSize: 32 }}>Application Submitted!</h2>
          <p className="muted" style={{ marginTop: 10 }}>
            Keep your reference number. We also sent it to your email.
          </p>
          {application?.id ? (
            <div className="copy" style={{ justifyContent: "center", marginTop: 16, fontSize: 20, fontWeight: 700 }}>
              #{application.id}
            </div>
          ) : null}
          <div style={{ textAlign: "left", marginTop: 24 }}>
            <b>What happens next</b>
            <ol className="list" style={{ marginTop: 10 }}>
              <li>The admin team reviews your documents and face check.</li>
              <li>You get an email when it is approved, or if something needs fixing.</li>
              <li>Once approved, open the app → Profile → Switch to Driver Mode.</li>
            </ol>
          </div>
          {manualReview ? (
            <Alert tone="warn" title="Some items need a manual check" style={{ marginTop: 18, textAlign: "left" }}>
              This can make the review take a little longer.
            </Alert>
          ) : null}
          <div className="row" style={{ justifyContent: "center", marginTop: 24 }}>
            <Link className="btn btn-hot" to="/driver/status">
              View Application Status {ICON.arrow}
            </Link>
            <Link className="btn btn-glass" to="/">
              Back to Home
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
