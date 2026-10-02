require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(), withTransaction: jest.fn() }));

const db = require("../src/config/db");
const barangayService = require("../src/services/barangay.service");
const settingsService = require("../src/services/system-settings.service");

const BARANGAYS = [
  { id: 1, name: "Poblacion Ward 7", is_enabled: 1, lat: 11.0311, lng: 125.7235 },
  { id: 2, name: "Sapao", is_enabled: 0, lat: 11.0435, lng: 125.7532 },
];

describe("barangay coverage", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    barangayService.invalidateCache();
    db.query.mockResolvedValue(BARANGAYS);
  });

  it("matches a point to the barangay with the nearest pin", async () => {
    const found = await barangayService.findBarangayAt(11.044, 125.752);
    expect(found).toMatchObject({ name: "Sapao", isEnabled: false });
  });

  it("ignores points far from every pin", async () => {
    expect(await barangayService.findBarangayAt(11.25, 125.4)).toBeNull();
  });

  it("refuses a drop-off in a disabled barangay", async () => {
    await expect(
      barangayService.assertBookableLocations({
        pickupLat: 11.031,
        pickupLng: 125.7235,
        dropoffLat: 11.0435,
        dropoffLng: 125.7532,
      })
    ).rejects.toMatchObject({
      statusCode: 403,
      details: { code: "BARANGAY_DISABLED", point: "dropoff", barangay: "Sapao" },
    });
  });

  it("allows trips between enabled barangays", async () => {
    await expect(
      barangayService.assertBookableLocations({
        pickupLat: 11.031,
        pickupLng: 125.7235,
        dropoffLat: 11.0315,
        dropoffLng: 125.724,
      })
    ).resolves.toBeUndefined();
  });
});

describe("operating hours", () => {
  // 2026-10-02 in Manila (UTC+8): 03:00 UTC = 11:00 AM, 15:30 UTC = 11:30 PM.
  const lateMorning = new Date("2026-10-02T03:00:00Z");
  const lateNight = new Date("2026-10-02T15:30:00Z");

  it("uses Philippine time", () => {
    expect(settingsService.isWithinHours("05:00", "22:00", lateMorning)).toBe(true);
    expect(settingsService.isWithinHours("05:00", "22:00", lateNight)).toBe(false);
  });

  it("supports hours that run past midnight", () => {
    expect(settingsService.isWithinHours("18:00", "02:00", lateNight)).toBe(true);
    expect(settingsService.isWithinHours("18:00", "02:00", lateMorning)).toBe(false);
  });

  it("reads old free-text hours", () => {
    expect(settingsService.toHHMM("5:00 AM")).toBe("05:00");
    expect(settingsService.toHHMM("10:00 PM")).toBe("22:00");
    expect(settingsService.toHHMM("12:15 am")).toBe("00:15");
  });

  it("blocks new bookings after hours only when the admin turned it on", async () => {
    const rows = (enforce) => [
      { setting_key: "operatingHoursStart", setting_value: "05:00" },
      { setting_key: "operatingHoursEnd", setting_value: "22:00" },
      { setting_key: "enforceOperatingHours", setting_value: enforce },
    ];

    settingsService.invalidateCache();
    db.query.mockResolvedValueOnce(rows("false"));
    await expect(settingsService.assertOpenForBooking(lateNight)).resolves.toBeUndefined();

    settingsService.invalidateCache();
    db.query.mockResolvedValueOnce(rows("true"));
    await expect(settingsService.assertOpenForBooking(lateNight)).rejects.toMatchObject({
      statusCode: 403,
      details: { code: "OUTSIDE_OPERATING_HOURS" },
    });
    await expect(settingsService.assertOpenForBooking(lateMorning)).resolves.toBeUndefined();
  });
});
