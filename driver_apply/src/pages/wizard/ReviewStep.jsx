import { useState } from "react";
import { apiClient } from "../../api/client";

function dataUrlToBlob(dataUrl) {
  const [header, base64] = dataUrl.split(",");
  const mime = header.match(/data:(.*);base64/)?.[1] || "image/jpeg";
  const bytes = atob(base64);
  const array = new Uint8Array(bytes.length);
  for (let i = 0; i < bytes.length; i += 1) array[i] = bytes.charCodeAt(i);
  return new Blob([array], { type: mime });
}

export default function ReviewStep({ formData, user, mode, onBack, onSubmitted }) {
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);
  const [confirmed, setConfirmed] = useState(false);
  // The server only accepts an application if the applicant confirmed their
  // email within the last hour; when that has lapsed (e.g. they came back
  // later) the code step appears here instead of losing the whole form.
  const [needsOtp, setNeedsOtp] = useState(false);
  const [otpCode, setOtpCode] = useState("");
  const [otpBusy, setOtpBusy] = useState(false);
  const [otpNotice, setOtpNotice] = useState(null);

  async function sendOtp() {
    setOtpBusy(true);
    setError(null);
    try {
      await apiClient.post("/auth/v2/driver-application/otp/send");
      setOtpNotice(`We sent a 6-digit code to ${user?.email || "your email"}.`);
    } catch (err) {
      setError(err?.response?.data?.message || "Could not send the verification code.");
    } finally {
      setOtpBusy(false);
    }
  }

  async function verifyOtpAndSubmit(e) {
    e?.preventDefault();
    if (!/^\d{6}$/.test(otpCode)) {
      setError("Enter the 6-digit code from your email.");
      return;
    }
    setOtpBusy(true);
    setError(null);
    try {
      await apiClient.post("/auth/v2/driver-application/otp/verify", { code: otpCode });
      setNeedsOtp(false);
      setOtpCode("");
      setOtpNotice(null);
      await handleSubmit();
    } catch (err) {
      setError(err?.response?.data?.message || "Invalid or expired code.");
    } finally {
      setOtpBusy(false);
    }
  }

  async function handleSubmit() {
    if (!confirmed) {
      setError("Please confirm your information is accurate before submitting.");
      return;
    }

    setSubmitting(true);
    setError(null);
    try {
      const body = new FormData();
      if (mode === "new") {
        body.append("plateNumber", formData.plateNumber || "");
      }
      if (formData.franchiseNumber) body.append("franchiseNumber", formData.franchiseNumber);
      if (formData.licenseType) body.append("licenseType", formData.licenseType);
      if (formData.address) body.append("address", formData.address);
      if (formData.emergencyContactName) body.append("emergencyContactName", formData.emergencyContactName);
      if (formData.emergencyContactPhone) body.append("emergencyContactPhone", formData.emergencyContactPhone);
      if (formData.licenseOcrText) body.append("licenseOcrText", formData.licenseOcrText);
      body.append("livenessStatus", formData.livenessStatus || "needs_review");
      body.append("licenseImage", formData.licenseFile, formData.licenseFile.name || "license.jpg");
      body.append("businessPermitImage", formData.permitFile, formData.permitFile.name || "permit.jpg");
      if (formData.selfieDataUrl) {
        body.append("selfieImage", dataUrlToBlob(formData.selfieDataUrl), "selfie.jpg");
      }

      const endpoint = mode === "new" ? "/auth/v2/apply-driver" : "/auth/v2/resubmit-driver-application";
      const { data } = await apiClient.post(endpoint, body, {
        headers: { "Content-Type": "multipart/form-data" },
      });

      if (!data?.success) {
        throw new Error(data?.message || "Submission failed.");
      }

      onSubmitted(data?.data);
    } catch (err) {
      if (err?.response?.data?.details?.code === "OTP_REQUIRED") {
        setNeedsOtp(true);
        await sendOtp();
        return;
      }
      setError(err?.response?.data?.message || err.message || "Submission failed. Please try again.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="card">
      <h2>Review &amp; Submit</h2>
      <p>Please confirm everything looks correct before submitting your application.</p>

      {error ? <div className="banner banner-error">{error}</div> : null}

      <div className="review-section">
        <h3>✓ Personal Information</h3>
        <div className="review-row"><span>Full Name</span><span>{user?.fullName || user?.full_name}</span></div>
        <div className="review-row"><span>Email</span><span>{user?.email}</span></div>
        <div className="review-row"><span>Contact</span><span>{user?.phone}</span></div>
        <div className="review-row"><span>Address</span><span>{formData.address}</span></div>
        <div className="review-row"><span>Emergency Contact</span><span>{formData.emergencyContactName}</span></div>
      </div>

      <div className="review-section">
        <h3>✓ Driver Information</h3>
        <div className="review-row"><span>License Type</span><span>{formData.licenseType}</span></div>
        {mode === "new" ? (
          <div className="review-row"><span>Plate Number</span><span>{formData.plateNumber}</span></div>
        ) : null}
        {formData.franchiseNumber ? (
          <div className="review-row"><span>Franchise Number</span><span>{formData.franchiseNumber}</span></div>
        ) : null}
      </div>

      <div className="review-section">
        <h3>✓ Required Documents</h3>
        <div className="review-row"><span>Driver's License</span><span>Uploaded</span></div>
        <div className="review-row"><span>Business Permit</span><span>Uploaded</span></div>
      </div>

      <div className="review-section">
        <h3>✓ Identity Verification</h3>
        <div className="review-row">
          <span>Liveness Check</span>
          <span>{formData.livenessStatus === "passed" ? "Passed" : "Needs review"}</span>
        </div>
      </div>

      <label style={{ display: "flex", gap: 10, alignItems: "flex-start", marginBottom: 16, cursor: "pointer" }}>
        <input
          type="checkbox"
          checked={confirmed}
          onChange={(e) => setConfirmed(e.target.checked)}
          style={{ marginTop: 3 }}
        />
        <span style={{ fontSize: 14, color: "var(--muted)" }}>
          I confirm that the information and documents I provided are accurate and belong to me.
        </span>
      </label>

      {needsOtp ? (
        <form onSubmit={verifyOtpAndSubmit} className="review-section">
          <h3>Confirm it's you</h3>
          <p style={{ fontSize: 14, color: "var(--muted)" }}>
            {otpNotice || "For your security, confirm your email before submitting."}
          </p>
          <div className="field">
            <label htmlFor="application-otp">Verification code</label>
            <input
              id="application-otp"
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={6}
              value={otpCode}
              onChange={(e) => setOtpCode(e.target.value.replace(/D/g, "").slice(0, 6))}
              placeholder="123456"
            />
          </div>
          <div className="btn-row">
            <button type="button" className="btn btn-ghost" onClick={sendOtp} disabled={otpBusy || submitting}>
              Resend code
            </button>
            <button type="submit" className="btn btn-primary" disabled={otpBusy || submitting}>
              {otpBusy || submitting ? "Verifying…" : "Verify & Submit"}
            </button>
          </div>
        </form>
      ) : null}

      <div className="btn-row">
        <button type="button" className="btn btn-ghost" onClick={onBack} disabled={submitting}>
          Back
        </button>
        <button type="button" className="btn btn-primary" onClick={handleSubmit} disabled={submitting || needsOtp}>
          {submitting ? "Submitting…" : "Submit Application"}
        </button>
      </div>
    </div>
  );
}
