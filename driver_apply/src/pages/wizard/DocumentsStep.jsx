import { useRef, useState } from "react";
import { classifyDocument } from "../../utils/documentClassifier";
import { checkLicenseIdentity } from "../../utils/licenseIdentity";

const OCR_TIMEOUT_MS = 20000;
const OCR_MAX_DIMENSION = 1800;

// Same rules the server applies after submission (and shows the admin).
const CHECK_MESSAGES = {
  license: {
    suspicious: "Mukhang hindi ito driver's license. Mag-upload ng malinaw na litrato ng LTO license mo.",
    unreadable: "Hindi mabasa ang litrato. Kumuha ng malinaw at maliwanag na litrato ng buong license.",
  },
  permit: {
    suspicious: "Mukhang hindi ito franchise / business permit. Mag-upload ng MTOP, franchise o permit mo.",
    unreadable: "Hindi mabasa ang litrato. Kumuha ng malinaw at maliwanag na litrato ng buong permit.",
  },
};

function checkWarning(ocrText, kind) {
  const { status } = classifyDocument(ocrText, kind);
  return { status, warning: CHECK_MESSAGES[kind][status] || null };
}

function loadImage(file) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("Could not read image file."));
    img.src = URL.createObjectURL(file);
  });
}

// Downscales the photo to a sane OCR size and converts it to a
// contrast-stretched grayscale canvas. Real-world document photos (uneven
// lighting, glare, low-contrast backgrounds) read much more reliably after
// this than the raw camera capture — full-resolution color photos are what
// were causing garbled/empty OCR text and constant false "doesn't look
// like a license/permit" warnings. The original file is still what gets
// uploaded; this canvas is only used for the OCR pass.
async function preprocessForOcr(file) {
  const img = await loadImage(file);
  try {
    const scale = Math.min(1, OCR_MAX_DIMENSION / Math.max(img.width, img.height));
    const width = Math.max(1, Math.round(img.width * scale));
    const height = Math.max(1, Math.round(img.height * scale));

    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    ctx.drawImage(img, 0, 0, width, height);

    const imageData = ctx.getImageData(0, 0, width, height);
    const data = imageData.data;
    const gray = new Uint8ClampedArray(width * height);
    let min = 255;
    let max = 0;
    for (let i = 0, p = 0; i < data.length; i += 4, p += 1) {
      const g = data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
      gray[p] = g;
      if (g < min) min = g;
      if (g > max) max = g;
    }
    const range = Math.max(max - min, 1);
    for (let i = 0, p = 0; i < data.length; i += 4, p += 1) {
      const stretched = ((gray[p] - min) / range) * 255;
      data[i] = data[i + 1] = data[i + 2] = stretched;
    }
    ctx.putImageData(imageData, 0, 0);

    return canvas;
  } finally {
    URL.revokeObjectURL(img.src);
  }
}

// Photo quality gate, run before OCR. Thresholds are deliberately lenient
// — they catch photos a person also couldn't read (motion blur, out of
// focus, a dark room, a washed-out flash, a tiny thumbnail), not slightly
// imperfect ones.
const MIN_SHARPNESS = 40; // variance of the Laplacian on a ~800px grayscale copy
const MIN_BRIGHTNESS = 45;
const MAX_BRIGHTNESS = 230;
const MIN_PHOTO_SIDE = 500; // px, shortest side of the original photo

async function checkPhotoQuality(file) {
  const img = await loadImage(file);
  try {
    if (Math.min(img.width, img.height) < MIN_PHOTO_SIDE) {
      return "Masyadong maliit ang litrato. Kunan ulit nang malapit para malinaw ang lahat ng nakasulat.";
    }
    const scale = Math.min(1, 800 / Math.max(img.width, img.height));
    const width = Math.max(1, Math.round(img.width * scale));
    const height = Math.max(1, Math.round(img.height * scale));
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    ctx.drawImage(img, 0, 0, width, height);
    const { data } = ctx.getImageData(0, 0, width, height);

    const gray = new Float32Array(width * height);
    let sum = 0;
    for (let i = 0, p = 0; i < data.length; i += 4, p += 1) {
      gray[p] = data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
      sum += gray[p];
    }
    const brightness = sum / gray.length;
    if (brightness < MIN_BRIGHTNESS) {
      return "Masyadong madilim ang litrato. Kunan ulit sa maliwanag na lugar.";
    }
    if (brightness > MAX_BRIGHTNESS) {
      return "Masyadong maliwanag / may silaw ang litrato. Iwasan ang flash at direktang ilaw sa card.";
    }

    // Sharpness: variance of the Laplacian (edges). Blurry photos have
    // almost no strong edges, so the variance is low.
    let lapSum = 0;
    let lapSq = 0;
    let n = 0;
    for (let y = 1; y < height - 1; y += 1) {
      for (let x = 1; x < width - 1; x += 1) {
        const p = y * width + x;
        const lap = gray[p - width] + gray[p + width] + gray[p - 1] + gray[p + 1] - 4 * gray[p];
        lapSum += lap;
        lapSq += lap * lap;
        n += 1;
      }
    }
    const mean = lapSum / n;
    const variance = lapSq / n - mean * mean;
    if (variance < MIN_SHARPNESS) {
      return "Malabo ang litrato. Hawakan nang steady ang phone, i-focus sa card, at kunan ulit.";
    }
    return null;
  } finally {
    URL.revokeObjectURL(img.src);
  }
}

function withTimeout(promise, ms) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error("OCR timed out")), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

// Runs the enhanced OCR pass for one document photo. Never throws — a slow
// network fetch of the OCR language data, a worker crash, or a bad photo
// should degrade to an empty result and let the admin review manually,
// never block the applicant from continuing.
async function runOcr(file) {
  let worker;
  try {
    const canvas = await preprocessForOcr(file);
    // Loaded on demand so the OCR engine isn't part of the initial bundle.
    const { createWorker } = await import("tesseract.js");
    worker = await withTimeout(createWorker("eng"), OCR_TIMEOUT_MS);
    const { data } = await withTimeout(worker.recognize(canvas), OCR_TIMEOUT_MS);
    return data.text || "";
  } catch {
    return "";
  } finally {
    if (worker) {
      worker.terminate().catch(() => {});
    }
  }
}

function UploadSlot({ title, hint, file, previewUrl, uploading, warning, rejected, okDetails, onSelect, inputId }) {
  const inputRef = useRef(null);
  return (
    <div
      className={`doc-upload ${file ? "uploaded" : ""}`}
      style={rejected ? { borderColor: "var(--coral)", borderStyle: "solid", background: "var(--coral-bg)" } : undefined}
      onClick={() => inputRef.current?.click()}
      role="button"
      tabIndex={0}
    >
      <div className="doc-body">
        <div className="doc-upload-title">{title}</div>
        <div className="doc-upload-status">
          {uploading
            ? "Checking the photo…"
            : rejected
              ? "Tap to upload a new photo"
              : file
                ? "✓ Document accepted — tap to replace"
                : hint}
        </div>
        {rejected ? (
          <div className="banner banner-error" style={{ margin: "8px 0 0" }}>
            ⚠ {rejected}
          </div>
        ) : null}
        {!rejected && warning ? <div className="field-error">⚠ {warning}</div> : null}
        {!rejected && okDetails ? <div className="field-hint" style={{ color: "var(--teal)" }}>{okDetails}</div> : null}
      </div>
      {previewUrl && !rejected ? <img src={previewUrl} alt={title} className="doc-preview" /> : null}
      <input
        ref={inputRef}
        id={inputId}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        style={{ display: "none" }}
        onChange={(e) => {
          const f = e.target.files?.[0];
          // Let the same file be picked again after a rejection.
          e.target.value = "";
          if (f) onSelect(f);
        }}
      />
    </div>
  );
}

export default function DocumentsStep({ user, formData, updateFormData, onNext, onBack }) {
  const [licenseUploading, setLicenseUploading] = useState(false);
  const [permitUploading, setPermitUploading] = useState(false);
  const [error, setError] = useState(null);
  const accountName = user?.full_name || user?.fullName || "";

  // A rejected photo is never kept: the slot empties and asks for a new
  // upload, so a bad photo can't reach the server.
  function rejectLicense(reason) {
    updateFormData({
      licenseFile: null,
      licensePreviewUrl: null,
      licenseOcrText: "",
      licenseCheck: "rejected",
      licenseWarning: null,
      licenseRejected: reason,
      licenseDetails: null,
    });
  }

  async function handleLicenseSelect(file) {
    setError(null);
    setLicenseUploading(true);
    try {
      const qualityProblem = await checkPhotoQuality(file).catch(() => "Hindi mabuksan ang litrato. Subukan ang ibang file.");
      if (qualityProblem) {
        rejectLicense(qualityProblem);
        return;
      }

      const ocrText = await runOcr(file);
      const { status } = classifyDocument(ocrText, "license");
      const identity = checkLicenseIdentity(ocrText, accountName);

      if (!identity.readable || status === "unreadable") {
        rejectLicense(
          "Hindi mabasa ang license sa litrato (malabo, may silaw, o putol). Kunan ulit ang buong card nang malinaw at diretso."
        );
        return;
      }
      if (!identity.licenseNumber) {
        rejectLicense(
          "Hindi ito mukhang Philippine driver's license — walang nakitang LTO license number (hal. A12-34-567890). Siguraduhing kita ang license number sa litrato."
        );
        return;
      }
      if (identity.nameStatus !== "match") {
        rejectLicense(
          `Hindi tugma ang pangalan sa license sa pangalan ng account mo (${accountName}). Sariling driver's license mo lang ang puwedeng i-upload.`
        );
        return;
      }

      updateFormData({
        licenseFile: file,
        licensePreviewUrl: URL.createObjectURL(file),
        licenseOcrText: ocrText,
        licenseCheck: status,
        licenseWarning: status === "suspicious" ? CHECK_MESSAGES.license.suspicious : null,
        licenseRejected: null,
        licenseDetails: `License No. ${identity.licenseNumber} · pangalan tugma sa account (${accountName})`,
        documentsConfirmed: false,
      });
    } finally {
      setLicenseUploading(false);
    }
  }

  async function handlePermitSelect(file) {
    setError(null);
    setPermitUploading(true);
    try {
      const qualityProblem = await checkPhotoQuality(file).catch(() => "Hindi mabuksan ang litrato. Subukan ang ibang file.");
      if (qualityProblem) {
        updateFormData({ permitFile: null, permitPreviewUrl: null, permitCheck: "rejected", permitWarning: null, permitRejected: qualityProblem });
        return;
      }
      const ocrText = await runOcr(file);
      const { status, warning } = checkWarning(ocrText, "permit");
      if (status === "unreadable") {
        updateFormData({ permitFile: null, permitPreviewUrl: null, permitCheck: "rejected", permitWarning: null, permitRejected: warning });
        return;
      }
      // Permit layouts differ per municipality, so a "doesn't look like a
      // permit" result can still be confirmed by the applicant below — it's
      // flagged for the admin.
      updateFormData({
        permitFile: file,
        permitPreviewUrl: URL.createObjectURL(file),
        permitCheck: status,
        permitWarning: warning,
        permitRejected: null,
        documentsConfirmed: false,
      });
    } finally {
      setPermitUploading(false);
    }
  }

  const flagged = Boolean(formData.licenseWarning || formData.permitWarning);

  function handleContinue() {
    if (!formData.licenseFile || !formData.permitFile) {
      setError(
        formData.licenseRejected || formData.permitRejected
          ? "May litratong hindi tinanggap. Mag-upload ng bago bago magpatuloy."
          : "Both the driver's license and business permit photos are required."
      );
      return;
    }
    // A permit that doesn't pass the check needs a new photo, or an explicit
    // "yes, this is the right document" — it's then flagged for the admin.
    if (flagged && !formData.documentsConfirmed) {
      setError("May dokumentong hindi pumasa sa check. Palitan ang litrato, o kumpirmahin sa ibaba na tama ito.");
      return;
    }
    onNext();
  }

  return (
    <div className="card">
      <h2>Required Documents</h2>
      <p>Upload clear photos of your documents. We'll automatically scan the license for you.</p>

      {error ? <div className="banner banner-error">{error}</div> : null}

      <UploadSlot
        title="Driver's License"
        hint="Tap to upload"
        file={formData.licenseFile}
        previewUrl={formData.licensePreviewUrl}
        uploading={licenseUploading}
        warning={formData.licenseWarning}
        rejected={formData.licenseRejected}
        okDetails={formData.licenseDetails}
        onSelect={handleLicenseSelect}
        inputId="license-upload"
      />

      <UploadSlot
        title="Franchise / Permit"
        hint="Tap to upload"
        file={formData.permitFile}
        previewUrl={formData.permitPreviewUrl}
        uploading={permitUploading}
        warning={formData.permitWarning}
        rejected={formData.permitRejected}
        onSelect={handlePermitSelect}
        inputId="permit-upload"
      />

      {flagged ? (
        <label style={{ display: "flex", gap: 10, alignItems: "flex-start", margin: "4px 0 14px", cursor: "pointer" }}>
          <input
            type="checkbox"
            checked={Boolean(formData.documentsConfirmed)}
            onChange={(e) => updateFormData({ documentsConfirmed: e.target.checked })}
            style={{ marginTop: 3 }}
          />
          <span style={{ fontSize: 14, color: "var(--muted)" }}>
            Sigurado akong tamang dokumento ang na-upload ko. Naiintindihan kong mamarkahan ito para sa masusing
            pagsusuri ng admin, at maaaring ma-reject ang application kung mali.
          </span>
        </label>
      ) : null}

      <p className="field-hint">
        Accepted formats: JPG, PNG, WEBP (max 5MB each). Ang license ay dapat Philippine LTO driver&apos;s license na
        nakapangalan sa iyo ({accountName || "pangalan ng account mo"}). Kunan ang buong card nang malinaw, diretso,
        walang silaw at hindi malabo — awtomatikong tatanggihan ang malabo o maling litrato. An admin reviews every
        application.
      </p>

      <div className="btn-row">
        <button type="button" className="btn btn-ghost" onClick={onBack}>
          Back
        </button>
        <button
          type="button"
          className="btn btn-primary"
          onClick={handleContinue}
          disabled={licenseUploading || permitUploading}
        >
          Continue
        </button>
      </div>
    </div>
  );
}
