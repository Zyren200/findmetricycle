import { useCallback, useEffect, useState } from "react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";
import { formatDateTime } from "../utils/admin-formatters";

const AUDIENCES = [
  { value: "everyone", label: "Everyone (passengers & drivers)" },
  { value: "passenger", label: "Passengers only" },
  { value: "driver", label: "Drivers only" },
];

const audienceLabel = (value) => AUDIENCES.find((a) => a.value === value)?.label || value;

/// Broadcast an announcement to the mobile apps. It appears in the
/// Notifications list of every targeted user and arrives live for anyone
/// currently connected.
export default function AnnouncementsPage() {
  const [form, setForm] = useState({ title: "", body: "", audience: "everyone" });
  const [sending, setSending] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);

  const loadHistory = useCallback(async () => {
    try {
      const { data } = await apiClient.get("/admin/announcements");
      setHistory(Array.isArray(data?.data) ? data.data : []);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load announcements.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadHistory();
  }, [loadHistory]);

  async function handleSend(e) {
    e.preventDefault();
    const title = form.title.trim();
    const body = form.body.trim();
    if (!title || !body) {
      setError("Please enter a title and a message.");
      return;
    }
    if (!window.confirm(`Send this announcement to ${audienceLabel(form.audience).toLowerCase()}?`)) return;

    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      await apiClient.post("/admin/announcements", { title, body, audience: form.audience });
      setSuccess("Announcement sent.");
      setForm({ title: "", body: "", audience: form.audience });
      await loadHistory();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to send the announcement.");
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="page-stack">
      <PageHero
        eyebrow="Broadcast"
        title="Announcements"
        description="Send a message to passengers, drivers, or everyone. It appears in their app's notifications."
      />

      {error ? <div className="error-banner">{error}</div> : null}
      {success ? <div className="success-banner">{success}</div> : null}

      <section className="panel">
        <div className="panel-header">
          <h3>New announcement</h3>
        </div>
        <form onSubmit={handleSend} style={{ display: "grid", gap: 14, marginTop: 12 }}>
          <label style={{ display: "grid", gap: 6 }}>
            <span className="muted">Send to</span>
            <select
              className="input"
              value={form.audience}
              onChange={(e) => setForm((f) => ({ ...f, audience: e.target.value }))}
            >
              {AUDIENCES.map((a) => (
                <option key={a.value} value={a.value}>
                  {a.label}
                </option>
              ))}
            </select>
          </label>
          <label style={{ display: "grid", gap: 6 }}>
            <span className="muted">Title</span>
            <input
              className="input"
              maxLength={150}
              value={form.title}
              onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
              placeholder="e.g. Service advisory"
            />
          </label>
          <label style={{ display: "grid", gap: 6 }}>
            <span className="muted">Message</span>
            <textarea
              className="input"
              rows={4}
              maxLength={1000}
              value={form.body}
              onChange={(e) => setForm((f) => ({ ...f, body: e.target.value }))}
              placeholder="What do you want to tell them?"
              style={{ resize: "vertical", minHeight: 96 }}
            />
            <small className="muted">{form.body.length}/1000</small>
          </label>
          <div>
            <button type="submit" className="btn btn-primary" disabled={sending}>
              {sending ? "Sending..." : "Send Announcement"}
            </button>
          </div>
        </form>
      </section>

      <section className="panel">
        <div className="panel-header">
          <h3>Sent announcements</h3>
        </div>
        {loading ? (
          <div className="state-block">Loading...</div>
        ) : (
          <div className="table-wrap">
            <table className="compact-table">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Message</th>
                  <th>Sent to</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                {history.length === 0 ? (
                  <tr>
                    <td colSpan={4}>No announcements sent yet.</td>
                  </tr>
                ) : (
                  history.map((row) => (
                    <tr key={row.id}>
                      <td><b>{row.title}</b></td>
                      <td style={{ whiteSpace: "pre-wrap" }}>{row.body}</td>
                      <td>{audienceLabel(row.recipientRole)}</td>
                      <td>{formatDateTime(row.createdAt)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
