import { useEffect, useState } from "react";

// Minimal client-side routing for the website (history API). Vite's dev
// server and any SPA host fall back to index.html, so deep links work.

const listeners = new Set();

export function navigate(to, { replace = false } = {}) {
  if (to === window.location.pathname + window.location.search) return;
  if (replace) window.history.replaceState({}, "", to);
  else window.history.pushState({}, "", to);
  window.scrollTo(0, 0);
  listeners.forEach((fn) => fn());
}

export function usePath() {
  const [path, setPath] = useState(window.location.pathname);
  useEffect(() => {
    const update = () => setPath(window.location.pathname);
    listeners.add(update);
    window.addEventListener("popstate", update);
    return () => {
      listeners.delete(update);
      window.removeEventListener("popstate", update);
    };
  }, []);
  return path.replace(/\/+$/, "") || "/";
}

export function Link({ to, className, children, onClick, ...rest }) {
  return (
    <a
      href={to}
      className={className}
      onClick={(e) => {
        onClick?.(e);
        if (e.defaultPrevented || e.metaKey || e.ctrlKey || e.shiftKey || e.button !== 0) return;
        e.preventDefault();
        navigate(to);
      }}
      {...rest}
    >
      {children}
    </a>
  );
}

export function NavLink({ to, end, className, activeClassName = "active", ...rest }) {
  const path = usePath();
  const active = end ? path === to : path === to || path.startsWith(`${to}/`);
  return <Link to={to} className={`${className || ""} ${active ? activeClassName : ""}`} {...rest} />;
}

export function useDocumentTitle(title) {
  useEffect(() => {
    document.title = title;
  }, [title]);
}
