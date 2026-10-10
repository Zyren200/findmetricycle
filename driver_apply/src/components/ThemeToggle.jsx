const STORAGE_KEY = "fmt-theme";

// The theme in effect: the visitor's choice, else the system setting.
function currentTheme() {
  const set = document.documentElement.dataset.theme;
  if (set === "dark" || set === "light") return set;
  return matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

/** Light/dark switch; the new theme spreads in a circle from the button. */
export function ThemeToggle() {
  function toggle(e) {
    const root = document.documentElement;
    const next = currentTheme() === "dark" ? "light" : "dark";
    const set = () => {
      root.dataset.theme = next;
    };
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // Private mode: the choice just isn't remembered.
    }
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!document.startViewTransition || reduce) return set();
    const x = e.clientX || innerWidth - 40;
    const y = e.clientY || 40;
    const r = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
    document
      .startViewTransition(set)
      .ready.then(() => {
        root.animate(
          { clipPath: [`circle(0 at ${x}px ${y}px)`, `circle(${r}px at ${x}px ${y}px)`] },
          { duration: 650, easing: "cubic-bezier(.22,1,.36,1)", pseudoElement: "::view-transition-new(root)" }
        );
      })
      .catch(() => {});
  }

  return (
    <button className="ibtn" id="theme" type="button" aria-label="Toggle light or dark theme" onClick={toggle}>
      <svg className="ico-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
      </svg>
      <svg className="ico-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
        <circle cx="12" cy="12" r="4.5" />
        <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
      </svg>
    </button>
  );
}
