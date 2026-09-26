import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";
import { formatDateTime } from "../utils/admin-formatters";

export default function ActivityLogsPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [logs, setLogs] = useState([]);

  const loadActivityLogs = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/activity-logs?limit=200");
      setLogs(Array.isArray(data?.data) ? data.data : []);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load activity logs.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadActivityLogs();
  }, [loadActivityLogs]);

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Audit trail"
        title="Activity Logs"
        description="Complete record of all admin actions for compliance and auditing."
        actions={
          <button type="button" className="ghost-btn" onClick={loadActivityLogs}>
            Refresh
          </button>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {loading ? <div className="state-block">Loading activity logs...</div> : null}

      {!loading ? (
        <section className="panel">
          <div className="panel-header">
            <h3>Action History</h3>
            <span className="badge plain">{logs.length} records</span>
          </div>
          {logs.length === 0 ? (
            <div className="state-block">No activity logs found.</div>
          ) : (
            <div className="table-wrap">
              <table className="compact-table">
                <thead>
                  <tr>
                    <th>Timestamp</th>
                    <th>Admin</th>
                    <th>Action</th>
                    <th>Target</th>
                  </tr>
                </thead>
                <tbody>
                  {logs.map((log) => (
                    <tr key={log.id}>
                      <td className="monospace">{formatDateTime(log.timestamp)}</td>
                      <td>{log.adminName || "System"}</td>
                      <td><strong>{log.action}</strong></td>
                      <td className="muted">{log.targetUserName || "-"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      ) : null}
    </div>
  );
}
