import { Link, useDocumentTitle } from "../../router";

// ── How It Works ─────────────────────────────────────────────────────────

const passengerSteps = [
  { icon: "⬇️", title: "Download the app", desc: "Get FindMeTricycle free from the download page. Install it on your Android phone." },
  { icon: "👤", title: "Create or log in", desc: "Sign up with your email (verified with a one-time code), or log in to your existing account." },
  { icon: "📍", title: "Set your pickup & destination", desc: "Tap the map or search for where you are and where you want to go within Guiuan." },
  { icon: "👥", title: "Select passenger count", desc: "Let the driver know how many passengers will be riding." },
  { icon: "💵", title: "Review the fare", desc: "See the estimated fare before confirming. Payment is cash only." },
  { icon: "✅", title: "Book and choose a driver", desc: "Confirm your booking and pick one of the nearby online drivers." },
  { icon: "🛺", title: "Track and ride", desc: "Track your driver in real time, show your pickup PIN, and ride safely to your destination." },
];

const driverSteps = [
  { icon: "👤", title: "Create or log in", desc: "Use your existing FindMeTricycle account. No separate driver account needed." },
  { icon: "📋", title: "Apply as a driver", desc: 'Go to the "Become a Driver" page and start your online application.' },
  { icon: "📄", title: "Submit requirements", desc: "Upload your driver's license and franchise / business permit." },
  { icon: "🤳", title: "Complete verification", desc: "Verify your identity with a live selfie through the website." },
  { icon: "⏳", title: "Wait for admin approval", desc: "Our team reviews your application, documents, and verification result." },
  { icon: "✅", title: "Get approved", desc: "When approved, Driver Mode is unlocked in your FindMeTricycle account." },
  { icon: "🛺", title: "Accept rides", desc: "Switch to Driver Mode in the app, go online, and start accepting passenger bookings." },
];

function StepList({ steps, driver }) {
  return (
    <div className="list-steps">
      {steps.map((s, i) => (
        <div className={`list-step ${driver && i === steps.length - 1 ? "highlight" : ""}`} key={s.title}>
          <div className={`list-step-num ${driver ? "driver" : ""}`}>{i + 1}</div>
          <div>
            <h3>
              <span>{s.icon}</span>
              {s.title}
            </h3>
            <p>{s.desc}</p>
          </div>
        </div>
      ))}
    </div>
  );
}

export function HowItWorksPage() {
  useDocumentTitle("How It Works — FindMeTricycle");
  return (
    <>
      <section className="page-hero">
        <div className="container container-xs">
          <h1>How It Works</h1>
          <p>Whether you&apos;re booking a ride or starting your driving journey, FindMeTricycle keeps it simple.</p>
        </div>
      </section>

      <section className="section-sm">
        <div className="container container-sm">
          <div className="group-head">
            <div className="group-icon">🛺</div>
            <div>
              <h2>For Passengers</h2>
              <p>Book a local tricycle ride in Guiuan</p>
            </div>
          </div>
          <StepList steps={passengerSteps} />
          <p className="text-center mt-8">
            <Link to="/download" className="cta cta-primary">
              Download App to Get Started
            </Link>
          </p>
        </div>
      </section>

      <section className="section-sm section-border">
        <div className="container container-sm">
          <div className="group-head">
            <div className="group-icon driver">👨‍✈️</div>
            <div>
              <h2>For Drivers</h2>
              <p>Apply and start earning in Guiuan</p>
            </div>
          </div>
          <StepList steps={driverSteps} driver />
          <p className="text-center mt-8">
            <Link to="/driver/apply" className="cta cta-driver">
              Apply as Driver
            </Link>
          </p>
        </div>
      </section>

      <section className="section-sm section-alt section-border">
        <div className="container container-sm">
          <div className="tile tile-plain center-tile">
            <span className="tile-emoji" style={{ fontSize: "2.4rem" }}>💵</span>
            <h3 style={{ fontSize: "1.25rem" }}>Cash Payment Only</h3>
            <p style={{ margin: "0 auto", maxWidth: "28rem" }}>
              FindMeTricycle uses cash payment only. Pay your driver directly after arriving at your
              destination — no digital wallets or cards required.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}

// ── Safety ───────────────────────────────────────────────────────────────

const passengerSafety = [
  { icon: "🪪", title: "Driver Information", desc: "See your driver's name, tricycle number, and rating before the ride begins." },
  { icon: "📍", title: "Live Ride Tracking", desc: "Track your tricycle in real time throughout the journey." },
  { icon: "🔢", title: "Pickup PIN", desc: "Your ride only starts once the driver enters the PIN shown in your app." },
  { icon: "🆘", title: "SOS Button", desc: "One-tap emergency alert that sends your location to the admin team." },
  { icon: "👥", title: "Passenger Count", desc: "Set the number of passengers so the driver knows who to expect." },
  { icon: "📋", title: "Ride History", desc: "Access your complete ride history for reference or reporting purposes." },
];

const driverSafety = [
  { icon: "🚨", title: "Issue Reporting", desc: "Report problematic passengers and incidents from within the app." },
  { icon: "🆘", title: "Driver SOS", desc: "Emergency alert available for drivers during an active ride." },
  { icon: "✅", title: "PIN Verification", desc: "Confirm you picked up the right passenger with their pickup PIN." },
  { icon: "❌", title: "No-Show Reporting", desc: "Passenger no-shows can be reported and reviewed by the admin." },
];

export function SafetyPage() {
  useDocumentTitle("Safety — FindMeTricycle");
  return (
    <>
      <section className="page-hero">
        <div className="container container-xs">
          <h1>Safety First</h1>
          <p>
            FindMeTricycle is designed with safety tools for both passengers and drivers. Here&apos;s
            what&apos;s in place to keep every ride secure.
          </p>
          <p className="field-hint" style={{ marginTop: 16, fontSize: ".75rem" }}>
            These features are designed to assist in safe travel. They do not replace personal judgment or
            emergency services. Always contact local authorities in a genuine emergency.
          </p>
        </div>
      </section>

      <section className="section-sm">
        <div className="container container-md">
          <div className="group-head">
            <div className="group-icon">🛺</div>
            <div>
              <h2>Passenger Safety</h2>
              <p>Safety tools available to everyone booking a ride</p>
            </div>
          </div>
          <div className="grid sm-2 lg-3">
            {passengerSafety.map((item) => (
              <div className="tile" key={item.title}>
                <span className="tile-emoji">{item.icon}</span>
                <h3>{item.title}</h3>
                <p>{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section-sm" style={{ background: "var(--driver-bg)", borderTop: "1px solid var(--line)" }}>
        <div className="container container-md">
          <div className="group-head">
            <div className="group-icon driver">👨‍✈️</div>
            <div>
              <h2>Driver Safety</h2>
              <p>Tools to help drivers manage their safety on the road</p>
            </div>
          </div>
          <div className="grid sm-2">
            {driverSafety.map((item) => (
              <div className="tile tile-plain" style={{ background: "var(--solid)" }} key={item.title}>
                <span className="tile-emoji">{item.icon}</span>
                <h3>{item.title}</h3>
                <p>{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section-sm">
        <div className="container container-md">
          <div className="tile tile-plain center-tile" style={{ background: "var(--teal-bg)", padding: 32 }}>
            <span className="tile-emoji" style={{ fontSize: "2.4rem" }}>✅</span>
            <h2 style={{ marginBottom: 12 }}>All Drivers Are Verified</h2>
            <p style={{ margin: "0 auto 16px", maxWidth: "36rem" }}>
              Every FindMeTricycle driver completes document verification, identity verification, and admin
              review before being allowed to accept rides. Drivers with incomplete or rejected applications
              cannot access Driver Mode.
            </p>
            <p style={{ margin: "0 auto", fontSize: ".75rem" }}>
              Verification helps maintain trust but does not guarantee the behavior of any individual. Use
              your judgment and the in-app tools at all times.
            </p>
          </div>
        </div>
      </section>

      <section className="section-sm section-alt section-border">
        <div className="container container-xs text-center">
          <h2 style={{ marginBottom: 8 }}>Have a safety concern?</h2>
          <p className="muted" style={{ margin: "0 auto 16px" }}>
            If you experienced or witnessed a safety issue, contact our support team right away.
          </p>
          <Link to="/contact" className="cta cta-primary cta-sm">
            Contact Support
          </Link>
        </div>
      </section>
    </>
  );
}

// ── About ────────────────────────────────────────────────────────────────

export function AboutPage() {
  useDocumentTitle("About FindMeTricycle — Guiuan, Eastern Samar");
  return (
    <>
      <section className="page-hero">
        <div className="container container-xs">
          <h1>About FindMeTricycle</h1>
          <p>A local transportation platform built around the needs of Guiuan, Eastern Samar.</p>
        </div>
      </section>

      <section className="section-sm">
        <div className="container container-xs prose">
          <div className="lead-box">
            <p>
              FindMeTricycle is a ride-hailing platform designed specifically for Guiuan, Eastern Samar,
              Philippines. It connects passengers with local tricycle drivers through a simple, safe, and
              easy-to-use mobile application.
            </p>
          </div>
          <h2>Built for Guiuan</h2>
          <p>
            Tricycles are the lifeblood of local transportation in Guiuan. FindMeTricycle was created to
            bring the convenience of ride-hailing technology to this community — without overcomplicating
            it. The platform is designed to work on everyday Android phones, with a focus on simplicity,
            reliability, and trust.
          </p>
          <h2>For Passengers</h2>
          <p>
            Passengers use the FindMeTricycle mobile application to book local tricycle rides. The app shows
            available drivers nearby, provides live ride tracking, and allows passengers to pay in cash — no
            digital wallets required. Safety tools like SOS alerts and driver verification are built in to
            keep every ride trustworthy.
          </p>
          <h2>For Drivers</h2>
          <p>
            Tricycle drivers in Guiuan can join the platform by applying through this website. They use their
            existing FindMeTricycle account — there is no separate driver account. After submitting their
            documents, completing identity verification, and receiving admin approval, Driver Mode becomes
            available in their app. Drivers can then switch between Passenger Mode and Driver Mode as needed.
          </p>
          <h2>One Account, Two Modes</h2>
          <p>
            FindMeTricycle uses a single unified account system. Everyone starts as a Passenger. Those who wish
            to drive can apply through the website — and when approved by the admin team, their same account is
            upgraded to include Driver capability. There is no need to create or manage a separate driver
            account.
          </p>
          <h2>Admin Management</h2>
          <p>
            The FindMeTricycle Admin Dashboard allows the operations team to review driver applications, verify
            submitted documents, manage accounts, and maintain the quality and safety of the platform. Admin
            approval is required before any driver can access Driver Mode.
          </p>
        </div>
      </section>

      <section className="section-sm section-alt section-border">
        <div className="container container-md">
          <h2 className="text-center" style={{ marginBottom: 32 }}>
            What we stand for
          </h2>
          <div className="grid sm-3">
            {[
              { icon: "🤝", title: "Local First", desc: "Built specifically for Guiuan, not a generic copy of global platforms." },
              { icon: "🔒", title: "Safety & Trust", desc: "Driver verification, document review, and admin oversight keep the community safe." },
              { icon: "💡", title: "Simple & Accessible", desc: "Designed for everyday Android phones and ordinary users — no technical knowledge needed." },
            ].map((v) => (
              <div className="tile tile-plain center-tile" key={v.title}>
                <span className="tile-emoji" style={{ fontSize: "2.4rem" }}>{v.icon}</span>
                <h3>{v.title}</h3>
                <p>{v.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section-sm section-border">
        <div className="container container-xs text-center">
          <h2 style={{ marginBottom: 16 }}>Be part of FindMeTricycle</h2>
          <p className="muted" style={{ margin: "0 auto 24px" }}>
            Download the app to book rides, or apply to join our driver network in Guiuan.
          </p>
          <div className="cta-row center">
            <Link to="/download" className="cta cta-primary">
              Download App
            </Link>
            <Link to="/driver" className="cta cta-outline-driver">
              Become a Driver
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}

// ── 404 ──────────────────────────────────────────────────────────────────

export function NotFoundPage() {
  useDocumentTitle("Page Not Found — FindMeTricycle");
  return (
    <div className="container center-block" style={{ padding: "96px 16px" }}>
      <div className="big" style={{ fontSize: "4.5rem" }}>🛺</div>
      <h1 style={{ fontSize: "3rem" }}>404</h1>
      <p style={{ fontSize: "1.2rem", color: "var(--ink-2)", marginBottom: 8 }}>Page Not Found</p>
      <p>This road doesn&apos;t go anywhere. The page you&apos;re looking for doesn&apos;t exist or has been moved.</p>
      <div className="cta-row center">
        <Link to="/" className="cta cta-primary">
          Go Home
        </Link>
        <Link to="/contact" className="cta cta-outline">
          Contact Support
        </Link>
      </div>
    </div>
  );
}
