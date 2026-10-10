import { ICON } from "../../components/Icons";
import { Card, Head, PhoneMock, StepCard } from "../../components/ui";
import { Link, useDocumentTitle } from "../../router";
import { DriverCta } from "./DriverPage";

export default function HomePage() {
  useDocumentTitle("FindMeTricycle");

  return (
    <>
      <div className="wrap hero">
        <div>
          <span className="live glass">
            <i />
            Now serving Guiuan, Eastern Samar
          </span>
          <h1>
            Sakay na, <span className="glow">one tap away.</span>
          </h1>
          <p className="lead">
            Book a local tricycle, watch it arrive on the map, and pay cash when you get there. Built for Guiuan riders
            and drivers.
          </p>
          <div className="row cta-row">
            <Link className="btn btn-hot" to="/download">
              Download for Android {ICON.arrow}
            </Link>
            <Link className="btn btn-glass" to="/driver">
              Become a Driver
            </Link>
          </div>
          <div className="kpis">
            <div className="kpi glass">
              <b>Free</b>
              <span>Android app</span>
            </div>
            <div className="kpi glass">
              <b>Verified</b>
              <span>Every driver</span>
            </div>
            <div className="kpi glass">
              <b>Cash</b>
              <span>Pay on arrival</span>
            </div>
          </div>
        </div>
        <PhoneMock />
      </div>

      <section>
        <div className="wrap">
          <Head eyebrow="Why FindMeTricycle" title="Everything a Guiuan ride needs." as="h2" />
          <div className="grid g4">
            <Card icon="pin" tone="o" title="Live tracking">
              See your driver on the map from pickup to drop-off.
            </Card>
            <Card icon="cash" tone="t" title="Cash only">
              Pay the driver when you arrive. No card needed.
            </Card>
            <Card icon="shield" tone="v" title="Verified drivers">
              License, permit and a face check before anyone drives.
            </Card>
            <Card icon="user" tone="o" title="One account, two modes">
              Ride today. Switch to Driver Mode once you are approved.
            </Card>
          </div>
        </div>
      </section>

      <section>
        <div className="wrap">
          <Head eyebrow="For passengers" title="Start riding in 4 steps." as="h2" />
          <div className="grid g4">
            <StepCard n={1} title="Download the app">
              Get the free Android app from our Download page.
            </StepCard>
            <StepCard n={2} title="Create your account">
              Sign up with your email and mobile number.
            </StepCard>
            <StepCard n={3} title="Set your destination">
              Choose pickup and drop-off and see the fare.
            </StepCard>
            <StepCard n={4} title="Ride and pay cash">
              Track your driver and pay when you arrive.
            </StepCard>
          </div>
        </div>
      </section>

      <section>
        <div className="wrap">
          <div className="card glass" style={{ padding: 44, textAlign: "center" }}>
            <span className="eyebrow">For tricycle drivers</span>
            <h2 style={{ fontSize: "clamp(28px,4vw,46px)", margin: "14px auto 0", maxWidth: "18ch" }}>
              More passengers, less waiting at the terminal.
            </h2>
            <p className="muted" style={{ margin: "14px auto 0", maxWidth: "52ch" }}>
              Use your passenger account to apply. Have your driver&apos;s license and franchise permit ready.
            </p>
            <div className="row" style={{ justifyContent: "center", marginTop: 24 }}>
              <DriverCta />
              <Link className="btn btn-glass" to="/driver">
                See requirements
              </Link>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
