import { useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import { formatDateTime } from "../utils/admin-formatters";
import { shortTime } from "../utils/notification-meta";
import BookingCard from "./BookingCard";
import InboxLayout, { Field, InboxRow, InboxToolbar, RelatedCard } from "./InboxLayout";

const STATUS_PILL = { open: "warning", resolved: "success", dismissed: "neutral" };

function categoryLabel(category) {
  const text = String(category || "other").replace(/_/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/**
 * Passenger and driver reports, Gmail-style: open ones stand out in the
 * list; opening one shows the whole report, who sent it, the ride it's
 * about, and lets the admin resolve or dismiss it with a note.
 */
// [canResolve]: whether this admin may resolve or dismiss reports.
// [onOpenBooking] is left out for admins who can't open bookings.
export default function ReportsInbox({ complaints = [], selectedId = null, onSelect, onOpenBooking, canResolve = true, onChanged }) {
  const [filter, setFilter] = useState("all");
  const [search, setSearch] = useState("");

  const openCount = complaints.filter((c) => c.status === "open").length;
  const visible = useMemo(() => {
    const term = search.trim().toLowerCase();
    return complaints.filter((c) => {
      if (filter === "open" && c.status !== "open") return false;
      if (filter === "closed" && c.status === "open") return false;
      if (!term) return true;
      return [c.reporter, c.reportedUser, c.category, c.description, c.rideId && `#${c.rideId}`].some((v) =>
        String(v ?? "").toLowerCase().includes(term)
      );
    });
  }, [complaints, filter, search]);

  const selected = complaints.find((c) => c.id === selectedId) || null;

  return (
    <InboxLayout
      placeholder="Select a report to read it."
      toolbar={
        <InboxToolbar
          search={search}
          onSearch={setSearch}
          searchPlaceholder="Search by reporter, category, details or ride #"
          tabs={[
            { key: "all", label: "All" },
            { key: "open", label: `Open${openCount ? ` (${openCount})` : ""}` },
            { key: "closed", label: "Closed" },
          ]}
          activeTab={filter}
          onTab={setFilter}
        />
      }
      reading={
        selected ? (
          <ReportReader
            key={selected.id}
            report={selected}
            onBack={() => onSelect?.(null)}
            onOpenBooking={onOpenBooking}
            canResolve={canResolve}
            onChanged={onChanged}
          />
        ) : null
      }
    >
      {visible.length === 0 ? (
        <div className="state-block">{complaints.length === 0 ? "No reports yet." : "Nothing matches."}</div>
      ) : (
        <ul className="inbox-rows">
          {visible.map((c) => (
            <InboxRow
              key={c.id}
              unread={c.status === "open"}
              selected={c.id === selectedId}
              icon={c.status === "open" ? "📝" : "✅"}
              title={`${categoryLabel(c.category)} · ${c.reporter}`}
              snippet={c.description}
              time={shortTime(c.createdAt)}
              onClick={() => onSelect?.(c)}
            />
          ))}
        </ul>
      )}
    </InboxLayout>
  );
}

function ReportReader({ report, onBack, onOpenBooking, canResolve, onChanged }) {
  const [booking, setBooking] = useState({ status: "idle", data: null });
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!report.rideId) {
      setBooking({ status: "idle", data: null });
      return undefined;
    }
    let cancelled = false;
    setBooking({ status: "loading", data: null });
    apiClient
      .get(`/admin/bookings/${report.rideId}`)
      .then(({ data }) => !cancelled && setBooking({ status: "ready", data: data?.data || null }))
      .catch(() => !cancelled && setBooking({ status: "error", data: null }));
    return () => {
      cancelled = true;
    };
  }, [report.rideId]);

  async function close(status) {
    setBusy(true);
    setError(null);
    try {
      const { data } = await apiClient.post(`/admin/complaints/${report.id}/resolve`, {
        status,
        ...(note.trim() ? { note: note.trim() } : {}),
      });
      setNote("");
      await onChanged?.(data?.data);
    } catch (err) {
      setError(err?.response?.data?.details?.issues?.[0]?.message || err?.response?.data?.message || "Couldn't update the report.");
    } finally {
      setBusy(false);
    }
  }

  const isOpen = report.status === "open";

  return (
    <article className="reader">
      <button type="button" className="btn btn-ghost btn-sm reader-back" onClick={onBack}>
        ← Back to reports
      </button>
      <div className="reader-tags">
        <span className="reader-category">
          <span aria-hidden="true">📝</span>
          {categoryLabel(report.category)}
        </span>
        <span className={`status-pill status-${STATUS_PILL[report.status] || "neutral"}`}>{report.status}</span>
      </div>
      <h2 className="reader-title">Report #{report.id}</h2>
      <div className="reader-date">
        From <strong>{report.reporter}</strong>
        {report.reporterPhone ? ` · ${report.reporterPhone}` : ""} · {formatDateTime(report.createdAt)}
      </div>
      <p className="reader-body">{report.description || "(No details)"}</p>

      <RelatedCard title="Details">
        <Field label="Category" value={categoryLabel(report.category)} />
        <Field label="Reported by" value={report.reporter} />
        <Field label="Contact" value={report.reporterPhone} />
        <Field label="About" value={report.reportedUser} />
        <Field label="Ride" value={report.rideId ? `#${report.rideId}` : null} />
      </RelatedCard>

      {booking.status === "loading" ? <div className="reader-related muted">Loading the ride…</div> : null}
      {booking.status === "error" ? <div className="reader-related muted">Couldn&apos;t load ride #{report.rideId}.</div> : null}
      {booking.status === "ready" && booking.data ? <BookingCard booking={booking.data} /> : null}

      {!isOpen ? (
        <RelatedCard title={report.status === "dismissed" ? "Dismissed" : "Resolved"}>
          <Field label="When" value={formatDateTime(report.resolvedAt)} />
          <Field label="By" value={report.resolvedByName} />
          <Field label="Note" value={report.resolutionNote || "No note added."} />
        </RelatedCard>
      ) : null}

      {isOpen && canResolve ? (
        <textarea
          className="reader-note"
          rows={3}
          maxLength={1000}
          placeholder="Note on what was done (optional) — e.g. Called the passenger; driver warned."
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      ) : null}
      {error ? <div className="error-banner" style={{ marginTop: 12 }}>{error}</div> : null}

      <div className="reader-actions">
        {isOpen && canResolve ? (
          <>
            <button type="button" className="btn btn-success btn-sm" disabled={busy} onClick={() => close("resolved")}>
              {busy ? "Saving…" : "Resolve"}
            </button>
            <button type="button" className="btn btn-ghost btn-sm" disabled={busy} onClick={() => close("dismissed")}>
              Dismiss
            </button>
          </>
        ) : null}
        {report.rideId && onOpenBooking ? (
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => onOpenBooking(report.rideId)}>
            Open booking #{report.rideId}
          </button>
        ) : null}
      </div>
    </article>
  );
}
