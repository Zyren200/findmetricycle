require("./setup-env");

const {
  RIDE_STATES,
  buildRideProgress,
  decorateBookingRecord,
} = require("../src/utils/ride-progress");

describe("ride progress helper", () => {
  it("shows searching driver for a pending booking", () => {
    const progress = buildRideProgress({
      status: "pending",
      passenger_id: 1,
      driver_id: null,
    });

    expect(progress.currentState).toBe(RIDE_STATES.SEARCHING_DRIVER);
    expect(progress.steps[0].status).toBe("completed");
    expect(progress.steps[1].status).toBe("active");
  });

  it("shows driver arriving when the driver is near pickup", () => {
    const progress = buildRideProgress({
      status: "accepted",
      passenger_id: 1,
      driver_id: 9,
      pickup_lat: 14.5995,
      pickup_lng: 120.9842,
      current_lat: 14.5995,
      current_lng: 120.9842,
    });

    expect(progress.currentState).toBe(RIDE_STATES.DRIVER_ARRIVING);
    expect(progress.steps[0].status).toBe("completed");
    expect(progress.steps[1].status).toBe("completed");
    expect(progress.steps[2].status).toBe("completed");
    expect(progress.steps[3].status).toBe("active");
  });

  it("shows ride in progress once the ride starts", () => {
    const progress = buildRideProgress({
      status: "ongoing",
      passenger_id: 1,
      driver_id: 9,
    });

    expect(progress.currentState).toBe(RIDE_STATES.RIDE_IN_PROGRESS);
    expect(progress.steps[4].status).toBe("completed");
    expect(progress.steps[5].status).toBe("active");
  });

  it("ends the cash-only lifecycle when the ride is completed", () => {
    const progress = buildRideProgress({
      status: "completed",
      passenger_id: 1,
      driver_id: 9,
    });

    expect(progress.currentState).toBe(RIDE_STATES.RIDE_COMPLETED);
    expect(progress.steps[6].status).toBe("active");
  });
});

describe("decorateBookingRecord", () => {
  it("never leaks the pickup PIN hash or attempt counter to clients", () => {
    const decorated = decorateBookingRecord({
      id: 42,
      status: "accepted",
      passenger_id: 1,
      driver_id: 9,
      pickup_pin_hash: "$2a$08$superseekrethash",
      pin_attempts: 3,
    });

    expect(decorated.pickup_pin_hash).toBeUndefined();
    expect(decorated.pin_attempts).toBeUndefined();
    expect(decorated.id).toBe(42);
    expect(decorated.rideState).toBeDefined();
  });
});
