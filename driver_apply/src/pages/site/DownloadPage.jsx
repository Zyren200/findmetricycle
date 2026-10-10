import QRCode from "react-qr-code";
import { config } from "../../config";
import { ICON } from "../../components/Icons";
import { Alert, Head, Shot, StepCard } from "../../components/ui";
import { Link, useDocumentTitle } from "../../router";

export default function DownloadPage() {
  useDocumentTitle("FindMeTricycle · Download");

  return (
    <section>
      <div className="wrap">
        <Head eyebrow="Download" title="Get FindMeTricycle for Android." sub="Free to download. No app store needed." />
        <div className="grid g2">
          <div className="card glass">
            <div className="row" style={{ alignItems: "flex-start", gap: 24 }}>
              <div className="qr" aria-label="QR code for the download page">
                <QRCode value={config.downloadPageUrl} size={140} fgColor="#17130F" bgColor="#ffffff" style={{ width: "100%", height: "100%" }} />
              </div>
              <div style={{ flex: 1, minWidth: 200 }}>
                <h3 style={{ fontSize: 22, marginTop: 0 }}>Scan to download</h3>
                <p className="muted">Open your phone camera and point it at the code.</p>
                <div className="row" style={{ marginTop: 18 }}>
                  <a className="btn btn-hot" href={config.apkUrl} download>
                    Download APK {ICON.arrow}
                  </a>
                </div>
                <p className="muted" style={{ fontSize: 13, marginTop: 10 }}>
                  Or open this link on your phone:
                </p>
                <div className="copy" style={{ marginTop: 6 }}>
                  {config.downloadPageUrl}
                </div>
              </div>
            </div>
          </div>
          <div className="card glass">
            <h3 style={{ fontSize: 22, marginTop: 0 }}>App requirements</h3>
            <ul className="list" style={{ marginTop: 12 }}>
              <li>Android phone ({config.minAndroid})</li>
              <li>Internet connection (mobile data or Wi-Fi)</li>
              <li>Location turned on for booking and tracking</li>
              <li>About {config.appSize} of free storage</li>
            </ul>
            <p className="muted" style={{ fontSize: 13, marginTop: 14 }}>
              Version {config.appVersion} · Updated {config.appUpdated}
            </p>
          </div>
        </div>

        <h3 style={{ fontSize: 22, margin: "40px 0 16px" }}>Inside the app</h3>
        <div className="shots-row">
          <Shot id="p-home" title="Home" sub="Search where you want to go." />
          <Shot id="choose" title="Choose your rider" sub="Nearby drivers with ratings." />
          <Shot id="ride" title="Ride status" sub="Live map, your PIN and SOS." />
          <Shot id="done" title="Ride completed" sub="Pay cash, then rate your driver." />
        </div>

        <h3 style={{ fontSize: 22, margin: "40px 0 16px" }}>Installation guide</h3>
        <div className="grid g4">
          <StepCard n={1} title="Download the APK">
            Tap Download APK on your Android phone.
          </StepCard>
          <StepCard n={2} title="Allow the install">
            If asked, allow installs from your browser in Settings.
          </StepCard>
          <StepCard n={3} title="Install and open">
            Open the downloaded file and tap Install.
          </StepCard>
          <StepCard n={4} title="Create your account">
            Sign up with your email and mobile number.
          </StepCard>
        </div>
        <Alert tone="info" title="Having trouble?" style={{ marginTop: 28 }}>
          Email us at <span className="mono">{config.contactEmail}</span> or use the <Link to="/contact">Contact page</Link>.
        </Alert>
      </div>
    </section>
  );
}
