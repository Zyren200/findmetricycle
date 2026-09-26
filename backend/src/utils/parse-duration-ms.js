function parseDurationMs(value) {
  if (!value) return 0;
  if (typeof value === "number" && Number.isFinite(value)) return value;

  const text = String(value).trim().toLowerCase();
  const numeric = Number(text);
  if (Number.isFinite(numeric)) {
    return numeric;
  }

  const match = text.match(/^(\d+)\s*(ms|s|m|h|d)$/);
  if (!match) return 0;

  const amount = Number(match[1]);
  const unit = match[2];
  const map = {
    ms: 1,
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000,
  };

  return amount * map[unit];
}

module.exports = parseDurationMs;

