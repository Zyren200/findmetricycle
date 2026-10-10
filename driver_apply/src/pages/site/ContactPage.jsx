import { useState } from "react";
import { apiClient } from "../../api/client";
import { config } from "../../config";
import { ICON } from "../../components/Icons";
import { Alert, Head, useToast } from "../../components/ui";
import { useDocumentTitle } from "../../router";

const TOPICS = ["Driver application", "Booking a ride", "Safety concern", "Other"];
// [hpTrap] is a hidden field only bots fill in; its name means nothing to
// browser autofill, which must never fill it.
const EMPTY = { name: "", email: "", topic: TOPICS[0], message: "", hpTrap: "" };

export default function ContactPage() {
  useDocumentTitle("FindMeTricycle · Contact");
  const toast = useToast();
  const [form, setForm] = useState(EMPTY);
  const [error, setError] = useState("");
  const [sentTo, setSentTo] = useState("");
  const [sending, setSending] = useState(false);

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }));

  // The message goes to the admin's Contact Support inbox; the reply is
  // emailed to the address given here.
  async function handleSubmit(e) {
    e.preventDefault();
    const name = form.name.trim();
    const email = form.email.trim();
    const message = form.message.trim();
    if (!name || !/^\S+@\S+\.\S+$/.test(email) || !message) {
      setError("Fill in your name, a valid email and your message.");
      return;
    }
    setError("");
    setSending(true);
    try {
      await apiClient.post("/contact", { name, email, subject: form.topic, message, hpTrap: form.hpTrap });
      setSentTo(email);
      setForm(EMPTY);
      toast("Message sent", `We'll reply to ${email}.`);
    } catch (err) {
      setError(
        err?.response?.data?.details?.issues?.[0]?.message ||
          err?.response?.data?.message ||
          "Couldn't send your message. Please check your connection and try again."
      );
    } finally {
      setSending(false);
    }
  }

  function copyEmail() {
    const done = () => toast("Copied", config.contactEmail);
    try {
      navigator.clipboard.writeText(config.contactEmail).then(done, () =>
        toast("Copy not allowed here", "Select the address and copy it manually.")
      );
    } catch {
      toast("Copy not allowed here");
    }
  }

  return (
    <section>
      <div className="wrap">
        <Head eyebrow="Contact" title="Get in touch." sub="Questions, concerns or feedback? We reply within 1 to 2 business days." />
        <div className="grid g2">
          {sentTo ? (
            <div className="card glass stack">
              <Alert tone="ok" title="Message sent">
                Thank you! Our support team will reply to <b style={{ display: "inline", margin: 0 }}>{sentTo}</b>. Check
                your inbox, and your spam folder too.
              </Alert>
              <button type="button" className="btn btn-glass" onClick={() => setSentTo("")}>
                Write another message
              </button>
            </div>
          ) : (
            <form className="card glass stack" onSubmit={handleSubmit} noValidate>
              <div className="fld">
                <label htmlFor="cName">Your name</label>
                <input id="cName" autoComplete="name" maxLength={120} value={form.name} onChange={set("name")} required />
              </div>
              <div className="fld">
                <label htmlFor="cEmail">Your email</label>
                <input id="cEmail" type="email" autoComplete="email" maxLength={190} value={form.email} onChange={set("email")} required />
              </div>
              <div className="fld">
                <label htmlFor="cTopic">Topic</label>
                <select id="cTopic" value={form.topic} onChange={set("topic")}>
                  {TOPICS.map((t) => (
                    <option key={t}>{t}</option>
                  ))}
                </select>
              </div>
              <div className="fld">
                <label htmlFor="cMsg">Message</label>
                <textarea id="cMsg" maxLength={5000} value={form.message} onChange={set("message")} required />
              </div>
              {/* Hidden from people; only bots fill it in. */}
              <input
                type="text"
                name="fmt_hp_check"
                value={form.hpTrap}
                onChange={set("hpTrap")}
                tabIndex={-1}
                autoComplete="off"
                aria-hidden="true"
                style={{ position: "absolute", left: -10000, width: 1, height: 1, opacity: 0 }}
              />
              {error ? <Alert tone="err">{error}</Alert> : null}
              <button className="btn btn-hot" type="submit" disabled={sending}>
                {sending ? "Sending…" : "Send message"} {ICON.arrow}
              </button>
              <p className="muted" style={{ fontSize: 13 }}>
                Our reply is emailed to the address you enter here.
              </p>
            </form>
          )}
          <div className="stack">
            <div className="card glass">
              <span className="ic o">{ICON.mail}</span>
              <h3>Email support</h3>
              <div className="copy" style={{ marginTop: 8 }}>
                <span style={{ flex: 1 }}>{config.contactEmail}</span>
                <button className="btn btn-glass btn-sm" type="button" onClick={copyEmail}>
                  Copy
                </button>
              </div>
            </div>
            <div className="card glass">
              <span className="ic t">{ICON.pin}</span>
              <h3>Service area</h3>
              <p>Guiuan, Eastern Samar, Philippines</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
