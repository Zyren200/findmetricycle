export default function SuccessPage({ onViewStatus }) {
  return (
    <div className="screen">
      <div className="shell">
        <div className="brand">
          <span className="brand-emoji">🛺</span>
          <span className="brand-title">FindMeTricycle</span>
        </div>

        <div className="card center-text">
          <div style={{ fontSize: 48, marginBottom: 12 }}>✅</div>
          <h1>Application Submitted Successfully</h1>
          <p>Your driver application has been submitted and is waiting for verification.</p>
          <p>We'll email you at each step of the review process.</p>

          <button type="button" className="btn btn-primary" onClick={onViewStatus}>
            View Application Status
          </button>
        </div>
      </div>
    </div>
  );
}
