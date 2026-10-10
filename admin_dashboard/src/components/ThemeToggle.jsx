import { useState } from "react";
import { Moon, Sun } from "lucide-react";

const STORAGE_KEY = "fmt-admin-theme";

function currentTheme() {
  return document.documentElement.dataset.theme === "dark" ? "dark" : "light";
}

/// Light/dark switch; index.html applies the saved choice before paint.
export default function ThemeToggle({ className = "adm-icon-btn adm-theme-btn" }) {
  const [theme, setTheme] = useState(currentTheme);
  const next = theme === "dark" ? "light" : "dark";

  function toggle() {
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // Private mode: the choice just isn't remembered.
    }
    setTheme(next);
  }

  return (
    <button
      type="button"
      className={className}
      onClick={toggle}
      aria-label={`Switch to ${next} mode`}
      title={`Switch to ${next} mode`}
    >
      {theme === "dark" ? <Sun size={18} /> : <Moon size={18} />}
    </button>
  );
}
