import { useMemo, useState } from "react";
import { apiClient } from "../api/client";
import { formatDateTime } from "../utils/admin-formatters";
import { shortTime } from "../utils/notification-meta";
import InboxLayout, { Field, InboxRow, InboxToolbar, RelatedCard } from "./InboxLayout";

const STATUS_PILL = { open: "warning", replied: "success", closed: "neutral" };

/**
 * Contact Support: messages sent from the website's Contact page,
 * Gmail-style. Opening one shows the message and every reply so far; a
 * reply written here is emailed to the address the person wrote from.
 */
// [canReply]: whether this admin may reply to, close or reopen messages.
export default function SupportInbox({ messages = [], selectedId = null, onSelect, canReply = true, onChanged }) {
  const [filter, setFilter] = useState("all");
  const [search, setSearch] = useState("");

  const openCount = messages.filter((m) => m.status === "open").length;
  const visible = useMemo(() => {
    const term = search.trim().toLowerCase();
    return messages.filter((m) => {
      if (filter !== "all" && m.status !== filter) return false;
      if (!term) return true;
      return [m.name, m.email, m.subject, m.message].some((v) => String(v ?? "").toLowerCase().includes(term));
    });
  }, [messages, filter, search]);

  const selected = messages.find((m) => m.id === selectedId) || null;

  return (
    <InboxLayout
      placeholder="Select a message to read it."
      toolbar={
        <InboxToolbar
          search={search}
          onSearch={setSearch}
          searchPlaceholder="Search by name, email, subject or message"
          tabs={[
            { key: "all", label: "All" },
            { key: "open", label: `Open${openCount ? ` (${openCount})` : ""}` },
            { key: "replied", label: "Replied" },
            { key: "closed", label: "Closed" },
          ]}
          activeTab={filter}
          onTab={setFilter}
        />
      }
      reading={
        selected ? (
          <MessageReader
            key={selected.id}
            message={selected}
            onBack={() => onSelect?.(null)}
            canReply={canReply}
            onChanged={onChanged}
          />
        ) : null
      }
    >
      {visible.length === 0 ? (
        <div className="state-block">{messages.length === 0 ? "No messages yet." : "Nothing matches."}</div>
      ) : (
        <ul className="inbox-rows">
          {visible.map((m) => (
            <InboxRow
              key={m.id}
              unread={m.status === "open"}
              selected={m.id === selectedId}
              icon={m.status === "open" ? "✉️" : m.status === "replied" ? "↩️" : "✅"}
              title={`${m.subject || "No subject"} · ${m.name}`}
              snippet={m.message}
              time={shortTime(m.createdAt)}
              onClick={() => onSelect?.(m)}
            />
          ))}
        </ul>
      )}
    </InboxLayout>
  );
}

function errorMessage(err, fallback) {
  return err?.response?.data?.details?.issues?.[0]?.message || err?.response?.data?.message || fallback;
}

function MessageReader({ message, onBack, canReply, onChanged }) {
  const [reply, setReply] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState(null);

  async function sendReply() {
    if (!reply.trim()) return;
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await apiClient.post(`/admin/contact-messages/${message.id}/reply`, { message: reply.trim() });
      setReply("");
      setNotice(`Reply emailed to ${message.email}.`);
      await onChanged?.();
    } catch (err) {
      setError(errorMessage(err, "Couldn't send the reply."));
    } finally {
      setBusy(false);
    }
  }

  async function setStatus(status) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await apiClient.post(`/admin/contact-messages/${message.id}/status`, { status });
      await onChanged?.();
    } catch (err) {
      setError(errorMessage(err, "Couldn't update the message."));
    } finally {
      setBusy(false);
    }
  }

  const isClosed = message.status === "closed";

  return (
    <article className="reader">
      <button type="button" className="btn btn-ghost btn-sm reader-back" onClick={onBack}>
        ← Back to messages
      </button>
      <div className="reader-tags">
        <span className="reader-category">
          <span aria-hidden="true">✉️</span>
          Contact message
        </span>
        <span className={`status-pill status-${STATUS_PILL[message.status] || "neutral"}`}>{message.status}</span>
      </div>
      <h2 className="reader-title">{message.subject || "No subject"}</h2>
      <div className="reader-date">
        From <strong>{message.name}</strong> · <a href={`mailto:${message.email}`}>{message.email}</a> ·{" "}
        {formatDateTime(message.createdAt)}
      </div>
      <p className="reader-body" style={{ whiteSpace: "pre-wrap" }}>
        {message.message}
      </p>

      {message.replies.map((r) => (
        <RelatedCard key={r.id} title={`Reply by ${r.adminName} · ${formatDateTime(r.createdAt)}`}>
          <p style={{ margin: 0, whiteSpace: "pre-wrap" }}>{r.body}</p>
        </RelatedCard>
      ))}

      {!message.replies.length ? (
        <RelatedCard title="Details">
          <Field label="Name" value={message.name} />
          <Field label="Email" value={message.email} />
          <Field label="Replies" value="None yet" />
        </RelatedCard>
      ) : null}

      {canReply && !isClosed ? (
        <>
          <textarea
            className="reader-note"
            rows={5}
            maxLength={5000}
            placeholder={`Write your reply — it will be emailed to ${message.email}.`}
            value={reply}
            onChange={(e) => setReply(e.target.value)}
          />
        </>
      ) : null}
      {error ? <div className="error-banner" style={{ marginTop: 12 }}>{error}</div> : null}
      {notice ? <div className="muted" style={{ marginTop: 12 }}>{notice}</div> : null}

      {canReply ? (
        <div className="reader-actions">
          {!isClosed ? (
            <>
              <button type="button" className="btn btn-success btn-sm" disabled={busy || !reply.trim()} onClick={sendReply}>
                {busy ? "Sending…" : "Send reply"}
              </button>
              <button type="button" className="btn btn-ghost btn-sm" disabled={busy} onClick={() => setStatus("closed")}>
                Close
              </button>
            </>
          ) : (
            <button type="button" className="btn btn-ghost btn-sm" disabled={busy} onClick={() => setStatus("open")}>
              Reopen
            </button>
          )}
        </div>
      ) : null}
    </article>
  );
}
