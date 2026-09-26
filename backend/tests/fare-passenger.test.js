require("./setup-env");

const { calculateFare, calculateFareBreakdown } = require("../src/utils/fare");
const { findRideSchema } = require("../src/validations/passenger.schema");
const { fareUpdateSchema } = require("../src/validations/admin.schema");

const baseSettings = { base_fare: 30, per_km_rate: 0, additional_passenger_fee: 5 };

describe("Additional passenger fee fare calculation", () => {
  it("does not multiply the whole fare by passenger count", () => {
    expect(calculateFare(0, baseSettings, 1)).toBe(30);
    expect(calculateFare(0, baseSettings, 2)).toBe(35);
    expect(calculateFare(0, baseSettings, 3)).toBe(40);
    expect(calculateFare(0, baseSettings, 4)).toBe(45);
    expect(calculateFare(0, baseSettings, 5)).toBe(50);
  });

  it("charges nothing extra when the additional passenger fee is zero", () => {
    const zeroFeeSettings = { ...baseSettings, additional_passenger_fee: 0 };
    expect(calculateFare(0, zeroFeeSettings, 5)).toBe(30);
  });

  it("clamps passenger counts outside 1-5 for safety", () => {
    expect(calculateFare(0, baseSettings, 0)).toBe(30);
    expect(calculateFare(0, baseSettings, 6)).toBe(50);
  });

  it("produces a breakdown usable for booking audit records", () => {
    const breakdown = calculateFareBreakdown(0, baseSettings, 3);
    expect(breakdown).toMatchObject({
      passengerCount: 3,
      singlePassengerFare: 30,
      additionalPassengerFee: 5,
      additionalPassengersCharge: 10,
      total: 40,
    });
  });
});

describe("Passenger findRide passengerCount validation", () => {
  function validBody(overrides = {}) {
    return {
      body: {
        pickupLat: 10,
        pickupLng: 120,
        dropoffLat: 10.1,
        dropoffLng: 120.1,
        ...overrides,
      },
    };
  }

  it("accepts passenger counts 1 through 5", () => {
    for (let count = 1; count <= 5; count += 1) {
      expect(findRideSchema.safeParse(validBody({ passengerCount: count })).success).toBe(true);
    }
  });

  it("rejects a passenger count of 6", () => {
    expect(findRideSchema.safeParse(validBody({ passengerCount: 6 })).success).toBe(false);
  });

  it("rejects a passenger count of 0", () => {
    expect(findRideSchema.safeParse(validBody({ passengerCount: 0 })).success).toBe(false);
  });

  it("defaults to passengerCount omitted (treated as 1 by the service)", () => {
    expect(findRideSchema.safeParse(validBody()).success).toBe(true);
  });
});

describe("Admin fare update additionalPassengerFee validation", () => {
  it("accepts a valid additional passenger fee", () => {
    expect(
      fareUpdateSchema.safeParse({
        body: { baseFare: 20, perKmRate: 12, additionalPassengerFee: 5 },
      }).success
    ).toBe(true);
  });

  it("rejects a negative additional passenger fee", () => {
    expect(
      fareUpdateSchema.safeParse({
        body: { baseFare: 20, perKmRate: 12, additionalPassengerFee: -1 },
      }).success
    ).toBe(false);
  });
});
