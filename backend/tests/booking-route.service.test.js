require("./setup-env");

jest.mock("../src/models/booking-route.model", () => ({
  findLatestForBooking: jest.fn(),
  create: jest.fn(),
}));

const routeModel = require("../src/models/booking-route.model");
const routeService = require("../src/services/booking-route.service");

describe("booking route recording", () => {
  beforeEach(() => jest.clearAllMocks());

  it("records the first point of an ongoing trip", async () => {
    routeModel.findLatestForBooking.mockResolvedValue(null);

    await expect(routeService.recordPoint({ bookingId: 7, lat: 11.0, lng: 125.7 })).resolves.toBe(true);
    expect(routeModel.create).toHaveBeenCalledWith({ bookingId: 7, lat: 11.0, lng: 125.7 });
  });

  it("does not store GPS heartbeats that are both recent and nearly unchanged", () => {
    const now = new Date("2026-10-10T10:00:05Z");
    const previous = { lat: 11.0, lng: 125.7, recorded_at: "2026-10-10T10:00:00Z" };

    expect(routeService.shouldRecordPoint(previous, 11.00001, 125.70001, now)).toBe(false);
  });

  it("records movement of at least 20 metres even before ten seconds pass", () => {
    const now = new Date("2026-10-10T10:00:05Z");
    const previous = { lat: 11.0, lng: 125.7, recorded_at: "2026-10-10T10:00:00Z" };

    expect(routeService.shouldRecordPoint(previous, 11.0003, 125.7, now)).toBe(true);
  });
});
