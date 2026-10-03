// Counts failures per key (e.g. one admin account) in a sliding window.
// express-rate-limit only keys on IP; this caps password guessing against a
// single account from many IPs. In-memory, like the socket limiter — fine
// for the single server this runs on.
function createFailureLimiter({ windowMs, max }) {
  const failures = new Map(); // key -> array of failure timestamps

  function recent(key) {
    const now = Date.now();
    const hits = (failures.get(key) || []).filter((t) => now - t < windowMs);
    if (hits.length) failures.set(key, hits);
    else failures.delete(key);
    return hits;
  }

  return {
    isBlocked(key) {
      return recent(key).length >= max;
    },
    recordFailure(key) {
      const hits = recent(key);
      hits.push(Date.now());
      failures.set(key, hits);
    },
    reset(key) {
      failures.delete(key);
    },
  };
}

module.exports = { createFailureLimiter };
