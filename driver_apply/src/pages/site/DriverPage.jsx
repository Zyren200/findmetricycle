import { ICON } from "../../components/Icons";
import { Card, Head, Shot } from "../../components/ui";
import { useAuth } from "../../context/AuthContext";
import { Link, useDocumentTitle } from "../../router";

/** "Start Application", or "View My Application" for a signed-in applicant. */
export function DriverCta() {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? (
    <Link className="btn btn-hot" to="/driver/status">
      View My Application {ICON.arrow}
    </Link>
  ) : (
    <Link className="btn btn-hot" to="/driver/apply">
      Start Application {ICON.arrow}
    </Link>
  );
}

export default function DriverPage() {
  useDocumentTitle("FindMeTricycle · Become a Driver");

  return (
    <>
      <section>
        <div className="wrap">
          <Head
            eyebrow="Become a driver"
            title="Drive with FindMeTricycle in Guiuan."
            sub="Apply with the passenger account you already use in the app. There is no separate driver account."
          />
          <div className="row" style={{ marginBottom: 40 }}>
            <DriverCta />
            <Link className="btn btn-glass" to="/download">
              No account yet? Get the app
            </Link>
          </div>
          <div className="grid g3">
            <Card icon="pin" tone="o" title="More passengers">
              Get ride requests from nearby passengers instead of waiting at the terminal.
            </Card>
            <Card icon="cash" tone="t" title="Keep your cash fares">
              Passengers pay you directly in cash.
            </Card>
            <Card icon="shield" tone="v" title="Trusted platform">
              Every driver and passenger is verified, so riders feel safe booking.
            </Card>
          </div>
        </div>
      </section>

      <section>
        <div className="wrap">
          <Head
            eyebrow="Driver Mode"
            title="What you will use on every ride."
            sub="Once approved, switch to Driver Mode in the same app. No second app to install."
            as="h2"
          />
          <div className="shots-row three">
            <Shot id="d-request" title="Ride requests" sub="Fare, pickup and drop-off. Accept within 20 seconds." />
            <Shot id="d-pin" title="PIN check" sub="Type the passenger's PIN to start the trip." />
            <Shot id="d-earn" title="Earnings" sub="Today, this week and this month at a glance." />
          </div>
        </div>
      </section>

      <section>
        <div className="wrap">
          <div className="grid g2">
            <div className="card glass">
              <span className="eyebrow">Prepare these first</span>
              <h3 style={{ fontSize: 24 }}>Requirements</h3>
              <ul className="list" style={{ marginTop: 12 }}>
                <li>Passenger account with an email address</li>
                <li>Driver&apos;s license (clear photo, in your own name)</li>
                <li>Franchise or business permit (clear photo)</li>
                <li>Tricycle plate number and franchise number</li>
                <li>Home address and an emergency contact</li>
                <li>A phone or laptop with a camera for the face check</li>
              </ul>
            </div>
            <div className="card glass">
              <span className="eyebrow">How the application works</span>
              <h3 style={{ fontSize: 24 }}>From sign-in to Driver Mode</h3>
              <ol className="list" style={{ marginTop: 12 }}>
                <li>Sign in with your passenger account and confirm the code sent to your email.</li>
                <li>Fill in 5 short steps: personal info, driver info, documents, face check, review.</li>
                <li>Submit. You get a reference number right away.</li>
                <li>The admin team reviews it and emails you the result.</li>
                <li>Once approved, tap Switch to Driver Mode in the app&apos;s Profile.</li>
              </ol>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
