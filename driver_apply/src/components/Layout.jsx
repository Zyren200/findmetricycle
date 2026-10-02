import { useState } from "react";
import { config } from "../config";
import { useAuth } from "../context/AuthContext";
import { Link, NavLink, navigate } from "../router";

const navLinks = [
  { to: "/", label: "Home", end: true },
  { to: "/how-it-works", label: "How It Works" },
  { to: "/driver", label: "Become a Driver" },
  { to: "/safety", label: "Safety" },
  { to: "/about", label: "About" },
  { to: "/contact", label: "Contact" },
];

export function Logo() {
  return (
    <Link to="/" className="logo">
      <span className="logo-mark">F</span>
      <span className="logo-text">
        Find<span>Me</span>Tricycle
      </span>
    </Link>
  );
}

function Header() {
  const [open, setOpen] = useState(false);
  const { isAuthenticated, logout } = useAuth();

  function handleLogout() {
    setOpen(false);
    logout();
    navigate("/");
  }

  return (
    <header className="site-header">
      <div className="container">
        <div className="site-header-row">
          <span onClick={() => setOpen(false)}>
            <Logo />
          </span>

          <nav className="nav">
            {navLinks.map((l) => (
              <NavLink key={l.to} to={l.to} end={l.end}>
                {l.label}
              </NavLink>
            ))}
          </nav>

          <div className="header-actions">
            {isAuthenticated ? (
              <>
                <Link to="/driver/status" className="header-link">
                  My Application
                </Link>
                <button type="button" className="header-link" onClick={handleLogout}>
                  Sign Out
                </button>
              </>
            ) : null}
            <Link to="/download" className="cta cta-primary cta-sm">
              Download App
            </Link>
          </div>

          <button
            type="button"
            className="menu-btn"
            onClick={() => setOpen(!open)}
            aria-label="Toggle menu"
            aria-expanded={open}
          >
            <svg width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              {open ? (
                <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
              ) : (
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
              )}
            </svg>
          </button>
        </div>
      </div>

      {open ? (
        <div className="mobile-menu">
          <nav className="container">
            {navLinks.map((l) => (
              <NavLink key={l.to} to={l.to} end={l.end} onClick={() => setOpen(false)}>
                {l.label}
              </NavLink>
            ))}
            <div className="mobile-menu-footer">
              {isAuthenticated ? (
                <>
                  <Link to="/driver/status" onClick={() => setOpen(false)}>
                    My Application
                  </Link>
                  <button type="button" className="header-link" onClick={handleLogout}>
                    Sign Out
                  </button>
                </>
              ) : null}
              <Link to="/download" className="cta cta-primary" onClick={() => setOpen(false)}>
                Download App
              </Link>
            </div>
          </nav>
        </div>
      ) : null}
    </header>
  );
}

const footerColumns = [
  {
    title: "Passengers",
    links: [
      { to: "/download", label: "Download App" },
      { to: "/how-it-works", label: "How It Works" },
      { to: "/safety", label: "Safety" },
    ],
  },
  {
    title: "Drivers",
    links: [
      { to: "/driver", label: "Become a Driver" },
      { to: "/driver/apply", label: "Apply Now" },
      { to: "/driver/status", label: "Application Status" },
    ],
  },
  {
    title: "Company",
    links: [
      { to: "/about", label: "About Us" },
      { to: "/contact", label: "Contact" },
      { to: "/safety", label: "Safety Policy" },
    ],
  },
];

function Footer() {
  return (
    <footer className="site-footer">
      <div className="container">
        <div className="footer-grid">
          <div className="footer-brand">
            <Logo />
            <p>Your local tricycle ride-hailing platform, built for Guiuan, Eastern Samar.</p>
            <a className="footer-mail" href={`mailto:${config.contactEmail}`}>
              {config.contactEmail}
            </a>
          </div>
          {footerColumns.map((col) => (
            <div key={col.title}>
              <h3>{col.title}</h3>
              <ul>
                {col.links.map((l) => (
                  <li key={l.label}>
                    <Link to={l.to}>{l.label}</Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="footer-bottom">
          <span>&copy; {new Date().getFullYear()} FindMeTricycle. Guiuan, Eastern Samar, Philippines.</span>
          <span>
            <span className="live-dot" />
            Service available in Guiuan
          </span>
        </div>
      </div>
    </footer>
  );
}

export default function Layout({ children }) {
  return (
    <div className="site">
      <Header />
      <main className="site-main">{children}</main>
      <Footer />
    </div>
  );
}
