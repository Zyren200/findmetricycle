// Polls for ride offers a driver never responded to and reassigns them —
// the server-side half of Phase 3's "Request timeout". Uses a plain
// setInterval rather than a cron dependency since this only needs to run
// inside this one always-on process, not be scheduled externally.
const bookingService = require("./booking.service");
const { getIO } = require("../sockets");

const POLL_INTERVAL_MS = 5000;
// Unreachable drivers are measured in minutes, so a slower check is plenty.
const UNREACHABLE_CHECK_MS = 30 * 1000;

let timer = null;
let unreachableTimer = null;
let running = false;
let checkingUnreachable = false;

async function tick() {
  if (running) return; // don't overlap a slow run with the next tick
  running = true;
  try {
    const results = await bookingService.expireStaleOffers();
    if (!results.length) return;

    let io;
    try {
      io = getIO();
    } catch (_) {
      return; // socket layer not initialized (e.g. under test) — skip broadcasting
    }

    for (const { booking, reassignedDriver, staleDriverId, nearbyDrivers, reason } of results) {
      io.to(`passenger:${booking.passenger_id}`)
        .to(`user:${booking.passenger_id}`)
        .emit("passenger:booking_update", {
          booking,
          nearbyDrivers: nearbyDrivers || [],
          reason: reason || null,
        });

      // Tell the driver whose offer just timed out to drop the request
      // card — otherwise they'd keep seeing "New Ride Request" for a
      // booking that's already been handed to someone else.
      if (staleDriverId) {
        io.to(`driver:${staleDriverId}`).emit("driver:booking_expired", {
          bookingId: booking.id,
        });
      }

      if (reassignedDriver) {
        io.to(`driver:${reassignedDriver.id}`).emit("driver:booking_request", {
          booking,
        });
      }
    }
  } catch (error) {
    console.error("ride-offer-scheduler tick failed:", error.message);
  } finally {
    running = false;
  }
}

// Accepted rides whose driver went silent (phone died, no signal) go back
// to the passenger to choose another rider — see
// bookingService.releaseUnreachableDrivers.
async function releaseUnreachableTick() {
  if (checkingUnreachable) return;
  checkingUnreachable = true;
  try {
    const results = await bookingService.releaseUnreachableDrivers();
    if (!results.length) return;

    let io;
    try {
      io = getIO();
    } catch (_) {
      return;
    }

    for (const { booking, nearbyDrivers, staleDriverId, staleDriverUserId, reason, minutes } of results) {
      io.to(`passenger:${booking.passenger_id}`)
        .to(`user:${booking.passenger_id}`)
        .emit("passenger:booking_update", { booking, nearbyDrivers, reason });

      // Reaches the driver only if their app is still connected (e.g. GPS
      // stopped but data still works); otherwise the app catches up when
      // it reconnects and finds no active ride.
      io.to(`driver:${staleDriverId}`)
        .to(`user:${staleDriverUserId}`)
        .emit("driver:booking_closed", {
          bookingId: booking.id,
          status: "released",
          wentOffline: true,
          message: `We couldn't reach your phone for ${minutes} minutes, so this ride was given back to the passenger. You've been set to Offline.`,
        });
    }
  } catch (error) {
    console.error("unreachable-driver check failed:", error.message);
  } finally {
    checkingUnreachable = false;
  }
}

function start() {
  if (timer) return;
  timer = setInterval(tick, POLL_INTERVAL_MS);
  unreachableTimer = setInterval(releaseUnreachableTick, UNREACHABLE_CHECK_MS);
  // Never keep the process alive on their own (tests, shutdown).
  for (const handle of [timer, unreachableTimer]) {
    if (typeof handle.unref === "function") handle.unref();
  }
}

function stop() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
  if (unreachableTimer) {
    clearInterval(unreachableTimer);
    unreachableTimer = null;
  }
}

module.exports = { start, stop, releaseUnreachableTick };
