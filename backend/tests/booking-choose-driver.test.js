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
const matchingService = require("../src/services/matching.service");
const notificationService = require("../src/services/notification.service");
const bookingService = require("../src/services/booking.service");

const PASSENGER_ID = 1;

// A full drivers row as the DB returns it, including private fields.
function driverRow(id, distanceToPickupKm) {
  return {
    id,
    user_id: 100 + id,
    full_name: `Rider ${id}`,
    tricycle_number: `TRI-${id}`,
    rating_avg: "4.50",
    total_rides: 12,
    current_lat: "11.03",
    current_lng: "125.72",
    distanceToPickupKm,
    license_number: "SECRET-LICENSE",
    license_image_url: "/uploads/driver-docs/secret.jpg",
    total_earnings: "9999.00",
  };
}

function pendingBooking(overrides = {}) {
  return {
    id: 10,
    passenger_id: PASSENGER_ID,
    status: "pending",
    driver_id: null,
    pickup_lat: 11.03,
    pickup_lng: 125.72,
    pickup_address: "Guiuan Plaza",
    ...overrides,
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  matchingService.listNearestAvailableDrivers.mockResolvedValue([
    driverRow(1, 0.4),
    driverRow(2, 1.2),
  ]);
});

describe("passenger chooses a rider", () => {
  it("lists nearby riders with public fields only", async () => {
    bookingModel.findById.mockResolvedValue(pendingBooking());

    const { nearbyDrivers } = await bookingService.listNearbyDriversForBooking({
      bookingId: 10,
      passengerId: PASSENGER_ID,
    });

    expect(nearbyDrivers.map((d) => d.id)).toEqual([1, 2]);
    expect(nearbyDrivers[0]).toMatchObject({ full_name: "Rider 1", rating: 4.5, distanceToPickupKm: 0.4 });
    for (const driver of nearbyDrivers) {
      expect(driver).not.toHaveProperty("license_number");
      expect(driver).not.toHaveProperty("license_image_url");
      expect(driver).not.toHaveProperty("total_earnings");
      expect(driver).not.toHaveProperty("user_id");
    }
  });

  it("won't list riders for someone else's booking", async () => {
    bookingModel.findById.mockResolvedValue(pendingBooking({ passenger_id: 999 }));

    await expect(
      bookingService.listNearbyDriversForBooking({ bookingId: 10, passengerId: PASSENGER_ID })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("assigns the chosen rider and notifies them", async () => {
    bookingModel.findById.mockResolvedValue(pendingBooking());
    bookingModel.assignDriver.mockResolvedValue({
      assigned: true,
      booking: pendingBooking({ driver_id: 2 }),
    });

    const result = await bookingService.passengerChooseDriver({
      bookingId: 10,
      passengerId: PASSENGER_ID,
      driverId: 2,
    });

    expect(bookingModel.assignDriver).toHaveBeenCalledWith(10, 2);
    expect(result.driver).toMatchObject({ id: 2, full_name: "Rider 2" });
    expect(result.driver).not.toHaveProperty("license_number");
    expect(result.driverUserId).toBe(102);
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ type: "ride_request", userId: 102, recipientRole: "driver" })
    );
  });

  it("rejects a rider who is no longer available", async () => {
    bookingModel.findById.mockResolvedValue(pendingBooking());
    matchingService.listNearestAvailableDrivers.mockResolvedValue([driverRow(1, 0.4)]);

    await expect(
      bookingService.passengerChooseDriver({ bookingId: 10, passengerId: PASSENGER_ID, driverId: 2 })
    ).rejects.toMatchObject({ statusCode: 409 });
    expect(bookingModel.assignDriver).not.toHaveBeenCalled();
  });
});

describe("rider declines", () => {
  it("returns the choice to the passenger instead of auto-assigning someone else", async () => {
    bookingModel.findById.mockResolvedValue(pendingBooking({ id: 20, driver_id: 1 }));
    bookingModel.clearAssignedDriver.mockResolvedValue({
      changed: true,
      booking: pendingBooking({ id: 20 }),
    });

    const result = await bookingService.driverRespond({
      bookingId: 20,
      driverId: 1,
      action: "decline",
    });

    expect(bookingModel.assignDriver).not.toHaveBeenCalled();
    expect(result.reassignedDriver).toBeNull();
    expect(result.reason).toBe("declined");
    expect(result.nearbyDrivers.length).toBeGreaterThan(0);
    // The rider who declined is excluded from the passenger's next list.
    const [, , , excluded] = matchingService.listNearestAvailableDrivers.mock.calls.at(-1);
    expect(excluded).toEqual([1]);
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ type: "booking_declined", userId: PASSENGER_ID })
    );
  });
});
