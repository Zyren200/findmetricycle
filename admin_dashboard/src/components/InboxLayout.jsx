/**
 * Gmail-style two-pane layout shared by the Notifications and Reports
 * inboxes: a list on the left, the open item on the right. On narrow
 * screens the two take turns (the reader shows a back button).
 */
export default function InboxLayout({ toolbar, reading, placeholder = "Select an item to read it.", children }) {
  return (
    <div className={`inbox ${reading ? "inbox-reading" : ""}`}>
      <section className="inbox-list panel">
        {toolbar ? <div className="inbox-toolbar">{toolbar}</div> : null}
        {children}
      </section>
      <section className="inbox-pane panel">
        {reading || (
          <div className="inbox-empty">
            <span aria-hidden="true">📬</span>
            <p>{placeholder}</p>
          </div>
        )}
      </section>
      <style>{INBOX_CSS}</style>
    </div>
  );
}

/** Search box plus filter tabs, with an optional action on the right. */
export function InboxToolbar({ search, onSearch, searchPlaceholder, tabs, activeTab, onTab, action }) {
  return (
    <>
      <input
        type="search"
        className="inbox-search"
        placeholder={searchPlaceholder}
        value={search}
        onChange={(e) => onSearch(e.target.value)}
      />
      <div className="inbox-tabs" role="tablist">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            type="button"
            role="tab"
            aria-selected={activeTab === tab.key}
            className={activeTab === tab.key ? "active" : ""}
            onClick={() => onTab(tab.key)}
          >
            {tab.label}
          </button>
        ))}
        {action}
      </div>
    </>
  );
}

/** One list row: unread dot, icon, title, one-line snippet and time. */
export function InboxRow({ unread, selected, icon, title, snippet, time, onClick }) {
  return (
    <li>
      <button
        type="button"
        className={`inbox-row ${unread ? "unread" : ""} ${selected ? "selected" : ""}`}
        onClick={onClick}
      >
        <span className="inbox-dot" aria-label={unread ? "unread" : undefined} />
        <span className="inbox-icon" aria-hidden="true">{icon}</span>
        <span className="inbox-text">
          <span className="inbox-title">{title}</span>
          <span className="inbox-snippet">{snippet}</span>
        </span>
        <span className="inbox-time">{time}</span>
      </button>
    </li>
  );
}

/** A labelled box of details in the reader. */
export function RelatedCard({ title, children }) {
  return (
    <div className="reader-related">
      <h4>{title}</h4>
      <dl>{children}</dl>
    </div>
  );
}

/** One label/value line in a RelatedCard; hidden when there's no value. */
export function Field({ label, value }) {
  if (value === null || value === undefined || value === "" || value === "-") return null;
  return (
    <>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </>
  );
}

const INBOX_CSS = `
  .inbox {
    display: grid;
    grid-template-columns: minmax(280px, 380px) 1fr;
    gap: 1rem;
    align-items: start;
  }
  .inbox .panel { padding: 0; overflow: hidden; }
  .inbox-toolbar {
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
    padding: 12px;
    border-bottom: 1px solid var(--border);
  }
  .inbox-search {
    width: 100%;
    padding: 0.55rem 0.75rem;
    border: 1px solid var(--border);
    border-radius: 0.5rem;
    background: var(--input-bg);
    color: var(--text);
  }
  .inbox-tabs { display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
  .inbox-tabs button {
    padding: 4px 12px;
    border-radius: 999px;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--muted);
    font-size: 13px;
    cursor: pointer;
  }
  .inbox-tabs button.active { background: var(--accent); border-color: var(--accent); color: var(--on-accent, #fff); }
  .inbox-tabs .inbox-action { margin-left: auto; border: none; color: var(--accent); }
  .inbox-tabs .inbox-action:disabled { color: var(--muted); cursor: default; }
  .inbox-rows { list-style: none; margin: 0; padding: 0; max-height: 70vh; overflow-y: auto; }
  .inbox-row {
    width: 100%;
    display: grid;
    grid-template-columns: 8px 22px 1fr auto;
    gap: 10px;
    align-items: start;
    padding: 12px 14px;
    border: none;
    border-bottom: 1px solid var(--border);
    background: transparent;
    color: var(--text);
    text-align: left;
    cursor: pointer;
  }
  .inbox-row:hover { background: var(--bg2); }
  .inbox-row.selected { background: var(--tint, rgba(6, 182, 212, 0.08)); }
  .inbox-dot { width: 8px; height: 8px; margin-top: 6px; border-radius: 50%; }
  .inbox-row.unread .inbox-dot { background: var(--accent); }
  .inbox-icon { font-size: 15px; line-height: 1.3; }
  .inbox-text { display: flex; flex-direction: column; min-width: 0; }
  .inbox-title { font-size: 13px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .inbox-row.unread .inbox-title { font-weight: 700; }
  .inbox-snippet {
    font-size: 12px;
    color: var(--muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .inbox-time { font-size: 11px; color: var(--muted); white-space: nowrap; }
  .inbox-row.unread .inbox-time { color: var(--text); font-weight: 600; }
  .inbox-pane { min-height: 320px; }
  .inbox-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    min-height: 320px;
    color: var(--muted);
    font-size: 14px;
  }
  .inbox-empty span { font-size: 32px; }
  .reader { padding: 20px 24px 24px; }
  .reader-back { display: none; margin-bottom: 12px; }
  .reader-tags { display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
  .reader-category {
    display: inline-flex;
    gap: 6px;
    align-items: center;
    padding: 3px 10px;
    border-radius: 999px;
    background: var(--bg2);
    color: var(--muted);
    font-size: 12px;
  }
  .reader-title { margin: 12px 0 4px; font-size: 20px; line-height: 1.3; color: var(--text-strong, var(--text)); }
  .reader-date { color: var(--muted); font-size: 12px; }
  .reader-body { margin: 16px 0 0; font-size: 14px; line-height: 1.6; white-space: pre-wrap; overflow-wrap: anywhere; }
  .reader-related {
    margin-top: 20px;
    padding: 14px 16px;
    border: 1px solid var(--border);
    border-radius: 0.6rem;
    background: var(--bg2);
  }
  .reader-related h4 { margin: 0 0 10px; font-size: 13px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.04em; }
  .reader-related dl { display: grid; grid-template-columns: max-content 1fr; gap: 6px 16px; margin: 0; font-size: 13px; }
  .reader-related dt { color: var(--muted); }
  .reader-related dd { margin: 0; overflow-wrap: anywhere; white-space: pre-wrap; }
  .reader-related a { color: var(--accent); }
  .reader-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 16px; }
  .reader-note {
    width: 100%;
    margin-top: 16px;
    padding: 0.6rem 0.75rem;
    border: 1px solid var(--border);
    border-radius: 0.5rem;
    background: var(--input-bg);
    color: var(--text);
    resize: vertical;
    font: inherit;
    font-size: 13px;
  }
  @media (max-width: 900px) {
    .inbox { grid-template-columns: 1fr; }
    .inbox .inbox-pane { display: none; }
    .inbox.inbox-reading .inbox-list { display: none; }
    .inbox.inbox-reading .inbox-pane { display: block; }
    .reader-back { display: inline-flex; }
  }
`;
