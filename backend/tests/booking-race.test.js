require("./setup-env");

jest.mock("../src/config/db", () => ({
  query: jest.fn(),
  withTransaction: jest.fn(async (work) => work({ query: jest.fn() })),
}));
jest.mock("../src/models/booking.model");
jest.mock("../src/models/driver.model");
jest.mock("../src/models/fare.model");
jest.mock("../src/services/notification.service", () => ({
  createNotification: jest.fn(async () => {}),
}));

const bookingModel = require("../src/models/booking.model");
const driverModel = require("../src/models/driver.model");
const fareModel = require("../src/models/fare.model");
const bookingService = require("../src/services/booking.service");

const DRIVER_ID = 5;
const BOOKING_ID = 100;

beforeEach(() => {
  jest.clearAllMocks();
  fareModel.getCurrentFareSettings.mockResolvedValue({ base_fare: 20, per_km_rate: 10 });
  bookingModel.findActiveByDriver.mockResolvedValue({
    id: BOOKING_ID,
    status: "ongoing",
    distance_km: 2,
    passenger_count: 1,
  });
  bookingModel.findById.mockResolvedValue({
    id: BOOKING_ID,
    status: "completed",
    passenger_id: 1,
    driver_user_id: 9,
  });
});

describe("completeRide", () => {
  it("credits the driver exactly once when the ride completes", async () => {
    bookingModel.markCompleted.mockResolvedValue({ changed: true });

    await bookingService.completeRide({ driverId: DRIVER_ID, bookingId: BOOKING_ID });

    expect(driverModel.addEarningsAndRideCount).toHaveBeenCalledTimes(1);
  });

  it("does not credit earnings again when a concurrent request already completed it", async () => {
    bookingModel.markCompleted.mockResolvedValue({ changed: false });

    await expect(
      bookingService.completeRide({ driverId: DRIVER_ID, bookingId: BOOKING_ID })
    ).rejects.toMatchObject({ statusCode: 409 });
    expect(driverModel.addEarningsAndRideCount).not.toHaveBeenCalled();
  });

  it("caps a driver-reported distance far beyond the booked route", async () => {
    bookingModel.markCompleted.mockResolvedValue({ changed: true });

    await bookingService.completeRide({
      driverId: DRIVER_ID,
      bookingId: BOOKING_ID,
      actualDistanceKm: 500,
    });

    // 2 km booked -> at most 2 * 1.5 + 1 = 4 km -> 20 + 4 * 10 = 60
    const [, fare] = bookingModel.markCompleted.mock.calls[0];
    expect(fare).toBe(60);
  });
});

describe("driverRespond", () => {
  beforeEach(() => {
    bookingModel.findById.mockResolvedValue({
      id: BOOKING_ID,
      status: "pending",
      driver_id: DRIVER_ID,
      passenger_id: 1,
    });
  });

  it("refuses to accept an offer that was already reassigned or cancelled", async () => {
    bookingModel.markAccepted.mockResolvedValue({ changed: false, booking: {} });

    await expect(
      bookingService.driverRespond({ bookingId: BOOKING_ID, driverId: DRIVER_ID, action: "accept" })
    ).rejects.toMatchObject({ statusCode: 409 });
    expect(bookingModel.markAccepted).toHaveBeenCalledWith(BOOKING_ID, DRIVER_ID);
  });

  it("only clears the driver it expects when declining", async () => {
    bookingModel.clearAssignedDriver.mockResolvedValue({ changed: false, booking: {} });

    await expect(
      bookingService.driverRespond({ bookingId: BOOKING_ID, driverId: DRIVER_ID, action: "decline" })
    ).rejects.toMatchObject({ statusCode: 409 });
    expect(bookingModel.clearAssignedDriver).toHaveBeenCalledWith(
      BOOKING_ID,
      DRIVER_ID,
      expect.any(String)
    );
  });
});
