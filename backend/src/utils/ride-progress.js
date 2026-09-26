const { haversineKm } = require("./haversine");

const RIDE_STATES = Object.freeze({
  BOOKING_CREATED: "booking_created",
  SEARCHING_DRIVER: "searching_driver",
  DRIVER_ACCEPTED: "driver_accepted",
  DRIVER_ARRIVING: "driver_arriving",
  PASSENGER_PICKED_UP: "passenger_picked_up",
  RIDE_IN_PROGRESS: "ride_in_progress",
  RIDE_COMPLETED: "ride_completed",
  CANCELLED: "cancelled",
});

const FLOW_STEPS = Object.freeze([
  { key: RIDE_STATES.BOOKING_CREATED, label: "Booking Created" },
  { key: RIDE_STATES.SEARCHING_DRIVER, label: "Searching Driver" },
  { key: RIDE_STATES.DRIVER_ACCEPTED, label: "Driver Accepted" },
  { key: RIDE_STATES.DRIVER_ARRIVING, label: "Driver Arriving" },
  { key: RIDE_STATES.PASSENGER_PICKED_UP, label: "Passenger Picked Up" },
  { key: RIDE_STATES.RIDE_IN_PROGRESS, label: "Ride In Progress" },
  { key: RIDE_STATES.RIDE_COMPLETED, label: "Ride Completed" },
]);

const RIDE_STATE_LABELS = Object.freeze({
  [RIDE_STATES.BOOKING_CREATED]: "Booking Created",
  [RIDE_STATES.SEARCHING_DRIVER]: "Searching Driver",
  [RIDE_STATES.DRIVER_ACCEPTED]: "Driver Accepted",
  [RIDE_STATES.DRIVER_ARRIVING]: "Driver Arriving",
  [RIDE_STATES.PASSENGER_PICKED_UP]: "Passenger Picked Up",
  [RIDE_STATES.RIDE_IN_PROGRESS]: "Ride In Progress",
  [RIDE_STATES.RIDE_COMPLETED]: "Ride Completed",
  [RIDE_STATES.CANCELLED]: "Cancelled",
});

const DRIVER_ARRIVAL_THRESHOLD_KM = 0.35;

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function getBookingStatus(record) {
  return String(record?.status || record?.booking_status || "").trim().toLowerCase();
}

function getDriverCoordinates(record) {
  const lat =
    toNumber(record?.current_lat) ??
    toNumber(record?.driver_current_lat) ??
    toNumber(record?.driver_lat);
  const lng =
    toNumber(record?.current_lng) ??
    toNumber(record?.driver_current_lng) ??
    toNumber(record?.driver_lng);

  if (lat === null || lng === null) {
    return null;
  }

  return { lat, lng };
}

function hasDriverArrived(record, thresholdKm = DRIVER_ARRIVAL_THRESHOLD_KM) {
  const pickupLat = toNumber(record?.pickup_lat);
  const pickupLng = toNumber(record?.pickup_lng);
  const driver = getDriverCoordinates(record);

  if (pickupLat === null || pickupLng === null || !driver) {
    return false;
  }

  return haversineKm(driver.lat, driver.lng, pickupLat, pickupLng) <= thresholdKm;
}

function determineRideState(record) {
  const bookingStatus = getBookingStatus(record);
  if (!bookingStatus) {
    return null;
  }

  if (bookingStatus === "cancelled") {
    return RIDE_STATES.CANCELLED;
  }

  if (bookingStatus === "completed") {
    return RIDE_STATES.RIDE_COMPLETED;
  }

  if (bookingStatus === "ongoing") {
    return RIDE_STATES.RIDE_IN_PROGRESS;
  }

  if (bookingStatus === "accepted") {
    return hasDriverArrived(record) ? RIDE_STATES.DRIVER_ARRIVING : RIDE_STATES.DRIVER_ACCEPTED;
  }

  if (bookingStatus === "pending") {
    return RIDE_STATES.SEARCHING_DRIVER;
  }

  return bookingStatus || null;
}

function buildRideProgress(record) {
  const currentState = determineRideState(record);
  if (!currentState) {
    return null;
  }

  const currentLabel = RIDE_STATE_LABELS[currentState] || currentState;
  if (currentState === RIDE_STATES.CANCELLED) {
    const steps = FLOW_STEPS.map((step, index) => ({
      ...step,
      status: index === 0 ? "completed" : "skipped",
    }));

    return {
      currentState,
      currentLabel,
      currentStepIndex: -1,
      currentStep: null,
      completedSteps: 1,
      totalSteps: FLOW_STEPS.length,
      progressPercent: Math.round((1 / FLOW_STEPS.length) * 100),
      steps,
    };
  }

  const currentStepIndex = FLOW_STEPS.findIndex((step) => step.key === currentState);
  const completedSteps = currentStepIndex < 0 ? 0 : currentStepIndex;
  const steps = FLOW_STEPS.map((step, index) => {
    if (currentStepIndex < 0) {
      return {
        ...step,
        status: "upcoming",
      };
    }

    if (index < currentStepIndex) {
      return {
        ...step,
        status: "completed",
      };
    }

    if (index === currentStepIndex) {
      return {
        ...step,
        status: "active",
      };
    }

    return {
      ...step,
      status: "upcoming",
    };
  });

  return {
    currentState,
    currentLabel,
    currentStepIndex,
    currentStep: currentStepIndex >= 0 ? FLOW_STEPS[currentStepIndex] : null,
    completedSteps,
    totalSteps: FLOW_STEPS.length,
    progressPercent:
      currentStepIndex >= 0
        ? Math.round((currentStepIndex / (FLOW_STEPS.length - 1)) * 100)
        : 0,
    steps,
  };
}

// Never send the PIN hash (or the raw attempt counter, which is only
// meaningful to the verification logic) to either the driver or the
// passenger client — decorateBookingRecord is the shaping step used
// everywhere a booking gets attached to an HTTP response or socket event.
function omitPinInternals(booking) {
  const { pickup_pin_hash, pin_attempts, ...rest } = booking;
  return rest;
}

function decorateBookingRecord(booking) {
  if (!booking) {
    return null;
  }

  const safeBooking = omitPinInternals(booking);
  const rideProgress = buildRideProgress(safeBooking);
  if (!rideProgress) {
    return safeBooking;
  }

  return {
    ...safeBooking,
    rideState: rideProgress.currentState,
    rideStateLabel: rideProgress.currentLabel,
    rideProgress,
  };
}

module.exports = {
  RIDE_STATES,
  RIDE_STATE_LABELS,
  FLOW_STEPS,
  DRIVER_ARRIVAL_THRESHOLD_KM,
  toNumber,
  getBookingStatus,
  getDriverCoordinates,
  hasDriverArrived,
  determineRideState,
  buildRideProgress,
  decorateBookingRecord,
};
