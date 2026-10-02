import { Link, useDocumentTitle } from "../../router";

function PhoneMockup() {
  return (
    <div className="phone">
      <div className="phone-orb a" />
      <div className="phone-orb b" />
      <div className="phone-frame">
        <div className="phone-notch" />
        <div className="phone-screen">
          <div className="ph-head">
            <div className="ph-row">
              <div>
                <small>FindMeTricycle</small>
                <b>Good morning!</b>
              </div>
              <div className="ph-avatar">JD</div>
            </div>
            <small>Where are you going?</small>
            <div className="ph-search">
              <i />
              Enter destination...
            </div>
          </div>
          <div className="ph-map">
            <div>
              <i />
              Guiuan, E. Samar
            </div>
          </div>
          <div className="ph-actions">
            <div className="ph-action">
              <span>🛺</span>
              <b>Book Ride</b>
              <small>Fast &amp; easy</small>
            </div>
            <div className="ph-action gray">
              <span>📍</span>
              <b>Track Ride</b>
              <small>Live location</small>
            </div>
          </div>
          <div className="ph-drivers">
            <b>Nearby Drivers</b>
            {[
              { name: "Rodrigo S.", eta: "2 min", rating: "4.9" },
              { name: "Maria L.", eta: "4 min", rating: "4.8" },
            ].map((d) => (
              <div className="ph-driver" key={d.name}>
                <span>🛺 {d.name}</span>
                <span>
                  <em>{d.eta}</em>
                  <small>★ {d.rating}</small>
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

const features = [
  { icon: "🛺", title: "Book Instantly", desc: "Find available tricycle drivers near you in Guiuan with just a few taps." },
  { icon: "📍", title: "Live Tracking", desc: "Track your driver on the map in real time until you reach your destination." },
  { icon: "💵", title: "Cash Payment", desc: "Pay easily with cash — no cards or digital wallets required." },
  { icon: "✅", title: "Verified Drivers", desc: "Every driver completes identity and document verification before joining." },
  { icon: "🆘", title: "SOS Safety", desc: "One-tap SOS alert and in-app reporting keep every trip secure." },
  { icon: "⭐", title: "Rate & Review", desc: "Help the community by rating your rides and giving driver feedback." },
];

const passengerSteps = [
  { num: "01", label: "Download the app", desc: "Get FindMeTricycle free for Android." },
  { num: "02", label: "Create an account", desc: "Quick signup, verified with your email." },
  { num: "03", label: "Set your destination", desc: "Pick your pickup and drop-off in Guiuan." },
  { num: "04", label: "Book your ride", desc: "Confirm the fare and choose a nearby driver." },
];

export default function HomePage() {
  useDocumentTitle("FindMeTricycle — Your Local Tricycle Ride in Guiuan");

  return (
    <>
      {/* Hero */}
      <section className="hero">
        <div className="container">
          <div className="grid lg-2 hero-grid">
            <div>
              <span className="eyebrow">Guiuan, Eastern Samar</span>
              <h1 className="hero-title">
                Your Local Tricycle Ride, <span className="accent">Made Simple.</span>
              </h1>
              <p className="lead">
                FindMeTricycle connects passengers with verified local tricycle drivers in Guiuan. Book a
                ride, track it live, and pay with cash — all from your phone.
              </p>
              <div className="cta-row">
                <Link to="/download" className="cta cta-primary">
                  Download App
                </Link>
                <Link to="/driver" className="cta cta-outline-driver">
                  Become a Driver
                </Link>
              </div>
              <div className="trust">
                <div>
                  <i style={{ background: "var(--driver-bg)", color: "var(--driver)" }}>✓</i>
                  Verified Drivers
                </div>
                <div>
                  <i style={{ background: "var(--teal-bg)" }}>🔒</i>
                  Safe &amp; Secure
                </div>
                <div>
                  <i style={{ background: "var(--sky-bg)" }}>📍</i>
                  Live Tracking
                </div>
              </div>
            </div>
            <PhoneMockup />
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="section">
        <div className="container">
          <div className="section-head">
            <h2>Everything you need for a safe, easy ride</h2>
            <p>Built around the needs of Guiuan residents — simple, reliable, and always local.</p>
          </div>
          <div className="grid sm-2 lg-3">
            {features.map((f) => (
              <div className="tile" key={f.title}>
                <div className="tile-icon">{f.icon}</div>
                <h3>{f.title}</h3>
                <p>{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How it works teaser */}
      <section className="section section-alt">
        <div className="container">
          <div className="section-head">
            <h2>Ready in 4 easy steps</h2>
            <p>Start riding in minutes.</p>
          </div>
          <div className="grid sm-2 lg-4">
            {passengerSteps.map((s) => (
              <div className="tile tile-plain center-tile" key={s.num}>
                <div className="step-num">{s.num}</div>
                <h3>{s.label}</h3>
                <p>{s.desc}</p>
              </div>
            ))}
          </div>
          <p className="text-center mt-8">
            <Link to="/how-it-works">See full guide →</Link>
          </p>
        </div>
      </section>

      {/* Download CTA */}
      <section className="band band-primary">
        <div className="container">
          <h2>Ready to ride in Guiuan?</h2>
          <p>Download FindMeTricycle today and book your first local tricycle ride.</p>
          <Link to="/download" className="cta cta-white cta-lg">
            Download for Android
          </Link>
          <small>Free download · No hidden fees · Cash payment only</small>
        </div>
      </section>

      {/* Driver recruitment */}
      <section className="section">
        <div className="container">
          <div className="recruit">
            <div className="grid lg-2" style={{ alignItems: "center", gap: 32 }}>
              <div>
                <span className="eyebrow driver">For Tricycle Drivers</span>
                <h2>Earn more, drive smarter</h2>
                <p className="lead">
                  Join FindMeTricycle as a driver and connect with passengers across Guiuan. Flexible
                  schedule, direct bookings, and a community that supports you.
                </p>
                <div className="cta-row">
                  <Link to="/driver/apply" className="cta cta-driver">
                    Apply as Driver
                  </Link>
                  <Link to="/driver" className="cta cta-outline-driver">
                    Learn More
                  </Link>
                </div>
              </div>
              <div className="grid sm-2 grid-gap-sm" style={{ gridTemplateColumns: "1fr 1fr" }}>
                {[
                  { icon: "📋", title: "Simple application", desc: "Apply online with your documents" },
                  { icon: "✅", title: "Quick verification", desc: "Admin reviews your application" },
                  { icon: "📱", title: "One account", desc: "Switch between Passenger & Driver mode" },
                  { icon: "💵", title: "Cash earnings", desc: "Collect payment directly from riders" },
                ].map((item) => (
                  <div className="mini-tile" key={item.title}>
                    <span>{item.icon}</span>
                    <b>{item.title}</b>
                    <small>{item.desc}</small>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
