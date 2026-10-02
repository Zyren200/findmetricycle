require("./setup-env");

jest.mock("../src/config/db", () => ({
  query: jest.fn(),
  withTransaction: jest.fn(async (work) => work({ query: jest.fn() })),
}));
jest.mock("../src/models/booking.model");
jest.mock("../src/models/driver.model");
jest.mock("../src/models/fare.model");
jest.mock("../src/services/matching.service");
jest.mock("../src/services/notification.service", () => ({
  createNotification: jest.fn(async () => {}),
}));

const bookingModel = require("../src/models/booking.model");
const driverModel = require("../src/models/driver.model");
const matchingService = require("../src/services/matching.service");
const notificationService = require("../src/services/notification.service");
const bookingService = require("../src/services/booking.service");

const PASSENGER_ID = 1;
const DRIVER_ID = 5;

function ride(overrides = {}) {
  return {
    id: 50,
    passenger_id: PASSENGER_ID,
    driver_id: DRIVER_ID,
    driver_user_id: 105,
    driver_name: "Juan",
    status: "accepted",
    estimated_fare: "45.00",
    pickup_lat: 11.03,
    pickup_lng: 125.72,
    ...overrides,
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  matchingService.listNearestAvailableDrivers.mockResolvedValue([]);
});

describe("passenger cancels", () => {
  it("can still cancel once the rider has arrived at pickup", async () => {
    bookingModel.findById.mockResolvedValue(ride({ status: "arriving" }));
    bookingModel.markCancelled.mockResolvedValue({ changed: true, booking: ride({ status: "cancelled" }) });

    await bookingService.cancelRide({ bookingId: 50, passengerId: PASSENGER_ID });
    expect(bookingModel.markCancelled).toHaveBeenCalledWith(50, "passenger");
  });

  it("can't cancel a trip that has started", async () => {
    bookingModel.findById.mockResolvedValue(ride({ status: "ongoing" }));
    await expect(
      bookingService.cancelRide({ bookingId: 50, passengerId: PASSENGER_ID })
    ).rejects.toMatchObject({ statusCode: 400 });
  });
});

describe("driver cancels before the trip", () => {
  it("hands the booking back to the passenger to choose another rider", async () => {
    bookingModel.findActiveByDriver.mockResolvedValue(ride({ status: "arriving" }));
    bookingModel.releaseDriver.mockResolvedValue({
      changed: true,
      booking: ride({ status: "pending", driver_id: null }),
    });

    const result = await bookingService.driverCancelRide({ bookingId: 50, driverId: DRIVER_ID, reason: "Flat tire" });

    expect(bookingModel.releaseDriver).toHaveBeenCalledWith(50, DRIVER_ID, "Driver cancelled: Flat tire");
    expect(result.reason).toBe("driver_cancelled");
    // The rider who backed out isn't offered to this passenger again.
    const [, , , excluded] = matchingService.listNearestAvailableDrivers.mock.calls.at(-1);
    expect(excluded).toEqual([DRIVER_ID]);
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ userId: PASSENGER_ID, title: "Rider cancelled" })
    );
  });

  it("is refused once the trip has started", async () => {
    bookingModel.findActiveByDriver.mockResolvedValue(ride({ status: "ongoing" }));
    await expect(
      bookingService.driverCancelRide({ bookingId: 50, driverId: DRIVER_ID })
    ).rejects.toMatchObject({ statusCode: 400 });
    expect(bookingModel.releaseDriver).not.toHaveBeenCalled();
  });
});

describe("admin force-close", () => {
  it("cancels a ride stuck in progress and tells both sides why", async () => {
    bookingModel.findById.mockResolvedValue(ride({ status: "ongoing" }));
    bookingModel.markCancelled.mockResolvedValue({ changed: true, booking: ride({ status: "cancelled" }) });

    const { booking } = await bookingService.adminCloseRide({
      bookingId: 50,
      outcome: "cancelled",
      reason: "Driver phone died",
    });

    expect(booking.status).toBe("cancelled");
    expect(bookingModel.markCancelled).toHaveBeenCalledWith(
      50,
      "admin",
      expect.objectContaining({ reason: "Driver phone died", fromStatuses: expect.arrayContaining(["ongoing"]) })
    );
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ userId: PASSENGER_ID, recipientRole: "passenger" })
    );
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 105, recipientRole: "driver" })
    );
  });

  it("marks a finished trip completed and credits the driver the estimated fare", async () => {
    bookingModel.findById.mockResolvedValue(ride({ status: "ongoing" }));
    bookingModel.markCompleted.mockResolvedValue({ changed: true });

    await bookingService.adminCloseRide({ bookingId: 50, outcome: "completed", reason: "Trip done, app crashed" });

    expect(bookingModel.markCompleted).toHaveBeenCalledWith(50, 45, expect.anything());
    expect(driverModel.addEarningsAndRideCount).toHaveBeenCalledWith(DRIVER_ID, 45, expect.anything());
  });

  it("won't mark a ride completed that never started", async () => {
    bookingModel.findById.mockResolvedValue(ride({ status: "accepted" }));
    await expect(
      bookingService.adminCloseRide({ bookingId: 50, outcome: "completed", reason: "test" })
    ).rejects.toMatchObject({ statusCode: 400 });
    expect(driverModel.addEarningsAndRideCount).not.toHaveBeenCalled();
  });

  it("refuses a ride that already ended", async () => {
    bookingModel.findById.mockResolvedValue(ride({ status: "completed" }));
    await expect(
      bookingService.adminCloseRide({ bookingId: 50, outcome: "cancelled", reason: "test" })
    ).rejects.toMatchObject({ statusCode: 409 });
  });
});

describe("unreachable driver", () => {
  it("hands the ride back to the passenger and sets the driver offline", async () => {
    bookingModel.findRidesWithUnreachableDriver.mockResolvedValue([
      { id: 50, driver_id: DRIVER_ID, passenger_id: PASSENGER_ID, driver_user_id: 105 },
    ]);
    bookingModel.releaseDriver.mockResolvedValue({
      changed: true,
      booking: ride({ status: "pending", driver_id: null }),
    });

    const [result] = await bookingService.releaseUnreachableDrivers();

    expect(bookingModel.findRidesWithUnreachableDriver).toHaveBeenCalledWith(5);
    expect(bookingModel.releaseDriver).toHaveBeenCalledWith(50, DRIVER_ID, expect.stringContaining("unreachable"));
    expect(driverModel.setOnlineStatus).toHaveBeenCalledWith(DRIVER_ID, false);
    expect(result).toMatchObject({ reason: "driver_unreachable", staleDriverId: DRIVER_ID, staleDriverUserId: 105 });
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ userId: PASSENGER_ID, title: "Rider unreachable" })
    );
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 105, recipientRole: "driver" })
    );
  });

  it("leaves the ride alone if the driver acted in the meantime", async () => {
    bookingModel.findRidesWithUnreachableDriver.mockResolvedValue([
      { id: 50, driver_id: DRIVER_ID, passenger_id: PASSENGER_ID, driver_user_id: 105 },
    ]);
    bookingModel.releaseDriver.mockResolvedValue({ changed: false, booking: ride({ status: "ongoing" }) });

    expect(await bookingService.releaseUnreachableDrivers()).toEqual([]);
    expect(driverModel.setOnlineStatus).not.toHaveBeenCalled();
    expect(notificationService.createNotification).not.toHaveBeenCalled();
  });
});

describe("driver app restart", () => {
  it("gets back the ride the driver is on, but not a pending offer", async () => {
    bookingModel.findActiveByDriver.mockResolvedValue(ride({ status: "arriving" }));
    expect(await bookingService.getActiveRideForDriver(DRIVER_ID)).toMatchObject({ id: 50, status: "arriving" });

    bookingModel.findActiveByDriver.mockResolvedValue(ride({ status: "pending" }));
    expect(await bookingService.getActiveRideForDriver(DRIVER_ID)).toBeNull();
  });
});
