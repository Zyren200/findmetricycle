import { useState } from "react";
import { config } from "../../config";
import { useDocumentTitle } from "../../router";

const faqs = [
  {
    q: "Is FindMeTricycle free to download?",
    a: "Yes. The FindMeTricycle app is completely free to download and use as a passenger. You only pay for rides in cash.",
  },
  {
    q: "Do I need a separate driver account?",
    a: "No. FindMeTricycle uses one account. You start as a passenger, and if you want to drive, you apply through this website. Once approved, Driver Mode is added to your existing account.",
  },
  {
    q: "How long does driver application review take?",
    a: "The admin team reviews each application carefully. Review times may vary. You can check your application status at any time on the Application Status page, and you'll be emailed at each step.",
  },
  {
    q: "What payment methods are accepted?",
    a: "FindMeTricycle currently uses cash payment only. Pay your driver directly at the end of your trip.",
  },
  {
    q: "Where is FindMeTricycle available?",
    a: "FindMeTricycle is designed for and currently available in Guiuan, Eastern Samar, Philippines.",
  },
  {
    q: "Can I reapply if my driver application was not approved?",
    a: 'Yes. If your application was not approved or needs corrections, a "Resubmit" or "Update Application" option appears on your Application Status page.',
  },
];

export default function ContactPage() {
  useDocumentTitle("Contact — FindMeTricycle");
  const [form, setForm] = useState({ name: "", email: "", subject: "", message: "" });
  const [sent, setSent] = useState(false);
  const [error, setError] = useState("");
  const [openFaq, setOpenFaq] = useState(null);

  function set(key) {
    return (e) => setForm((f) => ({ ...f, [key]: e.target.value }));
  }

  // There's no message inbox on the server, so the form hands the message
  // to the visitor's email app, addressed to support.
  function handleSubmit(e) {
    e.preventDefault();
    if (!form.name.trim() || !form.email.trim() || !form.message.trim()) {
      setError("Please fill in your name, email and message.");
      return;
    }
    setError("");
    const subject = form.subject.trim() || "FindMeTricycle inquiry";
    const body = `${form.message.trim()}\n\n— ${form.name.trim()} (${form.email.trim()})`;
    window.location.href = `mailto:${config.contactEmail}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    setSent(true);
  }

  return (
    <>
      <section className="page-hero">
        <div className="container container-xs">
          <h1>Contact Us</h1>
          <p>Have a question, concern, or feedback? We&apos;re here to help.</p>
        </div>
      </section>

      <section className="section-sm">
        <div className="container container-md">
          <div className="contact-grid">
            <div>
              <h2 style={{ fontSize: "1.25rem", marginBottom: 20 }}>Get in Touch</h2>
              <div className="contact-item">
                <i>✉️</i>
                <div>
                  <small>Email Support</small>
                  <a href={`mailto:${config.contactEmail}`}>{config.contactEmail}</a>
                </div>
              </div>
              <div className="contact-item">
                <i>📍</i>
                <div>
                  <small>Service Area</small>
                  <b>Guiuan, Eastern Samar, Philippines</b>
                </div>
              </div>
              <div className="info-box primary" style={{ marginTop: 24 }}>
                <b style={{ display: "block", marginBottom: 4 }}>Response Time</b>
                We aim to respond to all inquiries within 1–2 business days.
              </div>
            </div>

            <div>
              <h2 style={{ fontSize: "1.25rem", marginBottom: 20 }}>Send a Message</h2>
              {sent ? (
                <div className="tile tile-driver center-tile">
                  <span className="tile-emoji">✅</span>
                  <h3>Message ready to send</h3>
                  <p style={{ margin: "0 auto" }}>
                    Your email app opened with your message addressed to {config.contactEmail}. Press Send
                    there to deliver it.
                  </p>
                  <button type="button" className="link-btn" style={{ marginTop: 16 }} onClick={() => setSent(false)}>
                    Write another message
                  </button>
                </div>
              ) : (
                <form onSubmit={handleSubmit} noValidate>
                  <div className="form-grid two">
                    <div className="field">
                      <label htmlFor="c-name">Full Name *</label>
                      <input id="c-name" value={form.name} onChange={set("name")} placeholder="Juan dela Cruz" />
                    </div>
                    <div className="field">
                      <label htmlFor="c-email">Email *</label>
                      <input id="c-email" type="email" value={form.email} onChange={set("email")} placeholder="juan@example.com" />
                    </div>
                  </div>
                  <div className="field">
                    <label htmlFor="c-subject">Subject</label>
                    <input
                      id="c-subject"
                      value={form.subject}
                      onChange={set("subject")}
                      placeholder="Passenger support, Driver application, etc."
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="c-message">Message *</label>
                    <textarea
                      id="c-message"
                      rows={5}
                      value={form.message}
                      onChange={set("message")}
                      placeholder="Describe your question or concern..."
                    />
                  </div>
                  {error ? <div className="banner banner-error">{error}</div> : null}
                  <button type="submit" className="btn btn-primary">
                    Send Message
                  </button>
                </form>
              )}
            </div>
          </div>
        </div>
      </section>

      <section className="section-sm section-alt section-border">
        <div className="container container-xs">
          <h2 className="text-center" style={{ marginBottom: 32 }}>
            Frequently Asked Questions
          </h2>
          <div className="faq">
            {faqs.map((faq, i) => (
              <div className="faq-item" key={faq.q}>
                <button
                  type="button"
                  className="faq-q"
                  aria-expanded={openFaq === i}
                  onClick={() => setOpenFaq(openFaq === i ? null : i)}
                >
                  {faq.q}
                  <span>▼</span>
                </button>
                {openFaq === i ? (
                  <div className="faq-a">
                    <p>{faq.a}</p>
                  </div>
                ) : null}
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
