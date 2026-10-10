import { useEffect, useRef, useState } from "react";
import { ICON } from "../../components/Icons";
import { Alert } from "../../components/ui";

// face-api.js (with TensorFlow) is large, so it's only fetched once the
// applicant starts the check; set by start() before any detection runs.
let faceapi = null;

const STEPS = ["look_straight", "blink", "turn_head"];
const PROMPTS = ["Look straight", "Blink", "Turn your head"];
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

/**
 * Live face check: look straight, blink, turn your head. The result
 * (passed / needs_review / failed) and a selfie go with the application;
 * anything but "passed" is reviewed by the admin.
 */
export default function LivenessStep({ formData, updateFormData, errors }) {
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const streamRef = useRef(null);
  const rafRef = useRef(null);
  const aliveRef = useRef(true);
  const stateRef = useRef(null);

  // idle | loading | running | error
  const [phase, setPhase] = useState("idle");
  const [cameraError, setCameraError] = useState(null);
  const [stepIndex, setStepIndex] = useState(0);
  const [faceVisible, setFaceVisible] = useState(false);

  const result = formData.livenessStatus || null;

  function stopCamera() {
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    rafRef.current = null;
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
  }

  useEffect(() => {
    aliveRef.current = true;
    return () => {
      aliveRef.current = false;
      stopCamera();
    };
  }, []);

  async function start() {
    setCameraError(null);
    setStepIndex(0);
    setFaceVisible(false);
    setPhase("loading");
    stateRef.current = {
      stepIndex: 0,
      baselineX: null,
      eyeWasClosed: false,
      blinkDetected: false,
      turnDetected: false,
      startedAt: Date.now(),
      stepStartedAt: Date.now(),
    };
    try {
      faceapi = faceapi || (await import("face-api.js"));
      await Promise.all([
        faceapi.nets.tinyFaceDetector.loadFromUri("/models"),
        faceapi.nets.faceLandmark68Net.loadFromUri("/models"),
      ]);
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "user" }, audio: false });
      if (!aliveRef.current) {
        stream.getTracks().forEach((t) => t.stop());
        return;
      }
      streamRef.current = stream;
      setPhase("running");
      // The video is in the page once "running" renders.
      requestAnimationFrame(async () => {
        const video = videoRef.current;
        if (!video) return;
        video.srcObject = stream;
        try {
          await video.play();
        } catch {
          // Autoplay quirks: the detection loop waits for frames anyway.
        }
        loop();
      });
    } catch (err) {
      stopCamera();
      if (!aliveRef.current) return;
      setCameraError(
        err?.name === "NotAllowedError"
          ? "Camera permission was denied. Allow camera access in your browser and try again."
          : err?.name === "NotFoundError"
            ? "No camera was found on this device."
            : "We couldn't start the camera. Try again."
      );
      setPhase("error");
    }
  }

  function finish(status) {
    const video = videoRef.current;
    const canvas = canvasRef.current;
    let selfieDataUrl = null;
    if (video && canvas && video.videoWidth) {
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      canvas.getContext("2d").drawImage(video, 0, 0, canvas.width, canvas.height);
      selfieDataUrl = canvas.toDataURL("image/jpeg", 0.85);
    }
    stopCamera();
    if (!aliveRef.current) return;
    updateFormData({ livenessStatus: status, selfieDataUrl });
    setPhase("idle");
  }

  function loop() {
    async function tick() {
      if (!aliveRef.current) return;
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
      if (!aliveRef.current || !streamRef.current) return;
      setFaceVisible(Boolean(detection));

      if (detection) {
        const box = detection.detection.box;
        const current = STEPS[s.stepIndex];
        if (current === "look_straight") {
          if (s.baselineX === null) {
            s.baselineX = box.x + box.width / 2;
            s.stepStartedAt = now;
          } else if (now - s.stepStartedAt > 800) {
            if (advance()) return;
          }
        } else if (current === "blink") {
          const ear = (eyeAspectRatio(detection.landmarks.getLeftEye()) + eyeAspectRatio(detection.landmarks.getRightEye())) / 2;
          if (ear < 0.22) s.eyeWasClosed = true;
          else if (s.eyeWasClosed && ear > 0.27) s.blinkDetected = true;
          if (s.blinkDetected && advance()) return;
        } else if (current === "turn_head") {
          const shift = Math.abs(box.x + box.width / 2 - (s.baselineX ?? box.x + box.width / 2));
          if (shift > box.width * 0.18) s.turnDetected = true;
          if (s.turnDetected && advance()) return;
        }
      }

      if (now - s.stepStartedAt > STEP_TIMEOUT_MS && STEPS[s.stepIndex] !== "look_straight") {
        // Couldn't confirm this step in time: still let them through, flagged for the admin.
        finish("needs_review");
        return;
      }
      rafRef.current = requestAnimationFrame(tick);
    }

    // Returns true once the last step is done (the check is over).
    function advance() {
      const s = stateRef.current;
      if (s.stepIndex >= STEPS.length - 1) {
        setStepIndex(STEPS.length);
        finish("passed");
        return true;
      }
      s.stepIndex += 1;
      s.stepStartedAt = Date.now();
      setStepIndex(s.stepIndex);
      return false;
    }

    rafRef.current = requestAnimationFrame(tick);
  }

  const running = phase === "running";
  const progress = running ? (stepIndex / STEPS.length) * 100 : result === "passed" ? 100 : 0;
  const pillTone = (i) => {
    if (running) return i < stepIndex ? "ok" : i === stepIndex ? "warn" : "";
    return result === "passed" ? "ok" : "";
  };

  return (
    <>
      <h2>Identity verification</h2>
      <p className="muted">A quick live check that the applicant is you. Look straight at the camera, blink, then turn your head.</p>
      <div className="cam">
        {running || phase === "loading" ? <video ref={videoRef} muted playsInline /> : null}
        {!running && formData.selfieDataUrl ? (
          <img src={formData.selfieDataUrl} alt="Your face check" style={{ width: "100%", height: "100%", objectFit: "cover", transform: "scaleX(-1)" }} />
        ) : null}
        {!running && !formData.selfieDataUrl ? (
          result === "passed" ? (
            <span style={{ color: "var(--ok)" }}>{ICON.check}</span>
          ) : result ? (
            <span style={{ color: "var(--warn)" }}>{ICON.alert}</span>
          ) : (
            ICON.user
          )
        ) : null}
        <div className="ring" style={{ "--p": `${progress}%` }} />
      </div>
      <canvas ref={canvasRef} style={{ display: "none" }} />
      <div className="prompts">
        {PROMPTS.map((p, i) => (
          <span key={p} className={`pill ${pillTone(i)}`}>
            {p}
          </span>
        ))}
      </div>

      <div>
        {phase === "loading" ? <Alert tone="info" checking>Starting your camera…</Alert> : null}
        {running ? (
          <Alert tone="info" title={STEP_LABELS[STEPS[Math.min(stepIndex, STEPS.length - 1)]]}>
            {faceVisible ? "Hold still…" : "Position your face inside the circle."}
          </Alert>
        ) : null}
        {phase === "error" ? (
          <>
            <Alert tone="warn" title="We couldn't use your camera">
              {cameraError} If it still doesn&apos;t work, you can continue and the admin will review your identity by hand.
            </Alert>
            <div className="row" style={{ justifyContent: "center", marginTop: 12 }}>
              <button
                type="button"
                className="btn btn-glass btn-sm"
                onClick={() => {
                  updateFormData({ livenessStatus: "failed", selfieDataUrl: null });
                  setPhase("idle");
                }}
              >
                Continue without face check
              </button>
            </div>
          </>
        ) : null}
        {!running && phase !== "loading" && phase !== "error" && result ? (
          result === "passed" ? (
            <Alert tone="ok" title="Face check passed">
              All three actions were detected.
            </Alert>
          ) : (
            <Alert tone="warn" title="Face check marked for review">
              The admin will verify your identity from your documents. This can take longer.
            </Alert>
          )
        ) : null}
        {errors?.face ? (
          <Alert tone="err" style={{ marginTop: 8 }}>
            {errors.face}
          </Alert>
        ) : null}
      </div>
      {!running && phase !== "loading" ? (
        <div className="row" style={{ justifyContent: "center" }}>
          <button className="btn btn-glass" type="button" onClick={start}>
            {result ? "Do it again" : "Start face check"}
          </button>
        </div>
      ) : null}
    </>
  );
}
