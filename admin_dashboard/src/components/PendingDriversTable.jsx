import StatusPill from "./StatusPill";
import { hasDocumentWarning } from "./DocumentCheckBadge";
import { formatDateTime } from "../utils/admin-formatters";

export const APPLICATION_STATUS = {
  pending: ["Pending review", "warning"],
  needs_correction: ["Needs correction", "info"],
  rejected: ["Rejected", "danger"],
  approved: ["Approved", "success"],
};

function initials(name) {
  return String(name || "?")
    .split(" ")
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

function DocumentsSummary({ application }) {
  if (!application.documents_checked_at) {
    return <StatusPill label="Checking…" tone="neutral" />;
  }
  if (!hasDocumentWarning(application.license_check_status, application.permit_check_status)) {
    return <StatusPill label="✓ Documents look right" tone="success" />;
  }
  const bad = [
    application.license_check_status !== "verified" ? "license" : null,
    application.permit_check_status !== "verified" ? "permit" : null,
  ].filter(Boolean);
  return <StatusPill label={`⚠ Check ${bad.join(" & ")}`} tone="danger" />;
}

/** Application list; every decision happens in the review dialog. */
export default function PendingDriversTable({ applications, onReview, emptyText }) {
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Applicant</th>
            <th>Plate #</th>
            <th>Submitted</th>
            <th>Documents</th>
            <th>Status</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {applications.length === 0 ? (
            <tr>
              <td colSpan="6">{emptyText}</td>
            </tr>
          ) : (
            applications.map((app) => {
              const [statusLabel, statusTone] = APPLICATION_STATUS[app.status] || [app.status, "neutral"];
              return (
                <tr key={app.id}>
                  <td>
                    <div className="who">
                      <span className="avatar" aria-hidden="true">{initials(app.full_name)}</span>
                      <div>
                        <b>{app.full_name}</b>
                        <small>{app.phone || app.email || "-"}</small>
                      </div>
                    </div>
                  </td>
                  <td style={{ fontFamily: "monospace", fontSize: 12 }}>{app.plate_number || "-"}</td>
                  <td>{formatDateTime(app.submitted_at)}</td>
                  <td><DocumentsSummary application={app} /></td>
                  <td><StatusPill label={statusLabel} tone={statusTone} /></td>
                  <td>
                    <button type="button" className="btn btn-ghost btn-sm" onClick={() => onReview(app.id)}>
                      {app.status === "pending" ? "Review" : "View"}
                    </button>
                  </td>
                </tr>
              );
            })
          )}
        </tbody>
      </table>
    </div>
  );
}
