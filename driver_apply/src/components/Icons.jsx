// Line icons from the Prism Night design (24 px grid, currentColor).
const base = { viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeLinecap: "round", "aria-hidden": true };

export const ICON = {
  trike: (
    <svg {...base} strokeWidth="2.2" strokeLinejoin="round">
      <circle cx="6" cy="17" r="2.5" />
      <circle cx="18" cy="17" r="2.5" />
      <path d="M8.5 17h7M4 13V8a2 2 0 0 1 2-2h6l3 5h3a2 2 0 0 1 2 2v1.5" />
    </svg>
  ),
  pin: (
    <svg {...base} strokeWidth="2">
      <path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z" />
      <circle cx="12" cy="10" r="2.5" />
    </svg>
  ),
  cash: (
    <svg {...base} strokeWidth="2">
      <rect x="3" y="6" width="18" height="12" rx="2" />
      <circle cx="12" cy="12" r="2.5" />
    </svg>
  ),
  shield: (
    <svg {...base} strokeWidth="2" strokeLinejoin="round">
      <path d="M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6z" />
      <path d="M9 12l2 2 4-4" />
    </svg>
  ),
  user: (
    <svg {...base} strokeWidth="2">
      <circle cx="12" cy="8" r="4" />
      <path d="M4 21a8 8 0 0 1 16 0" />
    </svg>
  ),
  clock: (
    <svg {...base} strokeWidth="2">
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </svg>
  ),
  check: (
    <svg {...base} strokeWidth="2.6" strokeLinejoin="round">
      <path d="M5 12l5 5L20 7" />
    </svg>
  ),
  x: (
    <svg {...base} strokeWidth="2.6">
      <path d="M6 6l12 12M18 6L6 18" />
    </svg>
  ),
  edit: (
    <svg {...base} strokeWidth="2.2" strokeLinejoin="round" width="14" height="14">
      <path d="M4 20h4L19 9l-4-4L4 16z" />
    </svg>
  ),
  doc: (
    <svg {...base} strokeWidth="2">
      <path d="M6 3h9l4 4v14H6z" />
      <path d="M9 12h7M9 16h5" />
    </svg>
  ),
  card: (
    <svg {...base} strokeWidth="2">
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <circle cx="9" cy="11" r="2" />
      <path d="M14 10h4M14 14h4" />
    </svg>
  ),
  phone: (
    <svg {...base} strokeWidth="2">
      <rect x="6" y="2" width="12" height="20" rx="3" />
      <path d="M11 18h2" />
    </svg>
  ),
  mail: (
    <svg {...base} strokeWidth="2">
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <path d="M3 7l9 6 9-6" />
    </svg>
  ),
  arrow: (
    <svg {...base} strokeWidth="2.4">
      <path d="M5 12h14M13 6l6 6-6 6" />
    </svg>
  ),
  alert: (
    <svg {...base} strokeWidth="2.2">
      <path d="M12 3l10 18H2z" />
      <path d="M12 10v5M12 18h.01" />
    </svg>
  ),
  eye: (
    <svg {...base} strokeWidth="1.8" strokeLinejoin="round">
      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  ),
  eyeOff: (
    <svg {...base} strokeWidth="1.8" strokeLinejoin="round">
      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
      <circle cx="12" cy="12" r="3" />
      <path d="M3 21L21 3" />
    </svg>
  ),
};

/** The logo mark: a tricycle on the prism tile. */
export function MarkIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="6" cy="17" r="2.5" />
      <circle cx="18" cy="17" r="2.5" />
      <path d="M8.5 17h7M4 13V8a2 2 0 0 1 2-2h6l3 5h3.5a2 2 0 0 1 2 2v2" />
      <path d="M12 6v5h3" />
    </svg>
  );
}
