require("./setup-env");

const bcrypt = require("bcryptjs");

const mockTxClient = { query: jest.fn(async () => []) };
jest.mock("../src/config/db", () => ({
  query: jest.fn(async () => []),
  withTransaction: jest.fn(async (work) => work(mockTxClient)),
}));
jest.mock("../src/models/user.model");
jest.mock("../src/models/refresh-token.model");
jest.mock("../src/models/rating.model");
jest.mock("../src/models/booking.model");
jest.mock("../src/models/driver.model");
jest.mock("../src/services/auth.v2.service");

const db = require("../src/config/db");
const userModel = require("../src/models/user.model");
const refreshTokenModel = require("../src/models/refresh-token.model");
const ratingModel = require("../src/models/rating.model");
const bookingModel = require("../src/models/booking.model");
const driverModel = require("../src/models/driver.model");
const hashToken = require("../src/utils/token-hash");
const accountService = require("../src/services/passenger-account.service");
const accountSecurityService = require("../src/services/account-security.service");
const bookingService = require("../src/services/booking.service");
const matchingService = require("../src/services/matching.service");
const errorMiddleware = require("../src/middlewares/error.middleware");

let passwordHash;
beforeAll(async () => {
  passwordHash = await bcrypt.hash("secret123", 4);
});
beforeEach(() => {
  jest.clearAllMocks();
  db.query.mockResolvedValue([]);
});

describe("editing the passenger profile", () => {
  it("says the email is taken instead of a server error", async () => {
    userModel.findByEmail.mockResolvedValue({ id: 99 });
    await expect(accountService.updateProfile(7, { email: "taken@example.com" })).rejects.toMatchObject({
      statusCode: 409,
      message: "This email is already used by another account.",
      details: { field: "email" },
    });
    expect(userModel.updateProfile).not.toHaveBeenCalled();
  });

  it("says the mobile number is taken", async () => {
    userModel.findByPhone.mockResolvedValue({ id: 99 });
    await expect(accountService.updateProfile(7, { phone: "09171234567" })).rejects.toMatchObject({
      statusCode: 409,
      details: { field: "phone" },
    });
  });

  it("lets a user keep their own email", async () => {
    userModel.findByEmail.mockResolvedValue({ id: 7 });
    await accountService.updateProfile(7, { email: "me@example.com" });
    expect(userModel.updateProfile).toHaveBeenCalledWith(7, { email: "me@example.com" });
  });

  it("stores a cleared email as NULL, not an empty string", async () => {
    await accountService.updateProfile(7, { email: "" });
    expect(userModel.updateProfile).toHaveBeenCalledWith(7, { email: null });
    expect(userModel.findByEmail).not.toHaveBeenCalled();
  });
});

describe("deleting an account", () => {
  beforeEach(() => {
    userModel.findById.mockResolvedValue({ id: 7, password_hash: passwordHash });
  });

  it("is refused while a ride is in progress", async () => {
    db.query.mockResolvedValueOnce([{ id: 50 }]);
    await expect(accountService.deleteAccount(7, "secret123")).rejects.toMatchObject({ statusCode: 409 });
    expect(userModel.archiveUser).not.toHaveBeenCalled();
  });

  it("archives the account and signs every device out", async () => {
    await accountService.deleteAccount(7, "secret123");
    expect(userModel.archiveUser).toHaveBeenCalledWith(7, mockTxClient);
    expect(refreshTokenModel.revokeAllByUserId).toHaveBeenCalledWith(7, mockTxClient);
    expect(mockTxClient.query).toHaveBeenCalledWith(expect.stringContaining("is_online = 0"), [7]);
    expect(mockTxClient.query).toHaveBeenCalledWith(expect.stringContaining("push_tokens"), [7]);
  });

  it("checks the password first", async () => {
    await expect(accountService.deleteAccount(7, "wrong")).rejects.toMatchObject({ statusCode: 400 });
    expect(userModel.archiveUser).not.toHaveBeenCalled();
  });
});

describe("changing the password", () => {
  it("signs other devices out but keeps this one", async () => {
    userModel.findById.mockResolvedValue({ id: 7, email: "me@example.com", password_hash: passwordHash });
    const result = await accountSecurityService.confirmPasswordChange(7, {
      currentPassword: "secret123",
      newPassword: "newsecret123",
      otp: "123456",
      keepRefreshToken: "this-device-refresh-token",
    });
    expect(refreshTokenModel.revokeOtherSessions).toHaveBeenCalledWith(7, hashToken("this-device-refresh-token"));
    expect(result.message).toMatch(/Other devices have been signed out/);
  });
});

describe("rating a ride twice", () => {
  it("says it was already rated", async () => {
    bookingModel.findById.mockResolvedValue({ id: 50, passenger_id: 1, status: "completed", driver_id: 5 });
    ratingModel.findByBookingId.mockResolvedValue({ id: 3 });
    await expect(
      bookingService.rateCompletedRide({ bookingId: 50, passengerId: 1, stars: 5 })
    ).rejects.toMatchObject({ statusCode: 409, message: "You already rated this ride." });
    expect(ratingModel.createRating).not.toHaveBeenCalled();
  });

  it("turns a duplicate-key race into 409, not a server error", () => {
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    errorMiddleware({ code: "ER_DUP_ENTRY", message: "Duplicate entry '50' for key 'booking_id'" }, {}, res);
    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "That already exists." });
  });
});

describe("riders offered to a passenger", () => {
  it("leaves out riders more than 5 km from the pickup", async () => {
    driverModel.getApprovedOnlineDriversWithLocation.mockResolvedValue([
      { id: 1, current_lat: "11.0312", current_lng: "125.7236" }, // at the plaza
      { id: 2, current_lat: "10.7610", current_lng: "125.7102" }, // Homonhon, ~30 km
    ]);
    bookingModel.listDriverIdsWithActiveRide.mockResolvedValue([]);
    const riders = await matchingService.listNearestAvailableDrivers(11.0311, 125.7235, 10);
    expect(riders.map((r) => r.id)).toEqual([1]);
  });
});
