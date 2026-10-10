import { Component, createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { ICON } from "./Icons";

/** Section heading: mono eyebrow with the prism dash, title, optional lead. */
export function Head({ eyebrow, title, sub, as: Tag = "h1" }) {
  return (
    <div className="head">
      <span className="eyebrow">{eyebrow}</span>
      <Tag>{title}</Tag>
      {sub ? <p>{sub}</p> : null}
    </div>
  );
}

/** Glass feature card with a gradient icon tile (o = ember, t = lagoon, v = dusk). */
export function Card({ icon, tone = "o", title, children }) {
  return (
    <article className="card glass">
      <span className={`ic ${tone}`}>{ICON[icon]}</span>
      <h3>{title}</h3>
      <p>{children}</p>
    </article>
  );
}

/** Glass card with a numbered prism badge. */
export function StepCard({ n, title, children }) {
  return (
    <article className="card glass">
      <span className="num-badge">{n}</span>
      <h3>{title}</h3>
      <p>{children}</p>
    </article>
  );
}

/** A screenshot from the app, in the dark or light version to match the theme. */
export function ShotImages({ id, alt = "" }) {
  return (
    <>
      <img className="th-dk" src={`/shots/${id}-dark.webp`} alt={alt} decoding="async" loading="lazy" />
      <img className="th-lt" src={`/shots/${id}-light.webp`} alt={alt} decoding="async" loading="lazy" />
    </>
  );
}

export function Shot({ id, title, sub }) {
  return (
    <figure className="shot">
      <div className="frame glass">
        <div>
          <ShotImages id={id} alt={`${title} screen in the FindMeTricycle app`} />
        </div>
      </div>
      <figcaption>
        <b>{title}</b>
        <span>{sub}</span>
      </figcaption>
    </figure>
  );
}

/** Tilted glass phone cycling through three app screens. */
export function PhoneMock() {
  return (
    <div className="phone glass" aria-hidden="true">
      <div className="screen shots">
        {["p-home", "ride", "done"].map((id) => (
          <div className="shot-slide" key={id}>
            <ShotImages id={id} />
          </div>
        ))}
      </div>
    </div>
  );
}

/** Tinted notice with a glowing dot: info (lagoon), ok, warn, err. */
export function Alert({ tone = "info", title, children, style, checking = false }) {
  return (
    <div className={`alert ${tone}`} style={style} data-checking={checking || undefined} role={tone === "err" ? "alert" : undefined}>
      <span className="dot" />
      <div>
        {title ? <b>{title}</b> : null}
        {children}
      </div>
    </div>
  );
}

/* ---------- toasts ---------- */

const ToastContext = createContext(() => {});

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const nextId = useRef(1);

  const toast = useCallback((title, body = "", kind = "") => {
    const id = nextId.current++;
    setToasts((list) => [...list, { id, title, body, kind, leaving: false }]);
    setTimeout(() => {
      setToasts((list) => list.map((t) => (t.id === id ? { ...t, leaving: true } : t)));
      setTimeout(() => setToasts((list) => list.filter((t) => t.id !== id)), 400);
    }, 4200);
  }, []);

  return (
    <ToastContext.Provider value={toast}>
      {children}
      <div className="toasts" aria-live="polite">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={`toast glass ${t.kind}`}
            style={t.leaving ? { transition: "opacity .4s, transform .4s", opacity: 0, transform: "translateY(10px)" } : undefined}
          >
            <i />
            <div>
              <b>{t.title}</b>
              {t.body ? <span className="muted">{t.body}</span> : null}
            </div>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  return useContext(ToastContext);
}

/* ---------- modal ---------- */

/** Glass dialog over a blurred scrim; Escape or a click outside closes it. */
export function Modal({ onClose, children }) {
  const boxRef = useRef(null);
  useEffect(() => {
    const onKey = (e) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    const first = boxRef.current?.querySelector("input, button:not([data-close])");
    first?.focus();
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);

  return createPortal(
    <div className="modal" role="dialog" aria-modal="true" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="glass" ref={boxRef}>
        {children}
      </div>
    </div>,
    document.body
  );
}

export function ConfirmModal({ title, text, okLabel, danger = false, onOk, onClose }) {
  return (
    <Modal onClose={onClose}>
      <h3 style={{ fontSize: 22 }}>{title}</h3>
      <p className="muted" style={{ marginTop: 10 }}>
        {text}
      </p>
      <div className="row" style={{ marginTop: 22, justifyContent: "flex-end" }}>
        <button type="button" className="btn btn-glass" data-close onClick={onClose}>
          Cancel
        </button>
        <button
          type="button"
          className={`btn ${danger ? "btn-danger" : "btn-hot"}`}
          onClick={() => {
            onClose();
            onOk();
          }}
        >
          {okLabel}
        </button>
      </div>
    </Modal>
  );
}

/** Six one-digit boxes; typing moves on, Backspace moves back, a pasted code fills them all. */
export function OtpInputs({ digits, setDigits, onComplete, autoFocus = true }) {
  const refs = useRef([]);

  useEffect(() => {
    if (autoFocus) refs.current[0]?.focus();
  }, [autoFocus]);

  function update(next) {
    setDigits(next);
    if (next.every(Boolean)) onComplete?.(next.join(""));
  }

  return (
    <div className="otp">
      {digits.map((d, i) => (
        <input
          key={i}
          ref={(el) => (refs.current[i] = el)}
          inputMode="numeric"
          autoComplete={i === 0 ? "one-time-code" : "off"}
          maxLength={1}
          aria-label={`Digit ${i + 1}`}
          value={d}
          onChange={(e) => {
            const v = e.target.value.replace(/\D/g, "").slice(-1);
            const next = [...digits];
            next[i] = v;
            if (v && i < 5) refs.current[i + 1]?.focus();
            update(next);
          }}
          onKeyDown={(e) => {
            if (e.key === "Backspace" && !digits[i] && i > 0) refs.current[i - 1]?.focus();
          }}
          onPaste={(e) => {
            const t = (e.clipboardData.getData("text") || "").replace(/\D/g, "").slice(0, 6);
            if (!t) return;
            e.preventDefault();
            const next = [...digits];
            t.split("").forEach((c, j) => (next[j] = c));
            (refs.current[t.length] || refs.current[5])?.focus();
            update(next);
          }}
        />
      ))}
    </div>
  );
}

/** Catches a crash in one page so the site shows a message instead of a blank screen. */
export class PageErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { failed: false };
  }

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch(error) {
    console.error("Page crashed:", error);
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <section>
        <div className="wrap">
          <div className="form-card glass" style={{ textAlign: "center" }}>
            <h2>Something went wrong</h2>
            <p className="muted" style={{ marginTop: 8 }}>
              This page couldn&apos;t load. Reload it, and if it keeps happening, contact support.
            </p>
            <button type="button" className="btn btn-hot" style={{ marginTop: 20 }} onClick={() => window.location.reload()}>
              Reload
            </button>
          </div>
        </div>
      </section>
    );
  }
}
