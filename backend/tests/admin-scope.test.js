require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(async () => []), withTransaction: jest.fn() }));
jest.mock("../src/models/booking.model");
jest.mock("../src/models/driver.model");
jest.mock("../src/models/driver-application.model");
jest.mock("../src/models/user.model");
jest.mock("../src/models/notification.model");
jest.mock("../src/services/push.service");

const mockEmit = jest.fn();
const mockTo = jest.fn(() => ({ emit: mockEmit }));
jest.mock("../src/sockets", () => ({ getIO: () => ({ to: mockTo, emit: mockEmit }) }));

const bookingModel = require("../src/models/booking.model");
const driverModel = require("../src/models/driver.model");
const driverApplicationModel = require("../src/models/driver-application.model");
const userModel = require("../src/models/user.model");
const notificationModel = require("../src/models/notification.model");
const sosModel = require("../src/models/sos.model");
const adminService = require("../src/services/admin.service");
const notificationService = require("../src/services/notification.service");
const { permissionsForRole } = require("../src/constants/admin-permissions");

beforeEach(() => {
  jest.clearAllMocks();
  bookingModel.getDashboardCounts.mockResolvedValue({
    totalRides: 10,
    dailyEarnings: 500,
    completedRidesToday: 2,
    cancelledRidesToday: 1,
    todaysBookings: 3,
  });
  bookingModel.listRideHistory.mockResolvedValue([{ id: 1, status: "ongoing" }]);
  bookingModel.getRideActivity.mockResolvedValue([{ date: "2026-10-01", total: 3, completed: 2, cancelled: 1, earnings: 150 }]);
  driverModel.listOnlineDriversForAdmin.mockResolvedValue([{ id: 1 }]);
  driverModel.listAllForAdmin.mockResolvedValue([{ id: 1, approval_status: "approved" }]);
  driverModel.listDriversWithExpiringLicenses.mockResolvedValue([]);
  userModel.listPassengersForAdmin.mockResolvedValue([{ id: 2 }]);
  driverApplicationModel.listPendingApplications.mockResolvedValue([{ id: 3 }]);
  driverApplicationModel.listRecent.mockResolvedValue([{ id: 3 }]);
  jest.spyOn(sosModel, "listForAdmin").mockResolvedValue([{ id: 9, status: "active", lat: null, lng: null }]);
});

describe("dashboard summary follows permissions", () => {
  it("Super Admin gets every figure", async () => {
    const summary = await adminService.getDashboardSummary(permissionsForRole("super_admin"));
    expect(summary).toMatchObject({ dailyEarnings: 500, totalPassengers: 1, pendingApplications: 1, sosAlerts: 1, totalRides: 10 });
  });

  it("SOS Responder gets SOS and online drivers only — no earnings, passengers or applications", async () => {
    const summary = await adminService.getDashboardSummary(permissionsForRole("sos_responder"));
    expect(Object.keys(summary).sort()).toEqual(["activeDrivers", "onlineDrivers", "sosAlerts"]);
    // The queries for hidden figures aren't even run.
    expect(userModel.listPassengersForAdmin).not.toHaveBeenCalled();
    expect(bookingModel.getDashboardCounts).not.toHaveBeenCalled();
    expect(driverApplicationModel.listRecent).not.toHaveBeenCalled();
  });

  it("Operations Admin doesn't see earnings or SOS", async () => {
    const summary = await adminService.getDashboardSummary(permissionsForRole("operations_admin"));
    expect(summary).not.toHaveProperty("dailyEarnings");
    expect(summary).not.toHaveProperty("sosAlerts");
    expect(summary).toMatchObject({ totalRides: 10, totalPassengers: 1, pendingApplications: 1 });
  });

  it("ride activity drops the earnings column when asked", async () => {
    const [row] = await adminService.getRideActivity(7, { includeEarnings: false });
    expect(row).not.toHaveProperty("earnings");
    const [full] = await adminService.getRideActivity(7);
    expect(full.earnings).toBe(150);
  });
});

describe("live admin notifications go to the admins allowed to see them", () => {
  function created(type, extra = {}) {
    notificationModel.createNotification.mockResolvedValue({ id: 1, type, title: "t", body: "b", is_read: 0, ...extra });
  }

  it("an SOS alert reaches the SOS room only", async () => {
    created("sos_alert");
    await notificationService.createNotification({ type: "sos_alert", title: "t", body: "b", recipientRole: "admin" });
    expect(mockTo).toHaveBeenCalledWith("perm:sos.view");
    expect(mockTo).not.toHaveBeenCalledWith("role:admin");
  });

  it("a driver application reaches only those who review applications", async () => {
    created("driver_application");
    await notificationService.createNotification({ type: "driver_application", title: "t", body: "b", recipientRole: "admin" });
    expect(mockTo).toHaveBeenCalledWith("perm:driver_applications.view");
  });

  it("a passenger's own notification never reaches admins", async () => {
    created("ride_completed", { user_id: 5 });
    await notificationService.createNotification({ type: "ride_completed", title: "t", body: "b", userId: 5 });
    expect(mockTo).toHaveBeenCalledWith("user:5");
    expect(mockTo.mock.calls.every(([room]) => !room.startsWith("perm:"))).toBe(true);
  });
});
