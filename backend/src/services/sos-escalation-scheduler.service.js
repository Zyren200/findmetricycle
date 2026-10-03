// Checks for SOS alerts nobody has acknowledged within
// SOS_ESCALATION_AFTER_MS and alerts the Super Admins. The state lives in
// the database (sos_alerts.escalated_at), not in timers, so a restart
// doesn't lose or repeat an escalation.
const sosService = require("./sos.service");
const { SOS_ESCALATION_CHECK_MS } = require("../constants/sos");

let timer = null;
let running = false;

async function tick() {
  if (running) return; // don't overlap a slow run with the next tick
  running = true;
  try {
    await sosService.escalateOverdueAlerts();
  } catch (error) {
    console.error("SOS escalation check failed:", error.message);
  } finally {
    running = false;
  }
}

function start() {
  if (timer) return;
  timer = setInterval(tick, SOS_ESCALATION_CHECK_MS);
  // Never keep the process alive on its own (tests, shutdown).
  if (typeof timer.unref === "function") timer.unref();
}

function stop() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

module.exports = { start, stop, tick };
