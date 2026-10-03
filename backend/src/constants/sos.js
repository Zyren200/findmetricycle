// How long an SOS may stay open (nobody has acknowledged it) before every
// active Super Admin is alerted. The one place to change it; set
// SOS_ESCALATION_MINUTES in .env to override the 2-minute default.
const SOS_ESCALATION_AFTER_MS = Math.max(0.25, Number(process.env.SOS_ESCALATION_MINUTES) || 2) * 60 * 1000;

// How often the server looks for alerts past that time.
const SOS_ESCALATION_CHECK_MS = 15 * 1000;

// sos_alerts.status values. 'active' is an open alert (the name predates
// acknowledging).
const SOS_STATUS = {
  OPEN: "active",
  ACKNOWLEDGED: "acknowledged",
  RESOLVED: "resolved",
};

module.exports = {
  SOS_ESCALATION_AFTER_MS,
  SOS_ESCALATION_CHECK_MS,
  SOS_STATUS,
};
