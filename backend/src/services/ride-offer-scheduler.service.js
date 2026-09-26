// Polls for ride offers a driver never responded to and reassigns them —
// the server-side half of Phase 3's "Request timeout". Uses a plain
// setInterval rather than a cron dependency since this only needs to run
// inside this one always-on process, not be scheduled externally.
const bookingService = require("./booking.service");
const { getIO } = require("../sockets");

const POLL_INTERVAL_MS = 5000;

let timer = null;
let running = false;

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

    for (const { booking, reassignedDriver, staleDriverId } of results) {
      io.to(`passenger:${booking.passenger_id}`).emit("passenger:booking_update", {
        booking,
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

function start() {
  if (timer) return;
  timer = setInterval(tick, POLL_INTERVAL_MS);
  if (typeof timer.unref === "function") {
    timer.unref(); // never keep the process alive on its own (tests, shutdown)
  }
}

function stop() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

module.exports = { start, stop };
