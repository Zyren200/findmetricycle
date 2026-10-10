require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(async () => []), withTransaction: jest.fn() }));
jest.mock("../src/models/user.model");
jest.mock("../src/models/booking.model");
jest.mock("../src/models/complaint.model");
jest.mock("../src/services/notification.service");

const jwt = require("jsonwebtoken");
const request = require("supertest");
const env = require("../src/config/env");
const userModel = require("../src/models/user.model");
const bookingModel = require("../src/models/booking.model");
const complaintModel = require("../src/models/complaint.model");
const notificationService = require("../src/services/notification.service");
const { reportSchema } = require("../src/validations/passenger.schema");

const app = require("../src/app");
const token = jwt.sign({ userId: 5, role: "passenger", type: "access" }, env.jwt.secret, { expiresIn: "5m" });

const report = (body) =>
  request(app).post("/api/passenger/report").set("Authorization", `Bearer ${token}`).send(body);

beforeEach(() => {
  jest.clearAllMocks();
  userModel.findById.mockResolvedValue({ id: 5, role: "passenger", status: "active" });
  complaintModel.createComplaint.mockImplementation(async (fields) => ({ id: 31, status: "open", ...fields }));
  notificationService.createNotification.mockResolvedValue({});
});

describe("passenger Report a Problem", () => {
  it("files a general report for the admin", async () => {
    const res = await report({ category: "app_issue", description: "  The map stays blank.  " });

    expect(res.statusCode).toBe(201);
    expect(complaintModel.createComplaint).toHaveBeenCalledWith({
      reporterId: 5,
      reportedUserId: null,
      bookingId: null,
      category: "app_issue",
      description: "The map stays blank.",
    });
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ recipientRole: "admin", type: "driver_report" })
    );
  });

  it("ties a report about a ride to that ride's rider", async () => {
    bookingModel.findById.mockResolvedValue({ id: 12, passenger_id: 5, driver_user_id: 9 });

    const res = await report({ bookingId: 12, category: "driver_issue", description: "Took a long detour." });

    expect(res.statusCode).toBe(201);
    expect(complaintModel.createComplaint).toHaveBeenCalledWith(
      expect.objectContaining({ bookingId: 12, reportedUserId: 9, category: "driver_issue" })
    );
  });

  it("refuses a ride the passenger wasn't on", async () => {
    bookingModel.findById.mockResolvedValue({ id: 12, passenger_id: 77, driver_user_id: 9 });

    const res = await report({ bookingId: 12, category: "fare_dispute", description: "Charged too much." });

    expect(res.statusCode).toBe(403);
    expect(complaintModel.createComplaint).not.toHaveBeenCalled();
  });

  it("only takes the passenger categories and a description", () => {
    expect(reportSchema.safeParse({ body: { category: "booking_issue", description: "x" } }).success).toBe(true);
    // A driver-only category.
    expect(reportSchema.safeParse({ body: { category: "passenger_behavior", description: "x" } }).success).toBe(false);
    expect(reportSchema.safeParse({ body: { category: "other", description: "   " } }).success).toBe(false);
    expect(reportSchema.safeParse({ body: { category: "other", description: "x".repeat(1001) } }).success).toBe(false);
  });
});
