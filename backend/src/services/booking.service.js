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
const notificationService = require("./notification.service");
const { MIN_PASSENGERS, MAX_PASSENGERS } = require("../constants/fare");

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

  const active = await bookingModel.findActiveByPassenger(payload.passengerId);
  if (active) {
    let activeDriver = null;
    if (active.driver_id) {
      activeDriver = await driverModel.findById(active.driver_id);
    }
    return {
      booking: withRideProgress(active),
      matchedDriver: activeDriver,
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
    const nearbyDrivers = await matchingService.listNearestAvailableDrivers(
      payload.pickupLat,
      payload.pickupLng,
      5
    );
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
    matchedDriver: assigned
      ? {
          ...matchedDriver,
          distanceToPickupKm: matchedDriver.distanceToPickupKm,
          rating: matchedDriver.rating_avg,
        }
      : null,
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

  const drivers = await matchingService.listNearestAvailableDrivers(
    booking.pickup_lat,
    booking.pickup_lng,
    10
  );
  const chosen = drivers.find((d) => Number(d.id) === Number(payload.driverId));
  if (!chosen) {
    throw new ApiError(404, "Selected driver is not available.");
  }

  const { assigned, booking: updated } = await bookingModel.assignDriver(booking.id, chosen.id);
  if (!assigned) {
    throw new ApiError(409, "This booking was already assigned to another driver.");
  }
  return { booking: withRideProgress(updated), driver: chosen };
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
    const accepted = await bookingModel.markAccepted(payload.bookingId);
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

  const declined = await bookingModel.clearAssignedDriver(
    payload.bookingId,
    payload.reason || "Driver declined booking."
  );

  const reassignedDriver = await matchingService.findNearestAvailableDriver(
    declined.pickup_lat,
    declined.pickup_lng,
    [payload.driverId]
  );

  if (!reassignedDriver) {
    return {
      booking: withRideProgress(declined),
      reassignedDriver: null,
    };
  }

  const { assigned, booking: reassignedBooking } = await bookingModel.assignDriver(
    payload.bookingId,
    reassignedDriver.id
  );
  return {
    booking: withRideProgress(reassignedBooking),
    reassignedDriver: assigned ? reassignedDriver : null,
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
    const cleared = await bookingModel.clearAssignedDriver(booking.id, "Driver did not respond in time.");

    const reassignedDriver = await matchingService.findNearestAvailableDriver(
      cleared.pickup_lat,
      cleared.pickup_lng,
      [staleDriverId]
    );

    if (!reassignedDriver) {
      results.push({ booking: withRideProgress(cleared), reassignedDriver: null, staleDriverId });
      continue;
    }

    const { assigned, booking: reassignedBooking } = await bookingModel.assignDriver(
      booking.id,
      reassignedDriver.id
    );

    results.push({
      booking: withRideProgress(reassignedBooking),
      reassignedDriver: assigned ? reassignedDriver : null,
      staleDriverId,
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
  const finalDistanceKm = payload.actualDistanceKm
    ? Number(payload.actualDistanceKm)
    : Number(driverActive.distance_km);

  if (Number.isNaN(finalDistanceKm) || finalDistanceKm < 0) {
    throw new ApiError(400, "actualDistanceKm must be a valid positive number.");
  }

  const finalFare = calculateFare(finalDistanceKm, fareSettings, driverActive.passenger_count);

  const completed = await bookingModel.markCompleted(payload.bookingId, finalFare);
  await driverModel.addEarningsAndRideCount(payload.driverId, finalFare);

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
  driverRespond,
  arriveAtPickup,
  startRide,
  markNoShow,
  completeRide,
  cancelRide,
  rateCompletedRide,
  expireStaleOffers,
};
