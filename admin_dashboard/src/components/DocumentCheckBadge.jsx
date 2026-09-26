import StatusPill from "./StatusPill";

// Result of the server-side document check (OCR of the uploaded photo).
const LABELS = {
  license: {
    verified: ["✓ Looks like a driver's license", "success"],
    suspicious: ["⚠ Doesn't look like a driver's license", "danger"],
    unreadable: ["⚠ Unreadable — not a clear license photo", "warning"],
    error: ["Couldn't be checked", "neutral"],
  },
  permit: {
    verified: ["✓ Looks like a franchise / permit", "success"],
    suspicious: ["⚠ Doesn't look like a franchise / permit", "danger"],
    unreadable: ["⚠ Unreadable — not a clear permit photo", "warning"],
    error: ["Couldn't be checked", "neutral"],
  },
};

export default function DocumentCheckBadge({ kind, status }) {
  const [label, tone] = LABELS[kind]?.[status] || ["Not checked yet", "neutral"];
  return <StatusPill label={label} tone={tone} />;
}

/** True when either document didn't pass (or wasn't checked). */
export function hasDocumentWarning(licenseStatus, permitStatus) {
  return licenseStatus !== "verified" || permitStatus !== "verified";
}
