// Push notifications through Firebase Cloud Messaging (HTTP v1 API), so
// ride requests and ride updates reach a phone whose app is in the
// background or closed. In the foreground the apps already update from the
// live socket events, and Android doesn't show a notification-type push
// while the app is open, so nothing is shown twice.
//
// Needs a Firebase service-account key (Firebase console → Project settings
// → Service accounts → Generate new private key), configured with either
// FIREBASE_SERVICE_ACCOUNT_FILE (path to the JSON, relative to backend/) or
// FIREBASE_SERVICE_ACCOUNT_JSON (the JSON itself). Without it, push is off
// and everything else works as before.
const fs = require("fs");
const path = require("path");
const jwt = require("jsonwebtoken");
const pushTokenModel = require("../models/push-token.model");

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TIMEOUT_MS = 10000;

// Android notification channels, created by the app (MainActivity.kt).
const CHANNELS = {
  rideRequests: "ride_requests",
  rideUpdates: "ride_updates",
  announcements: "announcements",
};

let serviceAccount;
let accessToken = null;
let accessTokenExpiresAt = 0;

function loadServiceAccount() {
  if (serviceAccount !== undefined) return serviceAccount;
  serviceAccount = null;
  try {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
      ? process.env.FIREBASE_SERVICE_ACCOUNT_JSON
      : process.env.FIREBASE_SERVICE_ACCOUNT_FILE
        ? fs.readFileSync(path.resolve(__dirname, "../..", process.env.FIREBASE_SERVICE_ACCOUNT_FILE), "utf8")
        : null;
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      throw new Error("missing project_id / client_email / private_key");
    }
    serviceAccount = parsed;
  } catch (error) {
    console.warn(`Push notifications are off: can't read the Firebase service account (${error.message}).`);
  }
  return serviceAccount;
}

function isEnabled() {
  return Boolean(loadServiceAccount());
}

async function getAccessToken() {
  if (accessToken && Date.now() < accessTokenExpiresAt - 60 * 1000) return accessToken;
  const account = loadServiceAccount();
  const now = Math.floor(Date.now() / 1000);
  const assertion = jwt.sign(
    { iss: account.client_email, scope: SCOPE, aud: TOKEN_URL, iat: now, exp: now + 3600 },
    account.private_key,
    { algorithm: "RS256" }
  );
  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || !body.access_token) {
    throw new Error(`Firebase auth failed (${response.status}): ${body.error_description || body.error || "no token"}`);
  }
  accessToken = body.access_token;
  accessTokenExpiresAt = Date.now() + Number(body.expires_in || 3600) * 1000;
  return accessToken;
}

// FCM's answer for a token that will never work again (app uninstalled,
// token rotated, or from another Firebase project).
function isDeadToken(status, body) {
  const details = body?.error?.details || [];
  if (details.some((d) => ["UNREGISTERED", "SENDER_ID_MISMATCH"].includes(d.errorCode))) return true;
  return status === 404;
}

async function sendToToken(token, message) {
  const account = loadServiceAccount();
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${await getAccessToken()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message: { ...message, token } }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (response.ok) return { ok: true };
  const body = await response.json().catch(() => ({}));
  return { ok: false, dead: isDeadToken(response.status, body), status: response.status };
}

function buildMessage({ title, body, data = {}, channelId = CHANNELS.rideUpdates, ttlSeconds = null }) {
  // FCM data values must be strings.
  const stringData = Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [key, String(value)])
  );
  return {
    notification: { title, body },
    data: stringData,
    android: {
      priority: "HIGH",
      ...(ttlSeconds ? { ttl: `${ttlSeconds}s` } : {}),
      notification: { channel_id: channelId, sound: "default" },
    },
  };
}

async function sendToTokens(tokens, content) {
  if (!tokens.length || !isEnabled()) return { sent: 0, failed: 0 };
  const message = buildMessage(content);
  const results = await Promise.allSettled(tokens.map((token) => sendToToken(token, message)));

  const dead = [];
  let sent = 0;
  results.forEach((result, index) => {
    if (result.status === "fulfilled" && result.value.ok) sent += 1;
    else if (result.status === "fulfilled" && result.value.dead) dead.push(tokens[index]);
  });
  if (dead.length) await pushTokenModel.removeTokens(dead);
  return { sent, failed: tokens.length - sent };
}

// How a notification row is delivered as a push. Ride requests expire in
// seconds, so a phone that was off doesn't get a stale one hours later.
function contentFor(notification) {
  const metadata = notification.metadata || {};
  const isRideRequest = notification.type === "ride_request";
  return {
    title: notification.title,
    body: notification.body || "",
    data: { type: notification.type, notificationId: notification.id, bookingId: metadata.bookingId },
    channelId:
      notification.type === "announcement"
        ? CHANNELS.announcements
        : isRideRequest
          ? CHANNELS.rideRequests
          : CHANNELS.rideUpdates,
    ttlSeconds: isRideRequest ? 30 : null,
  };
}

/** Pushes a notification to every device of one user. Never throws. */
async function notifyUser(userId, notification) {
  if (!isEnabled() || !userId || !notification) return;
  try {
    await sendToTokens(await pushTokenModel.listTokensForUser(userId), contentFor(notification));
  } catch (error) {
    console.warn("push to user failed:", error.message);
  }
}

/** Pushes an announcement to everyone in its audience. Never throws. */
async function notifyAudience(audience, notification) {
  if (!isEnabled() || !notification) return;
  try {
    await sendToTokens(await pushTokenModel.listTokensForAudience(audience), contentFor(notification));
  } catch (error) {
    console.warn("push to audience failed:", error.message);
  }
}

module.exports = {
  CHANNELS,
  isEnabled,
  notifyUser,
  notifyAudience,
  sendToTokens,
  buildMessage,
  contentFor,
};
