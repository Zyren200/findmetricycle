require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(async () => []), withTransaction: jest.fn() }));
jest.mock("../src/models/booking.model");
jest.mock("../src/models/driver.model");
jest.mock("../src/models/user.model");
jest.mock("../src/models/sos.model");
jest.mock("../src/services/barangay.service");
jest.mock("../src/services/system-settings.service");
jest.mock("../src/services/notification.service");

const jwt = require("jsonwebtoken");
const request = require("supertest");
const db = require("../src/config/db");
const env = require("../src/config/env");
const bookingModel = require("../src/models/booking.model");
const userModel = require("../src/models/user.model");
const sosModel = require("../src/models/sos.model");
const barangayService = require("../src/services/barangay.service");
const systemSettingsService = require("../src/services/system-settings.service");
const serviceArea = require("../src/services/service-area.service");
const bookingService = require("../src/services/booking.service");
const sosService = require("../src/services/sos.service");
const adminService = require("../src/services/admin.service");
const defaultBarangays = require("../src/data/guiuan-barangays");

// [lat, lng]. Island points are barangay pins on that island.
const INSIDE = {
  "the town proper (Poblacion Ward 7)": [11.0311, 125.7235],
  "Homonhon Island (Casuguran)": [10.742, 125.7223],
  "Suluan Island (Suluan)": [10.7612, 125.9508],
  "Calicoan Island (Sulangan)": [10.9397, 125.8262],
  "Manicani Island (Hamorawon)": [11.0033, 125.6282],
  "Tubabao Island (San Pedro)": [11.0449, 125.6857],
};
const OUTSIDE = {
  "Mercedes, 0.8 km past the land border": [11.08827, 125.7235],
  "Mercedes town proper": [11.105, 125.7185],
  "Salcedo town proper": [11.148, 125.656],
  "Borongan": [11.608, 125.432],
  "Tacloban": [11.244, 125.004],
  "open sea east of Suluan": [10.7612, 125.99],
  "far out in the Pacific": [11.0, 126.2],
};
// 140 m north of the Guiuan–Mercedes border: outside, but within 300 m.
const NEAR_BORDER = [11.08149, 125.7235];

const original = { ...env.geofence };
afterEach(() => Object.assign(env.geofence, original));

describe("isInsideServiceArea", () => {
  it.each(Object.entries(INSIDE))("%s is inside", (_name, [lat, lng]) => {
    expect(serviceArea.isInsideServiceArea(lat, lng)).toBe(true);
  });

  it.each(Object.entries(OUTSIDE))("%s is outside", (_name, [lat, lng]) => {
    expect(serviceArea.isInsideServiceArea(lat, lng)).toBe(false);
  });

  it("counts a point just past the border as inside only within the buffer", () => {
    expect(serviceArea.isInsideServiceArea(...NEAR_BORDER, { bufferMeters: 0 })).toBe(false);
    expect(serviceArea.isInsideServiceArea(...NEAR_BORDER, { bufferMeters: 300 })).toBe(true);
    expect(serviceArea.isInsideServiceArea(...NEAR_BORDER, { bufferMeters: 100 })).toBe(false);
  });

  it.each([
    ["NaN", NaN, 125.72],
    ["null", null, 125.72],
    ["empty string", "", 125.72],
    ["a word", "guiuan", 125.72],
    ["a boolean", true, 125.72],
    ["latitude over 90", 95, 125.72],
    ["longitude over 180", 11.03, 190],
    ["Infinity", Infinity, 125.72],
  ])("rejects %s", (_name, lat, lng) => {
    expect(serviceArea.isInsideServiceArea(lat, lng)).toBe(false);
    expect(serviceArea.isValidCoordinate(lat, lng)).toBe(false);
  });

  it("accepts numeric strings (form and query values)", () => {
    expect(serviceArea.isInsideServiceArea("11.0311", "125.7235")).toBe(true);
  });

  it("matches the copy the mobile app bundles (run `npm run service-area:export` if not)", () => {
    const { MOBILE_COPY } = require("../scripts/export-service-area");
    const bundled = JSON.parse(require("fs").readFileSync(MOBILE_COPY, "utf8"));
    expect(bundled.version).toBe(serviceArea.version);
    expect(bundled.boundary).toEqual(serviceArea.describeServiceArea().boundary);
  });

  it("has every default barangay pin inside, with no buffer", () => {
    const outside = defaultBarangays.filter((b) => !serviceArea.isInsideServiceArea(b.lat, b.lng, { bufferMeters: 0 }));
    expect(outside.map((b) => b.name)).toEqual([]);
    expect(defaultBarangays).toHaveLength(60);
  });
});

describe("GET /api/service-area", () => {
  const app = require("../src/app");

it("returns the boundary, the map limits and a version", async () => {
    env.geofence.enabled = false;

    const res = await request(app).get("/api/service-area");
    expect(res.statusCode).toBe(200);
    const data = res.body.data;
    expect(data.boundary.geometry.type).toBe("MultiPolygon");
    expect(data.boundary.geometry.coordinates).toHaveLength(33);
    expect(data.version).toMatch(/^[0-9a-f]{16}$/);
    expect(serviceArea.isInsideServiceArea(data.center.lat, data.center.lng, { bufferMeters: 0 })).toBe(true);
    const [minLng, minLat, maxLng, maxLat] = data.bbox;
    const [pMinLng, pMinLat, pMaxLng, pMaxLat] = data.mapBounds;
    expect(pMinLng < minLng && pMinLat < minLat && pMaxLng > maxLng && pMaxLat > maxLat).toBe(true);
    expect(data.minZoom).toBeLessThan(data.defaultZoom);
    expect(data).toMatchObject({ mode: "polygon", bufferMeters: 300, enforced: false });
  });

  it("answers 304 when the client already has this version", async () => {
    const first = await request(app).get("/api/service-area");
    const again = await request(app).get("/api/service-area").set("If-None-Match", first.headers.etag);
    expect(again.statusCode).toBe(304);
  });
});

describe("bookings", () => {
  const inside = INSIDE["the town proper (Poblacion Ward 7)"];
  const outside = OUTSIDE["Mercedes town proper"];
  const book = (pickup, dropoff) =>
    bookingService.createBookingAndFindDriver({
      passengerId: 5,
      pickupLat: pickup[0],
      pickupLng: pickup[1],
      dropoffLat: dropoff[0],
      dropoffLng: dropoff[1],
    });

  beforeEach(() => {
    jest.clearAllMocks();
    env.geofence.enabled = true;
    bookingModel.findActiveByPassenger.mockResolvedValue(null);
    systemSettingsService.assertOpenForBooking.mockResolvedValue();
    // Stops the flow right after the area checks.
    barangayService.assertBookableLocations.mockRejectedValue(new Error("reached barangay coverage"));
  });

  it("rejects a pickup outside Guiuan, before Barangay Coverage", async () => {
    await expect(book(outside, inside)).rejects.toMatchObject({
      statusCode: 403,
      message: expect.stringContaining("only operates within Guiuan"),
      details: { code: "OUTSIDE_SERVICE_AREA", point: "pickup" },
    });
    expect(barangayService.assertBookableLocations).not.toHaveBeenCalled();
  });

  it("rejects a drop-off outside Guiuan", async () => {
    await expect(book(inside, outside)).rejects.toMatchObject({
      details: { code: "OUTSIDE_SERVICE_AREA", point: "dropoff" },
    });
  });

  it("lets a trip between the town and an island through to Barangay Coverage", async () => {
    await expect(book(inside, INSIDE["Homonhon Island (Casuguran)"])).rejects.toThrow("reached barangay coverage");
  });

  it("still lets Barangay Coverage refuse a disabled barangay inside Guiuan", async () => {
    barangayService.assertBookableLocations.mockRejectedValue(
      Object.assign(new Error("Rides to Sapao aren't available right now."), { statusCode: 403 })
    );
    await expect(book(inside, [11.0435, 125.7532])).rejects.toMatchObject({ message: expect.stringContaining("Sapao") });
  });

  it("never blocks resuming a ride already under way, wherever the passenger is", async () => {
    bookingModel.findActiveByPassenger.mockResolvedValue({ id: 9, status: "ongoing", driver_id: null, passenger_id: 5 });
    const result = await book(outside, outside);
    expect(result.message).toBe("You already have an active booking.");
  });

  it("isn't enforced while GEOFENCE_ENABLED is off", async () => {
    env.geofence.enabled = false;
    await expect(book(outside, outside)).rejects.toThrow("reached barangay coverage");
  });

  it("uses the older radius when GEOFENCE_MODE=radius", async () => {
    Object.assign(env.geofence, { mode: "radius", centerLat: 11.033, centerLng: 125.722, radiusKm: 50 });
    // Within 50 km, though outside the boundary: allowed in radius mode.
    await expect(book(inside, outside)).rejects.toThrow("reached barangay coverage");
  });
});

describe("SOS is never blocked by location", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    env.geofence.enabled = true;
  });

  it.each(Object.entries(OUTSIDE))("an SOS from %s is accepted", async (_name, [lat, lng]) => {
    sosModel.createAlert.mockResolvedValue({ id: 1, status: "active", passenger_id: 5, lat, lng, created_at: new Date() });
    const alert = await sosService.createSosAlert({ passengerId: 5, lat, lng, message: "help" });
    expect(alert).toMatchObject({ id: 1, lat, lng });
  });
});

describe("saved places", () => {
  const app = require("../src/app");
  const token = jwt.sign({ userId: 5, role: "passenger", type: "access" }, env.jwt.secret, { expiresIn: "5m" });

  beforeEach(() => {
    jest.clearAllMocks();
    env.geofence.enabled = true;
    userModel.findById.mockResolvedValue({ id: 5, role: "passenger", status: "active" });
    db.query.mockResolvedValue({ insertId: 7 });
  });

  const save = (lat, lng) =>
    request(app)
      .post("/api/passenger/favorites")
      .set("Authorization", `Bearer ${token}`)
      .send({ label: "Home", address: "Somewhere", lat, lng });

  it("refuses a place outside Guiuan", async () => {
    const res = await save(...OUTSIDE["Mercedes town proper"]);
    expect(res.statusCode).toBe(403);
    expect(res.body.details.code).toBe("OUTSIDE_SERVICE_AREA");
    expect(db.query).not.toHaveBeenCalledWith(expect.stringMatching(/INSERT INTO favorite_destinations/), expect.anything());
  });

  it("saves a place inside Guiuan", async () => {
    const res = await save(...INSIDE["Calicoan Island (Sulangan)"]);
    expect(res.statusCode).toBe(200);
  });

  it("rejects impossible coordinates", async () => {
    const res = await save(123, 125.7);
    expect(res.statusCode).toBe(400);
  });
});

describe("barangay pins", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    db.query.mockImplementation(async (sql) =>
      /SELECT id, name/.test(sql) ? [{ id: 3, name: "Sapao", is_enabled: 1, lat: 11.0435, lng: 125.7532 }] : {}
    );
  });

  it("can't be moved outside Guiuan's boundary, even with the geofence off", async () => {
    env.geofence.enabled = false;
    await expect(adminService.updateBarangay(3, { lat: 11.105, lng: 125.7185 }, 1)).rejects.toMatchObject({
      statusCode: 400,
      details: { code: "OUTSIDE_SERVICE_AREA" },
    });
  });

  it("can be moved within Guiuan", async () => {
    await expect(adminService.updateBarangay(3, { lat: 11.0441, lng: 125.7538 }, 1)).resolves.toMatchObject({ id: 3 });
  });
});
