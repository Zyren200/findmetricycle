require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn() }));

const db = require("../src/config/db");
const bookingModel = require("../src/models/booking.model");
const { decorateBookingRecord } = require("../src/utils/ride-progress");

beforeEach(() => jest.clearAllMocks());

describe("pickup PIN visibility", () => {
  it("is stripped from general booking reads (driver / admin paths)", async () => {
    db.query.mockResolvedValue([{ id: 10, status: "accepted", pickup_pin: "4821", pickup_pin_hash: "x" }]);

    const booking = await bookingModel.findById(10);

    expect(booking).not.toHaveProperty("pickup_pin");
  });

  it("is never included in a decorated booking payload", () => {
    const payload = decorateBookingRecord({ id: 10, status: "pending", pickup_pin: "4821", pickup_pin_hash: "x" });
    expect(payload).not.toHaveProperty("pickup_pin");
    expect(payload).not.toHaveProperty("pickup_pin_hash");
  });

  it("is returned to the booking's own passenger before the trip starts", async () => {
    db.query.mockResolvedValueOnce([{ pickup_pin: "4821", pin_attempts: 0, pin_verified_at: null, status: "arriving" }]);

    await expect(bookingModel.getPickupPinForPassenger(10, 1)).resolves.toBe("4821");
    // Scoped to the passenger in SQL, so someone else's booking yields nothing.
    expect(db.query.mock.calls[0][1]).toEqual([10, 1]);
  });

  it("is not returned once the trip is under way", async () => {
    db.query.mockResolvedValueOnce([{ pickup_pin: null, pin_attempts: 0, pin_verified_at: new Date(), status: "ongoing" }]);

    await expect(bookingModel.getPickupPinForPassenger(10, 1)).resolves.toBeNull();
  });

  it("issues a new PIN for older bookings that never stored one", async () => {
    db.query
      .mockResolvedValueOnce([{ pickup_pin: null, pin_attempts: 0, pin_verified_at: null, status: "accepted" }])
      .mockResolvedValueOnce({ affectedRows: 1 });

    const pin = await bookingModel.getPickupPinForPassenger(10, 1);

    expect(pin).toMatch(/^\d{4}$/);
    const [sql, params] = db.query.mock.calls[1];
    expect(sql).toMatch(/UPDATE bookings SET pickup_pin = \?, pickup_pin_hash = \?, pin_attempts = 0/);
    expect(params[0]).toBe(pin);
  });
});
