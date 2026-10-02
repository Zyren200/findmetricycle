import QRCode from "react-qr-code";
import { config } from "../../config";
import { Link, useDocumentTitle } from "../../router";

const installSteps = [
  { title: "Download the APK", desc: 'Tap "Download Android APK" or scan the QR code above.' },
  { title: "Open the downloaded file", desc: "Find the .apk file in your downloads folder and tap it to begin installation." },
  {
    title: "Allow installation from this source",
    desc: "If Android asks for permission to install apps from unknown sources, follow the on-screen instructions to allow it.",
  },
  { title: "Install FindMeTricycle", desc: 'Tap "Install" and wait for the app to finish installing on your device.' },
  { title: "Open and sign in", desc: "Launch FindMeTricycle, then log in to your existing account or create a new one." },
];

export default function DownloadPage() {
  useDocumentTitle("Download FindMeTricycle — Guiuan Tricycle Ride App");

  return (
    <>
      <section className="page-hero">
        <div className="container container-sm">
          <span className="eyebrow">Android</span>
          <h1>Download FindMeTricycle</h1>
          <p style={{ marginBottom: 32 }}>
            Book local tricycle rides in Guiuan — free for Android. No app store required.
          </p>
          <a href={config.apkUrl} download className="cta cta-primary cta-lg">
            ⬇ Download Android APK
          </a>
          <div className="meta-row">
            <span>
              Version <strong>{config.appVersion}</strong>
            </span>
            <span className="meta-sep" />
            <span>
              <strong>{config.appSize}</strong>
            </span>
            <span className="meta-sep" />
            <span>
              Updated <strong>{config.appUpdated}</strong>
            </span>
          </div>
        </div>
      </section>

      <section className="section-sm section-border" style={{ borderBottom: "1px solid var(--line)" }}>
        <div className="container container-sm">
          <div className="qr-row">
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
              <div className="qr-box">
                <QRCode value={config.downloadPageUrl} size={160} fgColor="#1f2937" bgColor="#ffffff" />
              </div>
              <p className="field-hint center-text" style={{ marginTop: 12 }}>
                Scan to open the download page on your phone
              </p>
            </div>
            <div style={{ flex: 1 }}>
              <h2>Scan QR Code</h2>
              <p>
                Open your phone&apos;s camera app and point it at the QR code. Tap the link that appears to
                go directly to the FindMeTricycle download page.
              </p>
              <div className="info-box primary">
                💡 Tip: Make sure your phone has enough storage space before downloading.
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="section-sm section-alt">
        <div className="container container-sm">
          <h2 className="text-center" style={{ marginBottom: 24 }}>
            App Requirements
          </h2>
          <div className="grid sm-3 grid-gap-sm">
            {[
              { icon: "📱", label: "Android Version", value: config.minAndroid },
              { icon: "💾", label: "Storage Required", value: config.appSize },
              { icon: "📡", label: "Internet", value: "Required for booking" },
            ].map((r) => (
              <div className="tile tile-plain center-tile" key={r.label}>
                <span className="tile-emoji">{r.icon}</span>
                <p style={{ fontSize: ".75rem", margin: "0 auto 4px" }}>{r.label}</p>
                <h3 style={{ fontSize: ".88rem", margin: 0 }}>{r.value}</h3>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section-sm">
        <div className="container container-xs">
          <div className="section-head" style={{ marginBottom: 40 }}>
            <h2>Installation Guide</h2>
            <p>Follow these simple steps to install FindMeTricycle on your Android phone.</p>
          </div>
          <div className="list-steps">
            {installSteps.map((s, i) => (
              <div className="list-step" key={s.title}>
                <div className="list-step-num" style={{ width: 40, height: 40, borderRadius: 12 }}>
                  {i + 1}
                </div>
                <div>
                  <h3>{s.title}</h3>
                  <p>{s.desc}</p>
                </div>
              </div>
            ))}
          </div>
          <div className="info-box driver" style={{ marginTop: 32, padding: 20 }}>
            <h3 style={{ color: "var(--driver)" }}>Having trouble?</h3>
            <p style={{ marginBottom: 12 }}>
              If you run into any issue during installation, our support team is here to help.
            </p>
            <Link to="/contact" style={{ color: "var(--driver)" }}>
              Contact Support →
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
