import { Shield } from "lucide-react";

/// Two-panel frame for the sign-in / sign-up / reset screens: brand panel
/// on the left (large screens), the form on the right.
export default function AuthShell({ children }) {
  return (
    <div className="adm-auth">
      <aside className="adm-auth-side">
        <div className="adm-auth-brand">
          <div className="mark">
            <Shield size={20} />
          </div>
          <div>
            <b>FindMeTricycle</b>
            <small>ADMIN PORTAL</small>
          </div>
        </div>

        <div>
          <p className="adm-auth-headline">
            Guiuan&apos;s Tricycle
            <br />
            <span>Operations Hub</span>
          </p>
          <p className="adm-auth-copy">
            Approve drivers, monitor live rides, manage SOS emergencies, and set fares — all in one place.
          </p>
          <div className="adm-auth-tiles">
            {[
              ["Driver approvals", "Review documents & face checks"],
              ["Live monitoring", "Online drivers and active rides"],
              ["SOS response", "Real-time emergency alerts"],
              ["Fare control", "Rates applied instantly in the app"],
            ].map(([title, sub]) => (
              <div key={title}>
                <b>{title}</b>
                <small>{sub}</small>
              </div>
            ))}
          </div>
        </div>

        <p className="adm-auth-foot">Guiuan, Eastern Samar, Philippines</p>
      </aside>

      <main className="adm-auth-main">
        <div>{children}</div>
      </main>
    </div>
  );
}
