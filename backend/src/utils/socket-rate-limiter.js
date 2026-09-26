// Minimal sliding-window limiter for Socket.IO event handlers — REST
// routes get express-rate-limit, but socket events bypass that entirely,
// so high-frequency/sensitive events (location updates, booking creation)
// need their own guard against a compromised or misbehaving client
// flooding the server.
const buckets = new Map();

function isRateLimited(key, { windowMs, max }) {
  const now = Date.now();
  const bucket = buckets.get(key);

  if (!bucket || now - bucket.windowStart > windowMs) {
    buckets.set(key, { windowStart: now, count: 1 });
    return false;
  }

  bucket.count += 1;
  return bucket.count > max;
}

module.exports = { isRateLimited };
