import { resolveDriverDocumentUrl } from "../utils/admin-formatters";

function initials(name) {
  return String(name || "?")
    .split(" ")
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

export default function PendingDriversTable({
  drivers,
  onApprove,
  onReject,
  onView,
  actionLoadingId,
}) {
  function resolveAssetUrl(path) {
    return resolveDriverDocumentUrl(path) || "#";
  }

  return (
    <section className="panel">
      <div className="panel-header">
        <div>
          <p className="panel-label">Approvals</p>
          <h3>Pending Driver Registrations</h3>
        </div>
        <span className="status-pill status-warning">{drivers.length} waiting</span>
      </div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Phone</th>
              <th>Tricycle #</th>
              <th>License Expiry</th>
              <th>License</th>
              <th>Permit</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {drivers.length === 0 ? (
              <tr>
                <td colSpan="7">No pending drivers.</td>
              </tr>
            ) : (
              drivers.map((driver) => (
                <tr key={driver.id}>
                  <td>
                    <div className="who">
                      <span className="avatar" aria-hidden="true">{initials(driver.full_name)}</span>
                      <div>
                        <b>{driver.full_name}</b>
                        <small>{driver.email || "-"}</small>
                      </div>
                    </div>
                  </td>
                  <td>{driver.phone}</td>
                  <td>{driver.tricycle_number}</td>
                  <td>{driver.license_expires_at ? new Date(driver.license_expires_at).toLocaleDateString() : "-"}</td>
                  <td>
                    <a href={resolveAssetUrl(driver.license_image_url)} target="_blank" rel="noreferrer">
                      View
                    </a>
                  </td>
                  <td>
                    <a href={resolveAssetUrl(driver.business_permit_image_url)} target="_blank" rel="noreferrer">
                      View
                    </a>
                  </td>
                  <td className="inline-actions">
                    <button
                      onClick={() => onView(driver.id)}
                      className="btn-ghost"
                    >
                      View
                    </button>
                    <button
                      disabled={actionLoadingId === driver.id}
                      onClick={() => onApprove(driver.id)}
                      className="btn-success"
                    >
                      Approve
                    </button>
                    <button
                      disabled={actionLoadingId === driver.id}
                      onClick={() => onReject(driver.id)}
                      className="btn-danger"
                    >
                      Reject
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
