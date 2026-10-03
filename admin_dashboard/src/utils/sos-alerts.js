// SOS alarm sound and desktop (browser) notifications for admins with SOS
// access. The sound is generated with Web Audio, so there's no audio file
// to load or miss.

let audioContext = null;

function getAudioContext() {
  if (typeof window === "undefined") return null;
  if (!audioContext) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return null;
    audioContext = new AudioContextClass();
  }
  return audioContext;
}

// Browsers only allow sound after the person has interacted with the page:
// the first click or key press anywhere unlocks it for later alarms.
export function installAlarmUnlock() {
  const unlock = () => {
    const context = getAudioContext();
    if (context && context.state === "suspended") context.resume().catch(() => {});
  };
  window.addEventListener("pointerdown", unlock, { once: true });
  window.addEventListener("keydown", unlock, { once: true });
}

/** A short two-tone siren, repeated [cycles] times. */
export function playSosAlarm({ cycles = 3 } = {}) {
  const context = getAudioContext();
  if (!context) return;
  if (context.state === "suspended") context.resume().catch(() => {});
  const start = context.currentTime + 0.05;
  for (let i = 0; i < cycles * 2; i += 1) {
    const at = start + i * 0.32;
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = "square";
    oscillator.frequency.value = i % 2 === 0 ? 880 : 660;
    gain.gain.setValueAtTime(0.0001, at);
    gain.gain.exponentialRampToValueAtTime(0.12, at + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.28);
    oscillator.connect(gain).connect(context.destination);
    oscillator.start(at);
    oscillator.stop(at + 0.3);
  }
}

export function browserAlertsSupported() {
  return typeof window !== "undefined" && "Notification" in window;
}

/** "default" (not asked yet), "granted", "denied" or "unsupported". */
export function browserAlertPermission() {
  return browserAlertsSupported() ? window.Notification.permission : "unsupported";
}

export async function requestBrowserAlerts() {
  if (!browserAlertsSupported()) return "unsupported";
  try {
    return await window.Notification.requestPermission();
  } catch (_) {
    return window.Notification.permission;
  }
}

/** Shows a desktop notification if the admin allowed them. */
export function showBrowserAlert({ title, body, tag, onClick }) {
  if (browserAlertPermission() !== "granted") return null;
  try {
    const notification = new window.Notification(title, { body, tag, requireInteraction: true });
    notification.onclick = () => {
      window.focus();
      if (onClick) onClick();
      notification.close();
    };
    return notification;
  } catch (_) {
    // Some browsers only allow notifications from a service worker.
    return null;
  }
}
