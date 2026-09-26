require("./setup-env");

const {
  driverParamSchema,
  rejectDriverSchema,
  fareUpdateSchema,
  driverLicenseQuerySchema,
} = require("../src/validations/admin.schema");

describe("Admin validation schema", () => {
  it("validates driver ID params", () => {
    expect(driverParamSchema.safeParse({ params: { driverId: "12" } }).success).toBe(true);
    expect(driverParamSchema.safeParse({ params: { driverId: 0 } }).success).toBe(false);
  });

  it("validates driver rejection payloads", () => {
    expect(
      rejectDriverSchema.safeParse({ params: { driverId: "5" }, body: { reason: "Incomplete papers" } }).success
    ).toBe(true);
    expect(
      rejectDriverSchema.safeParse({ params: { driverId: "5" }, body: { reason: "No" } }).success
    ).toBe(false);
  });

  it("validates admin fare updates", () => {
    expect(
      fareUpdateSchema.safeParse({ body: { baseFare: "20", perKmRate: "15" } }).success
    ).toBe(true);
    expect(
      fareUpdateSchema.safeParse({ body: { baseFare: -1, perKmRate: 15 } }).success
    ).toBe(false);
  });

  it("validates driver license expiration query parameters", () => {
    expect(driverLicenseQuerySchema.safeParse({ query: { days: "30" } }).success).toBe(true);
    expect(driverLicenseQuerySchema.safeParse({ query: { days: "400" } }).success).toBe(false);
  });

});
