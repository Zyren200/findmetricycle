import { Link, useDocumentTitle } from "../../router";

// What the application actually asks for (see the wizard steps).
const requirements = [
  { icon: "🪪", label: "Valid Driver's License", note: "Clear photo; the license details are read automatically" },
  { icon: "📄", label: "Franchise or Business Permit", note: "Clear photo of your current permit" },
  { icon: "🛺", label: "Tricycle Information", note: "Plate number and franchise / permit number" },
  { icon: "📞", label: "Address & Emergency Contact", note: "Your home address and someone we can reach" },
  { icon: "📷", label: "Face Verification", note: "Quick live selfie check through this website" },
  { icon: "📱", label: "FindMeTricycle Account", note: "Your passenger account with a registered email" },
];

const benefits = [
  { icon: "⏰", title: "Flexible Schedule", desc: "Drive on your own time. Go online when you want, rest when you need." },
  { icon: "💵", title: "Cash Earnings", desc: "Collect payment directly from passengers. No waiting for payouts." },
  { icon: "📱", title: "Easy to Manage", desc: "Switch between Passenger and Driver mode in the same FindMeTricycle account." },
  { icon: "🤝", title: "Local Community", desc: "Be part of a trusted driver network built for Guiuan." },
];

const applicationSteps = [
  { label: "Complete CAPTCHA", desc: "Simple human verification to protect your application." },
  { label: "Log in", desc: "Use your existing FindMeTricycle passenger account." },
  { label: "Verify Email with OTP", desc: "Confirm your email address with a one-time code." },
  { label: "Personal Information", desc: "Confirm your details, address and emergency contact." },
  { label: "Driver Information", desc: "Enter your license type, plate number and franchise number." },
  { label: "Upload Documents", desc: "Upload clear photos of your driver's license and franchise / business permit." },
  { label: "Face Verification", desc: "Complete a quick live selfie check to confirm your identity." },
  { label: "Review & Submit", desc: "Review everything and confirm with a code sent to your email." },
  { label: "Admin Review", desc: "Our team reviews your application and documents. You'll be emailed at each step." },
];

export default function DriverPage() {
  useDocumentTitle("Become a Driver — FindMeTricycle");

  return (
    <>
      <section className="hero" style={{ paddingBottom: 64 }}>
        <div className="container">
          <div style={{ maxWidth: 672 }}>
            <span className="eyebrow driver">Guiuan, Eastern Samar</span>
            <h1 className="hero-title" style={{ fontSize: "clamp(2rem, 6vw, 3rem)" }}>
              Drive with <span className="accent-driver">FindMeTricycle</span>
            </h1>
            <p className="lead" style={{ maxWidth: "none" }}>
              Become a verified driver and connect with passengers across Guiuan. Use your existing
              FindMeTricycle account — no separate driver account needed.
            </p>
            <div className="cta-row">
              <Link to="/driver/apply" className="cta cta-driver">
                Apply as Driver
              </Link>
              <Link to="/driver/status" className="cta cta-outline-driver">
                Check Application Status
              </Link>
            </div>
          </div>
        </div>
      </section>

      <section className="callout-band">
        <div className="container">
          <div className="callout-row">
            <div className="callout-icon">ℹ️</div>
            <div>
              <b>One Account. Two Modes.</b>
              <p>
                FindMeTricycle uses a single account. You start as a Passenger. After approval, your same
                account unlocks Driver Mode — no second account, no separate login.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="section">
        <div className="container">
          <div className="section-head" style={{ marginBottom: 40 }}>
            <h2>Why drive with us?</h2>
            <p>Built for Guiuan drivers.</p>
          </div>
          <div className="grid sm-2 lg-4">
            {benefits.map((b) => (
              <div className="tile tile-driver" key={b.title}>
                <span className="tile-emoji">{b.icon}</span>
                <h3>{b.title}</h3>
                <p>{b.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container container-md">
          <div className="section-head" style={{ marginBottom: 40 }}>
            <h2>Driver Requirements</h2>
            <p>Prepare these before starting your application.</p>
          </div>
          <div className="grid sm-2 grid-gap-sm">
            {requirements.map((r) => (
              <div className="tile tile-plain req-tile" key={r.label}>
                <div className="req-icon">{r.icon}</div>
                <div>
                  <b>{r.label}</b>
                  <small>{r.note}</small>
                </div>
              </div>
            ))}
          </div>
          <p className="note">Additional requirements may be requested by the admin after initial review.</p>
        </div>
      </section>

      <section className="section">
        <div className="container container-sm">
          <div className="section-head" style={{ marginBottom: 40 }}>
            <h2>How the application works</h2>
            <p>{applicationSteps.length} steps from application to Driver Mode.</p>
          </div>
          <div className="timeline-v">
            {applicationSteps.map((s, i) => (
              <div className="timeline-v-item" key={s.label}>
                <div className="timeline-v-num">{String(i + 1).padStart(2, "0")}</div>
                <div className={`timeline-v-body ${i === applicationSteps.length - 1 ? "highlight" : ""}`}>
                  <b>{s.label}</b>
                  <small>{s.desc}</small>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="band band-driver">
        <div className="container">
          <h2>Ready to start driving?</h2>
          <p>Apply now and join the FindMeTricycle driver network in Guiuan.</p>
          <div className="cta-row center">
            <Link to="/driver/apply" className="cta cta-white cta-lg" style={{ color: "var(--driver)" }}>
              Start Application
            </Link>
            <Link to="/driver/status" className="cta cta-ghost-white cta-lg">
              Check Status
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
