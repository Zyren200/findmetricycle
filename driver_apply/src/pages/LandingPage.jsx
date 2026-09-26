export default function LandingPage({ onStart }) {
  return (
    <div className="screen">
      <div className="shell">
        <div className="brand">
          <span className="brand-emoji">🛺</span>
          <span className="brand-title">FindMeTricycle</span>
        </div>

        <div className="card">
          <h1>Become a FindMeTricycle Driver</h1>
          <p>
            Apply with the account you already use to book rides. Upload your documents, complete a
            quick face check, and our team verifies everything before Driver Mode turns on.
          </p>

          <button type="button" className="btn btn-primary" onClick={onStart} style={{ marginTop: 20 }}>
            Start Application
          </button>

          <p className="field-hint center-text" style={{ marginTop: 12 }}>
            Takes about 10 minutes. Keep your license and permit photos nearby.
          </p>
        </div>

        <div className="pass">
          <div className="pass-top">
            <span className="pass-mark" aria-hidden="true">🛺</span>
            <div>
              <p className="pass-title">Driver verification</p>
              <p className="pass-sub">What your application goes through</p>
            </div>
          </div>
          <ul className="pass-checks">
            <li>
              <span className="tick">✓</span>
              <div><b>Account confirmed</b><small>Your existing passenger account</small></div>
            </li>
            <li>
              <span className="tick">✓</span>
              <div><b>Email code verified</b><small>Sent to your registered email</small></div>
            </li>
            <li>
              <span className="tick">✓</span>
              <div><b>Documents checked</b><small>License &amp; business permit</small></div>
            </li>
            <li>
              <span className="tick">✓</span>
              <div><b>Face check passed</b><small>Look straight, blink, turn head</small></div>
            </li>
            <li>
              <span className="tick waiting">●</span>
              <div><b>Admin review</b><small>A person makes the final decision</small></div>
            </li>
          </ul>
        </div>

        <div className="card">
          <p className="field-hint" style={{ margin: 0 }}>
            You must already have a FindMeTricycle passenger account to continue — this does not create
            a separate driver account. Once approved, switch between Passenger and Driver mode right in
            the app.
          </p>
        </div>
      </div>
    </div>
  );
}
