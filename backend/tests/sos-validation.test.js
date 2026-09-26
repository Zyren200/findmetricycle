require("./setup-env");

const { sosSchema } = require("../src/validations/passenger.schema");

describe("Passenger SOS validation schema", () => {
  it("accepts an empty body (no booking/location required)", () => {
    expect(sosSchema.safeParse({ body: {} }).success).toBe(true);
  });

  it("accepts a full SOS payload", () => {
    expect(
      sosSchema.safeParse({
        body: { bookingId: 12, lat: 10.3, lng: 123.9, message: "Help, driver is speeding." },
      }).success
    ).toBe(true);
  });

  it("rejects an out-of-range latitude", () => {
    expect(sosSchema.safeParse({ body: { lat: 900 } }).success).toBe(false);
  });

  it("rejects a message over 500 characters", () => {
    expect(sosSchema.safeParse({ body: { message: "x".repeat(501) } }).success).toBe(false);
  });
});
