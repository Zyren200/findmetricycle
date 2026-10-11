import { useEffect, useRef, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { installPrismFx } from "../prism-fx";
import { Link, navigate, usePath } from "../router";

import { ThemeToggle } from "./ThemeToggle";
import { useToast } from "./ui";

const NAV = [
  ["/", "Home"],
  ["/how-it-works", "How It Works"],
  ["/driver", "Become a Driver"],
  ["/download", "Download"],
  ["/safety", "Safety"],
  ["/about", "About"],
  ["/contact", "Contact"],
];

export function firstName(user) {
  return String(user?.fullName || user?.full_name || "").trim().split(/\s+/)[0] || "there";
}

export function Logo() {
  return (
    <Link to="/" className="logo">
      <span className="mark mark-img">
        <img src="/app-icon.png" alt="" />
      </span>
      <span>
        FindMe<b>Tricycle</b>
      </span>
    </Link>
  );
}

function isOn(to, path) {
  if (to === "/driver") return path === "/driver" || path === "/driver/apply";
  return to === path;
}

function Header({ tabsRef, headerRef }) {
  const path = usePath();
  const { isAuthenticated, user, logout } = useAuth();
  const toast = useToast();
  const [open, setOpen] = useState(false);

  const items = isAuthenticated ? [...NAV, ["/driver/status", "My Application"]] : NAV;

  useEffect(() => setOpen(false), [path]);
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => e.key === "Escape" && setOpen(false);
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open]);

  function signOut() {
    setOpen(false);
    logout();
    toast("Signed out", "You can sign in again any time to check your application.");
    navigate("/driver");
  }

  return (
    <header className="nav" ref={headerRef}>
      <div className="wrap">
        <nav className="nav-in glass" aria-label="Main">
          <Logo />
          <ul className={`tabs ${open ? "open" : ""}`} id="tabs" ref={tabsRef}>
            {items.map(([to, label]) => (
              <li key={to}>
                <Link to={to} className={isOn(to, path) ? "on" : ""} onClick={() => setOpen(false)}>
                  {label}
                </Link>
              </li>
            ))}
            {isAuthenticated ? (
              <li className="only-m">
                <button type="button" onClick={signOut}>
                  Sign Out
                </button>
              </li>
            ) : null}
          </ul>
          <div className="actions">
            <span style={{ display: "flex", gap: 8, alignItems: "center" }}>
              {isAuthenticated ? (
                <>
                  <span className="user-chip">
                    <i>{firstName(user).charAt(0).toUpperCase()}</i>
                    <span>{firstName(user)}</span>
                  </span>
                  <button type="button" className="btn btn-glass btn-sm" id="signOut" onClick={signOut}>
                    Sign Out
                  </button>
                </>
              ) : (
                <Link to="/driver/apply" className="btn btn-hot btn-sm nav-cta">
                  Apply as Driver
                </Link>
              )}
            </span>
            <ThemeToggle />
            <button
              type="button"
              className="ibtn burger"
              aria-label="Menu"
              aria-expanded={open}
              aria-controls="tabs"
              onClick={() => setOpen((o) => !o)}
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
                <path d="M4 7h16M4 12h16M4 17h16" />
              </svg>
            </button>
          </div>
        </nav>
      </div>
    </header>
  );
}

function Footer() {
  return (
    <footer>
      <div className="wrap">
        <div>
          <b style={{ color: "var(--fg)" }}>FindMeTricycle</b> · Guiuan, Eastern Samar
          <br />
          <small>&copy; {new Date().getFullYear()} FindMeTricycle. Cash rides with verified local drivers.</small>
        </div>
        <nav aria-label="Footer">
          <Link to="/how-it-works">How It Works</Link>
          <Link to="/driver">Become a Driver</Link>
          <Link to="/driver/status">Application Status</Link>
          <Link to="/safety">Safety</Link>
          <Link to="/contact">Contact</Link>
        </nav>
      </div>
    </footer>
  );
}

export default function Layout({ children }) {
  const appRef = useRef(null);
  const tabsRef = useRef(null);
  const headerRef = useRef(null);

  useEffect(
    () => installPrismFx({ app: appRef.current, tabs: tabsRef.current, header: headerRef.current }),
    []
  );

  return (
    <>
      <div className="sky" aria-hidden="true">
        <span className="stars" />
        <span className="aur x1" />
        <span className="aur x2" />
        <span className="aur x3" />
        <span className="aur x4" />
        <span className="beam" />
      </div>
      <Header tabsRef={tabsRef} headerRef={headerRef} />
      <main id="app" ref={appRef}>
        {children}
      </main>
      <Footer />
    </>
  );
}
