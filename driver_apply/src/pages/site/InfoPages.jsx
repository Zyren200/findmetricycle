import { config } from "../../config";
import { ICON } from "../../components/Icons";
import { Alert, Card, Head, StepCard } from "../../components/ui";
import { Link, useDocumentTitle } from "../../router";

export function HowItWorksPage() {
  useDocumentTitle("FindMeTricycle · How It Works");
  return (
    <section>
      <div className="wrap">
        <Head
          eyebrow="How it works"
          title="Booking a tricycle, made simple."
          sub="Passengers book in the app. Drivers accept rides in Driver Mode. Every fare is paid in cash."
        />
        <h3 style={{ fontSize: 22, marginBottom: 16 }}>For passengers</h3>
        <div className="grid g4">
          <StepCard n={1} title="Open the app">
            Sign in with your passenger account.
          </StepCard>
          <StepCard n={2} title="Set pickup and destination">
            The fare is shown before you book.
          </StepCard>
          <StepCard n={3} title="Get matched">
            Choose a nearby verified driver and send your request.
          </StepCard>
          <StepCard n={4} title="Ride and pay cash">
            Pay the driver the shown fare when you arrive.
          </StepCard>
        </div>
        <h3 style={{ fontSize: 22, margin: "40px 0 16px" }}>For drivers</h3>
        <div className="grid g4">
          <StepCard n={1} title="Apply on this website">
            Use your passenger account and upload your documents.
          </StepCard>
          <StepCard n={2} title="Get approved">
            The admin team reviews your application and emails you.
          </StepCard>
          <StepCard n={3} title="Switch to Driver Mode">
            Open Profile in the app and tap Switch to Driver Mode.
          </StepCard>
          <StepCard n={4} title="Accept rides">
            Pick up passengers nearby and collect cash fares.
          </StepCard>
        </div>
        <Alert tone="info" title="Cash payment only" style={{ marginTop: 32 }}>
          There are no card or e-wallet payments. Passengers pay the driver directly.
        </Alert>
      </div>
    </section>
  );
}

export function SafetyPage() {
  useDocumentTitle("FindMeTricycle · Safety");
  return (
    <section>
      <div className="wrap">
        <Head
          eyebrow="Safety"
          title="Safety first, for riders and drivers."
          sub="Every driver is verified before they can accept rides."
        />
        <div className="grid g2">
          <div className="card glass">
            <span className="ic t">{ICON.user}</span>
            <h3>Passenger safety</h3>
            <ul className="list" style={{ marginTop: 10 }}>
              <li>See the driver&apos;s name, tricycle number and rating before the ride</li>
              <li>Track the trip live on the map</li>
              <li>A 4-digit PIN makes sure you board the right tricycle</li>
              <li>SOS alerts the admin with your location and opens the dialer with 911</li>
              <li>Report a problem to the admin anytime</li>
            </ul>
          </div>
          <div className="card glass">
            <span className="ic o">{ICON.trike}</span>
            <h3>Driver safety</h3>
            <ul className="list" style={{ marginTop: 10 }}>
              <li>Passengers sign up with a verified email and mobile number</li>
              <li>See pickup and drop-off before you accept</li>
              <li>SOS is available during every ride</li>
              <li>Report a passenger to the admin</li>
              <li>Cash fares shown upfront to avoid disputes</li>
            </ul>
          </div>
        </div>
        <div className="card glass" style={{ marginTop: 16 }}>
          <span className="ic v">{ICON.shield}</span>
          <h3>All drivers are verified</h3>
          <p>
            Each application is checked by the admin team: driver&apos;s license, franchise or business permit, and a live
            face check.
          </p>
        </div>
        <Alert tone="warn" title="Have a safety concern?" style={{ marginTop: 16 }}>
          Contact support right away at <span className="mono">{config.contactEmail}</span> or through the{" "}
          <Link to="/contact">Contact page</Link>.
        </Alert>
      </div>
    </section>
  );
}

export function AboutPage() {
  useDocumentTitle("FindMeTricycle · About");
  return (
    <section>
      <div className="wrap">
        <Head
          eyebrow="About"
          title="Built for Guiuan."
          sub="FindMeTricycle is a local tricycle booking platform made for Guiuan, Eastern Samar."
        />
        <div className="grid g3">
          <Card icon="pin" tone="o" title="Built for Guiuan">
            Made around how tricycles work in town: local routes, local drivers, cash fares.
          </Card>
          <Card icon="user" tone="t" title="One account, two modes">
            Every driver starts as a passenger. Approved drivers switch modes in the same app.
          </Card>
          <Card icon="shield" tone="v" title="Admin management">
            A local admin team reviews driver applications and handles reports.
          </Card>
        </div>
      </div>
    </section>
  );
}

export function NotFoundPage() {
  useDocumentTitle("FindMeTricycle · Page not found");
  return (
    <section>
      <div className="wrap">
        <div className="form-card glass" style={{ textAlign: "center" }}>
          <h2>Page not found</h2>
          <p className="muted" style={{ marginTop: 8 }}>
            The page you opened doesn&apos;t exist.
          </p>
          <Link className="btn btn-hot" style={{ marginTop: 20 }} to="/">
            Go Home
          </Link>
        </div>
      </div>
    </section>
  );
}
