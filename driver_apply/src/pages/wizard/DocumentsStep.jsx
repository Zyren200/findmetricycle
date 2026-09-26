import { useRef, useState } from "react";
import { classifyDocument } from "../../utils/documentClassifier";

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

function UploadSlot({ title, hint, file, previewUrl, uploading, warning, onSelect, inputId }) {
  const inputRef = useRef(null);
  return (
    <div
      className={`doc-upload ${file ? "uploaded" : ""}`}
      onClick={() => inputRef.current?.click()}
      role="button"
      tabIndex={0}
    >
      <div className="doc-upload-title">{title}</div>
      <div className="doc-upload-status">
        {uploading ? "Reading document…" : file ? "✓ Document uploaded" : hint}
      </div>
      {warning ? <div className="field-error">⚠ {warning}</div> : null}
      {previewUrl ? <img src={previewUrl} alt={title} className="doc-preview" /> : null}
      <input
        ref={inputRef}
        id={inputId}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        style={{ display: "none" }}
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) onSelect(f);
        }}
      />
    </div>
  );
}

export default function DocumentsStep({ formData, updateFormData, onNext, onBack }) {
  const [licenseUploading, setLicenseUploading] = useState(false);
  const [permitUploading, setPermitUploading] = useState(false);
  const [error, setError] = useState(null);

  async function handleLicenseSelect(file) {
    setError(null);
    setLicenseUploading(true);
    try {
      const previewUrl = URL.createObjectURL(file);
      const ocrText = await runOcr(file);
      const { status, warning } = checkWarning(ocrText, "license");
      updateFormData({
        licenseFile: file,
        licensePreviewUrl: previewUrl,
        licenseOcrText: ocrText,
        licenseCheck: status,
        licenseWarning: warning,
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
      const previewUrl = URL.createObjectURL(file);
      const ocrText = await runOcr(file);
      const { status, warning } = checkWarning(ocrText, "permit");
      updateFormData({
        permitFile: file,
        permitPreviewUrl: previewUrl,
        permitCheck: status,
        permitWarning: warning,
        documentsConfirmed: false,
      });
    } finally {
      setPermitUploading(false);
    }
  }

  const flagged = Boolean(formData.licenseWarning || formData.permitWarning);

  function handleContinue() {
    if (!formData.licenseFile || !formData.permitFile) {
      setError("Both the driver's license and business permit photos are required.");
      return;
    }
    // A photo that doesn't pass the check needs a new photo, or an explicit
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
        Accepted formats: JPG, PNG, WEBP (max 5MB each). The photos are checked automatically — make sure the
        whole document is visible, in focus and well lit. An admin reviews every application.
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
