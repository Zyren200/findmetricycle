import { useRef, useState } from "react";
import { createWorker } from "tesseract.js";

const LICENSE_KEYWORDS = ["LICENSE", "DRIVER", "LTO", "PHILIPPINES"];
const PERMIT_KEYWORDS = ["FRANCHISE", "PERMIT", "TRICYCLE", "OPERATOR", "TODA"];
const OCR_TIMEOUT_MS = 20000;
const OCR_MAX_DIMENSION = 1800;

function classify(text, keywords) {
  const upper = (text || "").toUpperCase();
  const hits = keywords.filter((k) => upper.includes(k)).length;
  return hits >= 1;
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
      const looksLikeLicense = classify(ocrText, LICENSE_KEYWORDS);
      updateFormData({
        licenseFile: file,
        licensePreviewUrl: previewUrl,
        licenseOcrText: ocrText,
        licenseWarning: ocrText && !looksLikeLicense
          ? "This doesn't look like a driver's license. Please double-check the photo."
          : null,
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
      const looksLikePermit = classify(ocrText, PERMIT_KEYWORDS);
      updateFormData({
        permitFile: file,
        permitPreviewUrl: previewUrl,
        permitWarning: ocrText && !looksLikePermit
          ? "This doesn't look like a franchise/permit document. Please double-check the photo."
          : null,
      });
    } finally {
      setPermitUploading(false);
    }
  }

  function handleContinue() {
    if (!formData.licenseFile || !formData.permitFile) {
      setError("Both the driver's license and business permit photos are required.");
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

      <p className="field-hint">
        Accepted formats: JPG, PNG, WEBP (max 5MB each). Document checks here are just a helpful hint —
        an admin always makes the final decision.
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
