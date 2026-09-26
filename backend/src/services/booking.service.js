const db = require("../config/db");
const bookingStatus = require("../constants/booking-status");
const bookingModel = require("../models/booking.model");
const driverModel = require("../models/driver.model");
const fareModel = require("../models/fare.model");
const ratingModel = require("../models/rating.model");
const matchingService = require("./matching.service");
const { haversineKm } = require("../utils/haversine");
const { calculateFare, calculateFareBreakdown } = require("../utils/fare");
const { decorateBookingRecord } = require("../utils/ride-progress");
const ApiError = require("../utils/api-error");
const env = require("../config/env");
const { isInsideGeofence } = require("../utils/geofence");
const notificationService = require("./notification.service");
const { MIN_PASSENGERS, MAX_PASSENGERS } = require("../constants/fare");
const { toPublicDriver } = require("../utils/public-driver");

// How many of the nearest online riders the passenger gets to pick from.
const NEARBY_DRIVER_LIMIT = 10;

// Riders who already declined (or let expire) a given booking, so they
// aren't offered to that passenger again. In-memory is enough: a pending
// booking only lives for minutes, and entries are dropped once it's
// accepted or cancelled.
const declinedDriversByBooking = new Map();

function rememberDeclinedDriver(bookingId, driverId) {
  const key = Number(bookingId);
  const set = declinedDriversByBooking.get(key) || new Set();
  set.add(Number(driverId));
  declinedDriversByBooking.set(key, set);
}

function forgetBooking(bookingId) {
  declinedDriversByBooking.delete(Number(bookingId));
}

function declinedDriverIds(bookingId) {
  return [...(declinedDriversByBooking.get(Number(bookingId)) || [])];
}

// Nearest online, idle riders for this booking's pickup, minus anyone who
// already turned it down — shaped for the passenger's device.
async function listChoosableDrivers(booking) {
  const drivers = await matchingService.listNearestAvailableDrivers(
    booking.pickup_lat,
    booking.pickup_lng,
    NEARBY_DRIVER_LIMIT,
    declinedDriverIds(booking.id)
  );
  return drivers.map(toPublicDriver);
}

const MAX_DISTANCE_OVERAGE_RATIO = 1.5;
const MAX_DISTANCE_OVERAGE_KM = 1;

function withRideProgress(booking) {
  return decorateBookingRecord(booking);
}

// Notification failures should never block the ride flow itself.
async function notifySafe(payload) {
  try {
    await notificationService.createNotification(payload);
  } catch (err) {
    // swallow
  }
}

async function createBookingAndFindDriver(payload) {
  const coords = [
    payload.pickupLat,
    payload.pickupLng,
    payload.dropoffLat,
    payload.dropoffLng,
  ].map(Number);

  if (coords.some((value) => Number.isNaN(value))) {
    throw new ApiError(400, "Valid pickup/drop-off latitude and longitude are required.");
  }

  // Enforced here (not as route middleware) so the socket find_ride path
  // is covered too.
  if (env.geofence.enabled) {
    const [pickupLat, pickupLng, dropoffLat, dropoffLng] = coords;
    if (!isInsideGeofence(pickupLat, pickupLng) || !isInsideGeofence(dropoffLat, dropoffLng)) {
      throw new ApiError(403, "Service is only available within Guiuan area.");
    }
  }

  const active = await bookingModel.findActiveByPassenger(payload.passengerId);
  if (active) {
    let activeDriver = null;
    if (active.driver_id) {
      activeDriver = toPublicDriver(await driverModel.findById(active.driver_id));
    }
    // Still waiting for the passenger to pick a rider — hand the list back
    // so the app can resume the choose step instead of getting stuck.
    const waitingForChoice = active.status === bookingStatus.PENDING && !active.driver_id;
    return {
      booking: withRideProgress(active),
      matchedDriver: activeDriver,
      nearbyDrivers: waitingForChoice ? await listChoosableDrivers(active) : [],
      message: "You already have an active booking.",
    };
  }

  const passengerCount = payload.passengerCount ? Number(payload.passengerCount) : 1;
  if (
    !Number.isInteger(passengerCount) ||
    passengerCount < MIN_PASSENGERS ||
    passengerCount > MAX_PASSENGERS
  ) {
    throw new ApiError(400, `passengerCount must be between ${MIN_PASSENGERS} and ${MAX_PASSENGERS}.`);
  }

  const distanceKm = haversineKm(
    Number(payload.pickupLat),
    Number(payload.pickupLng),
    Number(payload.dropoffLat),
    Number(payload.dropoffLng)
  );

  const fareSettings = await fareModel.getCurrentFareSettings();
  const fareBreakdown = calculateFareBreakdown(distanceKm, fareSettings, passengerCount);
  const estimatedFare = fareBreakdown.total;

  const booking = await bookingModel.createBooking({
    passengerId: payload.passengerId,
    pickupAddress: payload.pickupAddress,
    pickupLat: payload.pickupLat,
    pickupLng: payload.pickupLng,
    dropoffAddress: payload.dropoffAddress,
    dropoffLat: payload.dropoffLat,
    dropoffLng: payload.dropoffLng,
    passengerCount,
    distanceKm,
    estimatedFare,
    fareBreakdown,
  });

  await notifySafe({
    type: "new_booking",
    title: "New booking request",
    body: `Booking #${booking.id} requested from ${payload.pickupAddress || "pickup"}.`,
    recipientRole: "admin",
    metadataJson: { bookingId: booking.id, passengerId: payload.passengerId },
  });

  if (payload.autoAssign === false) {
    const nearbyDrivers = await listChoosableDrivers(booking);
    return {
      booking: withRideProgress(booking),
      pickupPin: booking.pickup_pin,
      nearbyDrivers,
      message: nearbyDrivers.length
        ? "Select a driver to continue."
        : "No available driver found yet. Booking is waiting in queue.",
    };
  }

  const matchedDriver = await matchingService.findNearestAvailableDriver(
    payload.pickupLat,
    payload.pickupLng
  );

  if (!matchedDriver) {
    return {
      booking: withRideProgress(booking),
      pickupPin: booking.pickup_pin,
      matchedDriver: null,
      message: "No available driver found yet. Booking is waiting in queue.",
    };
  }

  const { assigned, booking: updatedBooking } = await bookingModel.assignDriver(
    booking.id,
    matchedDriver.id
  );

  return {
    booking: withRideProgress(updatedBooking),
    pickupPin: booking.pickup_pin,
    matchedDriver: assigned ? toPublicDriver(matchedDriver) : null,
    message: assigned
      ? "Driver request sent."
      : "No available driver found yet. Booking is waiting in queue.",
  };
}

async function passengerChooseDriver(payload) {
  const booking = await bookingModel.findById(payload.bookingId);
  if (!booking) throw new ApiError(404, "Booking not found.");
  if (Number(booking.passenger_id) !== Number(payload.passengerId)) {
    throw new ApiError(403, "Booking does not belong to this passenger.");
  }
  if (booking.status !== bookingStatus.PENDING) {
    throw new ApiError(400, "Booking is no longer pending.");
  }
  if (booking.driver_id) {
    throw new ApiError(400, "Driver already assigned.");
  }

  // Re-check against the live list: the rider may have gone offline,
  // taken another ride, or already declined this booking since the
  // passenger's list was fetched.
  const drivers = await matchingService.listNearestAvailableDrivers(
    booking.pickup_lat,
    booking.pickup_lng,
    NEARBY_DRIVER_LIMIT,
    declinedDriverIds(booking.id)
  );
  const chosen = drivers.find((d) => Number(d.id) === Number(payload.driverId));
  if (!chosen) {
    throw new ApiError(409, "This rider is no longer available. Please choose another rider.");
  }

  const { assigned, booking: updated } = await bookingModel.assignDriver(booking.id, chosen.id);
  if (!assigned) {
    throw new ApiError(409, "This booking was already assigned to another driver.");
  }

  // In-app notification for the rider, so the request also shows up in
  // their notification list if the realtime event is missed.
  await notifySafe({
    type: "ride_request",
    title: "New ride request",
    body: `A passenger chose you for a ride from ${updated.pickup_address || "their pickup point"}.`,
    userId: chosen.user_id,
    recipientRole: "driver",
    metadataJson: { bookingId: updated.id },
  });

  return {
    booking: withRideProgress(updated),
    driver: toPublicDriver(chosen),
    driverUserId: chosen.user_id,
  };
}

// Refreshes the rider list while the passenger is still choosing.
async function listNearbyDriversForBooking({ bookingId, passengerId }) {
  const booking = await bookingModel.findById(bookingId);
  if (!booking) throw new ApiError(404, "Booking not found.");
  if (Number(booking.passenger_id) !== Number(passengerId)) {
    throw new ApiError(403, "Booking does not belong to this passenger.");
  }
  const waitingForChoice = booking.status === bookingStatus.PENDING && !booking.driver_id;
  return {
    booking: withRideProgress(booking),
    nearbyDrivers: waitingForChoice ? await listChoosableDrivers(booking) : [],
  };
}

// The offer currently waiting on this rider, used by the driver app as a
// fallback when the realtime "driver:booking_request" event was missed.
async function getIncomingOfferForDriver(driverId) {
  const booking = await bookingModel.findActiveByDriver(driverId);
  if (!booking || booking.status !== bookingStatus.PENDING) return null;
  return withRideProgress(booking);
}

async function driverRespond(payload) {
  if (!["accept", "decline"].includes(payload.action)) {
    throw new ApiError(400, "Action must be either 'accept' or 'decline'.");
  }

  const booking = await bookingModel.findById(payload.bookingId);
  if (!booking) {
    throw new ApiError(404, "Booking not found.");
  }

  if (!booking.driver_id || Number(booking.driver_id) !== Number(payload.driverId)) {
    throw new ApiError(403, "Booking is not assigned to this driver.");
  }

  if (booking.status !== bookingStatus.PENDING) {
    throw new ApiError(400, "Booking is no longer pending.");
  }

  if (payload.action === "accept") {
    const { changed, booking: accepted } = await bookingModel.markAccepted(
      payload.bookingId,
      payload.driverId
    );
    if (!changed) {
      throw new ApiError(409, "This ride request is no longer available.");
    }
    forgetBooking(accepted.id);
    await notifySafe({
      type: "booking_accepted",
      title: "Driver assigned",
      body: `${accepted.driver_name || "A driver"} accepted your ride request.`,
      userId: accepted.passenger_id,
      recipientRole: "passenger",
      metadataJson: { bookingId: accepted.id },
    });
    return {
      booking: withRideProgress(accepted),
      reassignedDriver: null,
    };
  }

  const { changed: declinedNow, booking: declined } = await bookingModel.clearAssignedDriver(
    payload.bookingId,
    payload.driverId,
    payload.reason || "Driver declined booking."
  );
  if (!declinedNow) {
    throw new ApiError(409, "This ride request is no longer available.");
  }

  // The passenger picked this rider, so the choice goes back to them (with
  // a fresh list) rather than silently handing the ride to someone else.
  rememberDeclinedDriver(payload.bookingId, payload.driverId);
  await notifySafe({
    type: "booking_declined",
    title: "Rider unavailable",
    body: "The rider you chose declined. Please choose another rider.",
    userId: declined.passenger_id,
    recipientRole: "passenger",
    metadataJson: { bookingId: declined.id },
  });

  return {
    booking: withRideProgress(declined),
    reassignedDriver: null,
    nearbyDrivers: await listChoosableDrivers(declined),
    reason: "declined",
  };
}

async function arriveAtPickup(payload) {
  const driverActive = await bookingModel.findActiveByDriver(payload.driverId);
  if (!driverActive || Number(driverActive.id) !== Number(payload.bookingId)) {
    throw new ApiError(404, "No matching active booking for this driver.");
  }

  if (driverActive.status !== bookingStatus.ACCEPTED) {
    throw new ApiError(400, "Arrival can only be marked from accepted state.");
  }

  const arriving = await bookingModel.markArriving(payload.bookingId);
  // The passenger may have cancelled between the check above and the update.
  if (arriving.status !== bookingStatus.ARRIVING) {
    throw new ApiError(409, "This ride is no longer active.");
  }
  await notifySafe({
    type: "driver_arrived",
    title: "Your driver has arrived",
    body: "Give the driver your pickup PIN to start the trip.",
    userId: arriving.passenger_id,
    recipientRole: "passenger",
    metadataJson: { bookingId: arriving.id },
  });
  return withRideProgress(arriving);
}

// Phase 4's NO_SHOW terminal state — the booking table itself has no
// separate no_show status, so this closes the ride the same way a
// cancellation does (status='cancelled', cancelled_by='driver') and
// files a complaint record so it surfaces in the admin Report Center for
// review, matching Scenario D end to end.
async function markNoShow(payload) {
  const driverActive = await bookingModel.findActiveByDriver(payload.driverId);
  if (!driverActive || Number(driverActive.id) !== Number(payload.bookingId)) {
    throw new ApiError(404, "No matching active booking for this driver.");
  }

  if (driverActive.status !== bookingStatus.ARRIVING) {
    throw new ApiError(400, "No-show can only be reported after marking arrival at pickup.");
  }

  const { changed, booking: cancelled } = await bookingModel.markCancelled(payload.bookingId, "driver");
  if (!changed) {
    throw new ApiError(400, "This ride can no longer be marked as a no-show.");
  }

  await notifySafe({
    type: "booking_cancelled",
    title: "Ride cancelled",
    body: "Your driver reported that you weren't at the pickup location.",
    userId: cancelled.passenger_id,
    recipientRole: "passenger",
    metadataJson: { bookingId: cancelled.id, reason: "no_show" },
  });

  try {
    // Lazy require avoids a circular dependency (complaint.service also
    // touches booking data) at module load time.
    const complaintService = require("./complaint.service");
    await complaintService.createComplaint({
      reporterId: driverActive.driver_user_id,
      bookingId: payload.bookingId,
      category: "no_show",
      description: payload.note || "Passenger was not present at the pickup location.",
    });
  } catch (err) {
    // A failed complaint record should never block closing out the ride.
  }

  return withRideProgress(cancelled);
}

async function startRide(payload) {
  const driverActive = await bookingModel.findActiveByDriver(payload.driverId);
  if (!driverActive || Number(driverActive.id) !== Number(payload.bookingId)) {
    throw new ApiError(404, "No matching active booking for this driver.");
  }

  if (![bookingStatus.ACCEPTED, bookingStatus.ARRIVING].includes(driverActive.status)) {
    throw new ApiError(400, "Ride can only be started from accepted or arriving state.");
  }

  // The driver must confirm the passenger's 4-digit pickup PIN before the
  // trip can start — the one hard gate between "arrived" and "trip
  // started" (see Phase 5 / Phase 4 PASSENGER_VERIFIED step).
  const result = await bookingModel.verifyPickupPin(payload.bookingId, payload.pin);
  if (!result.ok) {
    if (result.reason === "locked") {
      throw new ApiError(429, "Too many incorrect PIN attempts. Ask the passenger to confirm their identity another way, or contact support.");
    }
    if (result.reason === "mismatch") {
      throw new ApiError(400, `Incorrect PIN. ${result.attemptsRemaining} attempt(s) remaining.`);
    }
    throw new ApiError(400, "This booking has no pickup PIN to verify.");
  }

  const started = await bookingModel.markOngoing(payload.bookingId);
  if (started.status !== bookingStatus.ONGOING) {
    throw new ApiError(409, "This ride is no longer active.");
  }
  await notifySafe({
    type: "ride_started",
    title: "Trip started",
    body: "Your ride is now in progress.",
    userId: started.passenger_id,
    recipientRole: "passenger",
    metadataJson: { bookingId: started.id },
  });
  return withRideProgress(started);
}

// Called on a fixed interval by ride-offer-scheduler.service.js. Any
// booking whose driver didn't respond within the offer window is treated
// exactly like a decline: clear the driver and hand it to the next
// nearest one (same single-driver exclusion as the manual decline path).
async function expireStaleOffers() {
  const expired = await bookingModel.findExpiredPendingOffers();
  const results = [];

  for (const booking of expired) {
    const staleDriverId = booking.driver_id;
    const { changed, booking: cleared } = await bookingModel.clearAssignedDriver(
      booking.id,
      staleDriverId,
      "Driver did not respond in time."
    );
    // The driver accepted (or declined) between the SELECT and now — leave it alone.
    if (!changed) continue;

    // Same as a decline: back to the passenger to choose another rider.
    rememberDeclinedDriver(booking.id, staleDriverId);
    results.push({
      booking: withRideProgress(cleared),
      reassignedDriver: null,
      staleDriverId,
      nearbyDrivers: await listChoosableDrivers(cleared),
      reason: "expired",
    });
  }

  return results;
}

async function completeRide(payload) {
  const driverActive = await bookingModel.findActiveByDriver(payload.driverId);
  if (!driverActive || Number(driverActive.id) !== Number(payload.bookingId)) {
    throw new ApiError(404, "No matching active booking for this driver.");
  }

  if (driverActive.status !== bookingStatus.ONGOING) {
    throw new ApiError(400, "Ride can only be completed from ongoing state.");
  }

  const fareSettings = await fareModel.getCurrentFareSettings();
  const estimatedDistanceKm = Number(driverActive.distance_km);
  let finalDistanceKm = payload.actualDistanceKm
    ? Number(payload.actualDistanceKm)
    : estimatedDistanceKm;

  if (Number.isNaN(finalDistanceKm) || finalDistanceKm < 0) {
    throw new ApiError(400, "actualDistanceKm must be a valid positive number.");
  }

  // The actual distance is reported by the driver's app, so it can't be
  // trusted blindly: allow for detours, but never more than
  // MAX_DISTANCE_OVERAGE_RATIO of the booked route (+ a small allowance).
  if (estimatedDistanceKm > 0) {
    const maxDistanceKm = estimatedDistanceKm * MAX_DISTANCE_OVERAGE_RATIO + MAX_DISTANCE_OVERAGE_KM;
    finalDistanceKm = Math.min(finalDistanceKm, maxDistanceKm);
  }

  const finalFare = calculateFare(finalDistanceKm, fareSettings, driverActive.passenger_count);

  // Completing the booking and crediting the driver happen together or not
  // at all; a double-tapped "Complete" only credits once.
  const changed = await db.withTransaction(async (client) => {
    const result = await bookingModel.markCompleted(payload.bookingId, finalFare, client);
    if (result.changed) {
      await driverModel.addEarningsAndRideCount(payload.driverId, finalFare, client);
    }
    return result.changed;
  });
  if (!changed) {
    throw new ApiError(409, "This ride was already completed.");
  }
  const completed = await bookingModel.findById(payload.bookingId);

  await notifySafe({
    type: "ride_completed",
    title: "Trip completed",
    body: `Total fare: PHP ${finalFare.toFixed(2)}. Rate your driver!`,
    userId: completed.passenger_id,
    recipientRole: "passenger",
    metadataJson: { bookingId: completed.id, finalFare },
  });
  await notifySafe({
    type: "ride_completed",
    title: "Ride completed",
    body: `You earned PHP ${finalFare.toFixed(2)} from this ride.`,
    userId: completed.driver_user_id,
    recipientRole: "driver",
    metadataJson: { bookingId: completed.id, finalFare },
  });

  return withRideProgress(completed);
}

async function cancelRide(payload) {
  const booking = await bookingModel.findById(payload.bookingId);
  if (!booking) {
    throw new ApiError(404, "Booking not found.");
  }

  if (Number(booking.passenger_id) !== Number(payload.passengerId)) {
    throw new ApiError(403, "Booking does not belong to this passenger.");
  }

  if (![bookingStatus.PENDING, bookingStatus.ACCEPTED].includes(booking.status)) {
    throw new ApiError(400, "Booking can no longer be cancelled.");
  }

  const { changed, booking: cancelled } = await bookingModel.markCancelled(payload.bookingId, "passenger");
  if (!changed) {
    throw new ApiError(400, "Booking can no longer be cancelled.");
  }
  forgetBooking(cancelled.id);

  await notifySafe({
    type: "booking_cancelled",
    title: "Booking cancelled",
    body: `Booking #${payload.bookingId} was cancelled by the passenger.`,
    recipientRole: "admin",
    metadataJson: { bookingId: payload.bookingId },
  });

  if (cancelled.driver_user_id) {
    await notifySafe({
      type: "booking_cancelled",
      title: "Ride cancelled",
      body: "The passenger cancelled this ride.",
      userId: cancelled.driver_user_id,
      recipientRole: "driver",
      metadataJson: { bookingId: cancelled.id },
    });
  }

  return withRideProgress(cancelled);
}

async function rateCompletedRide(payload) {
  if (!Number.isInteger(payload.stars) || payload.stars < 1 || payload.stars > 5) {
    throw new ApiError(400, "stars must be an integer from 1 to 5.");
  }

  const booking = await bookingModel.findById(payload.bookingId);
  if (!booking) {
    throw new ApiError(404, "Booking not found.");
  }

  if (Number(booking.passenger_id) !== Number(payload.passengerId)) {
    throw new ApiError(403, "Booking does not belong to this passenger.");
  }

  if (booking.status !== bookingStatus.COMPLETED) {
    throw new ApiError(400, "Only completed rides can be rated.");
  }

  if (!booking.driver_id) {
    throw new ApiError(400, "Booking has no driver to rate.");
  }

  const rating = await ratingModel.createRating({
    bookingId: payload.bookingId,
    passengerId: payload.passengerId,
    driverId: booking.driver_id,
    stars: payload.stars,
    feedback: payload.feedback,
  });

  await driverModel.refreshDriverRating(booking.driver_id);

  if (booking.driver_user_id) {
    await notifySafe({
      type: "new_rating",
      title: "New rating received",
      body: `A passenger rated you ${payload.stars} star${payload.stars === 1 ? "" : "s"}.`,
      userId: booking.driver_user_id,
      recipientRole: "driver",
      metadataJson: { bookingId: payload.bookingId, stars: payload.stars },
    });
  }

  return rating;
}

module.exports = {
  createBookingAndFindDriver,
  passengerChooseDriver,
  listNearbyDriversForBooking,
  getIncomingOfferForDriver,
  driverRespond,
  arriveAtPickup,
  startRide,
  markNoShow,
  completeRide,
  cancelRide,
  rateCompletedRide,
  expireStaleOffers,
};
