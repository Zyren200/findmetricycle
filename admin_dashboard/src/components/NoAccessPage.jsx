import { ShieldOff } from "lucide-react";

// Shown when the URL points at a page the admin's role doesn't include.
export default function NoAccessPage({ pageTitle, roleLabel, homeTitle, onGoHome }) {
  return (
    <section className="panel no-access" role="alert">
      <ShieldOff size={32} />
      <h2>No access</h2>
      <p className="muted">
        {pageTitle ? <b>{pageTitle}</b> : "This page"} isn&apos;t part of the {roleLabel || "your"} role. Ask a
        Super Admin if you need it.
      </p>
      {onGoHome && homeTitle ? (
        <button type="button" className="btn btn-primary" onClick={onGoHome}>
          Go to {homeTitle}
        </button>
      ) : null}
    </section>
  );
}
