import { useEffect, useRef, useState } from "react";
import * as faceapi from "face-api.js";

const STEPS = ["look_straight", "blink", "turn_head"];
const STEP_LABELS = {
  look_straight: "Look straight at the camera",
  blink: "Blink your eyes",
  turn_head: "Turn your head slightly left or right",
};
const STEP_TIMEOUT_MS = 12000;
const TOTAL_TIMEOUT_MS = 40000;

function eyeAspectRatio(eye) {
  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const vertical = dist(eye[1], eye[5]) + dist(eye[2], eye[4]);
  const horizontal = dist(eye[0], eye[3]);
  return horizontal === 0 ? 0 : vertical / (2 * horizontal);
}

export default function LivenessStep({ onComplete, onSkipToReview }) {
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const streamRef = useRef(null);
  const rafRef = useRef(null);
  const stateRef = useRef({
    stepIndex: 0,
    baselineX: null,
    eyeWasClosed: false,
    blinkDetected: false,
    turnDetected: false,
    startedAt: Date.now(),
    stepStartedAt: Date.now(),
  });

  const [modelsLoaded, setModelsLoaded] = useState(false);
  const [error, setError] = useState(null);
  const [stepIndex, setStepIndex] = useState(0);
  const [faceVisible, setFaceVisible] = useState(false);
  const [result, setResult] = useState(null); // { status, selfieDataUrl }

  useEffect(() => {
    let cancelled = false;

    async function init() {
      try {
        await Promise.all([
          faceapi.nets.tinyFaceDetector.loadFromUri("/models"),
          faceapi.nets.faceLandmark68Net.loadFromUri("/models"),
        ]);
        if (cancelled) return;
        setModelsLoaded(true);

        const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "user" } });
        if (cancelled) {
          stream.getTracks().forEach((t) => t.stop());
          return;
        }
        streamRef.current = stream;
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          await videoRef.current.play();
        }
        startDetectionLoop();
      } catch (err) {
        if (!cancelled) {
          setError(
            err?.name === "NotAllowedError"
              ? "Camera permission was denied. Please allow camera access and try again."
              : err?.name === "NotFoundError"
                ? "No camera was found on this device."
                : "Could not start the camera. Please try again."
          );
        }
      }
    }

    init();

    return () => {
      cancelled = true;
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      streamRef.current?.getTracks().forEach((t) => t.stop());
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function finish(status) {
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    streamRef.current?.getTracks().forEach((t) => t.stop());

    const video = videoRef.current;
    const canvas = canvasRef.current;
    let selfieDataUrl = null;
    if (video && canvas) {
      canvas.width = video.videoWidth || 320;
      canvas.height = video.videoHeight || 240;
      const ctx = canvas.getContext("2d");
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      selfieDataUrl = canvas.toDataURL("image/jpeg", 0.85);
    }

    setResult({ status, selfieDataUrl });
    onComplete({ status, selfieDataUrl });
  }

  function startDetectionLoop() {
    async function tick() {
      const video = videoRef.current;
      if (!video || video.readyState < 2) {
        rafRef.current = requestAnimationFrame(tick);
        return;
      }

      const now = Date.now();
      const s = stateRef.current;

      if (now - s.startedAt > TOTAL_TIMEOUT_MS) {
        finish("needs_review");
        return;
      }

      const detection = await faceapi
        .detectSingleFace(video, new faceapi.TinyFaceDetectorOptions({ inputSize: 224 }))
        .withFaceLandmarks();

      setFaceVisible(Boolean(detection));

      if (detection) {
        const landmarks = detection.landmarks;
        const box = detection.detection.box;
        const currentStep = STEPS[s.stepIndex];

        if (currentStep === "look_straight") {
          if (s.baselineX === null) {
            s.baselineX = box.x + box.width / 2;
            s.stepStartedAt = now;
          } else if (now - s.stepStartedAt > 800) {
            advanceStep();
          }
        } else if (currentStep === "blink") {
          const leftEAR = eyeAspectRatio(landmarks.getLeftEye());
          const rightEAR = eyeAspectRatio(landmarks.getRightEye());
          const ear = (leftEAR + rightEAR) / 2;

          if (ear < 0.22) {
            s.eyeWasClosed = true;
          } else if (s.eyeWasClosed && ear > 0.27) {
            s.blinkDetected = true;
          }

          if (s.blinkDetected) advanceStep();
        } else if (currentStep === "turn_head") {
          const currentX = box.x + box.width / 2;
          const shift = Math.abs(currentX - (s.baselineX ?? currentX));
          if (shift > box.width * 0.18) {
            s.turnDetected = true;
          }
          if (s.turnDetected) advanceStep();
        }
      }

      if (now - s.stepStartedAt > STEP_TIMEOUT_MS && STEPS[s.stepIndex] !== "look_straight") {
        // Couldn't confirm this step in time — still let them through, flagged for admin review.
        finish("needs_review");
        return;
      }

      rafRef.current = requestAnimationFrame(tick);
    }

    function advanceStep() {
      const s = stateRef.current;
      if (s.stepIndex >= STEPS.length - 1) {
        finish("passed");
        return;
      }
      s.stepIndex += 1;
      s.stepStartedAt = Date.now();
      setStepIndex(s.stepIndex);
    }

    rafRef.current = requestAnimationFrame(tick);
  }

  if (error) {
    return (
      <div className="card">
        <h2>Identity Verification</h2>
        <div className="banner banner-error">{error}</div>
        <p>You can still submit your application — the liveness check will be flagged for manual review.</p>
        <button type="button" className="btn btn-primary" onClick={() => onSkipToReview("failed")}>
          Continue Without Camera
        </button>
      </div>
    );
  }

  if (result) {
    return (
      <div className="card">
        <h2>Identity Verification</h2>
        <div className={`banner ${result.status === "passed" ? "banner-success" : "banner-warning"}`}>
          {result.status === "passed"
            ? "✓ Liveness check complete."
            : "Liveness check recorded — this will be reviewed by an admin."}
        </div>
        {result.selfieDataUrl ? <img src={result.selfieDataUrl} alt="Captured selfie" className="doc-preview" /> : null}
      </div>
    );
  }

  return (
    <div className="card">
      <h2>Identity Verification</h2>
      <p>Follow the on-screen instructions using your camera. This helps confirm you're a real person.</p>

      <div style={{ position: "relative" }}>
        <video ref={videoRef} className="otp-webcam" muted playsInline />
        {!modelsLoaded ? (
          <div className="center-text" style={{ marginTop: 12 }}>
            Loading camera models…
          </div>
        ) : null}
      </div>
      <canvas ref={canvasRef} style={{ display: "none" }} />

      {modelsLoaded ? (
        <>
          <div className="liveness-instruction">{STEP_LABELS[STEPS[stepIndex]]}</div>
          <p className="center-text">
            Step {stepIndex + 1} of {STEPS.length} {faceVisible ? "" : "— position your face in the frame"}
          </p>
        </>
      ) : null}
    </div>
  );
}
