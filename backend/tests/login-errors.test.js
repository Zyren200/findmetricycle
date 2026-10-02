require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(), withTransaction: jest.fn() }));
jest.mock("../src/models/user.model");
jest.mock("../src/models/refresh-token.model");

const bcrypt = require("bcryptjs");
const db = require("../src/config/db");
const userModel = require("../src/models/user.model");
const authService = require("../src/services/auth.service");
const authV2Service = require("../src/services/auth.v2.service");

describe("login error messages", () => {
  beforeEach(() => jest.clearAllMocks());

  it("says when the email is not registered", async () => {
    userModel.findByEmail.mockResolvedValue(null);
    await expect(authService.login({ email: "nobody@example.com", password: "x" })).rejects.toMatchObject({
      statusCode: 401,
      message: "This email is not registered.",
      details: { field: "email" },
    });
  });

  it("says when the mobile number is not registered", async () => {
    userModel.findByPhone.mockResolvedValue(null);
    await expect(authService.login({ phone: "09171234567", password: "x" })).rejects.toMatchObject({
      statusCode: 401,
      message: "This mobile number is not registered.",
      details: { field: "phone" },
    });
  });

  it("says when only the password is wrong", async () => {
    userModel.findByEmail.mockResolvedValue({
      id: 7,
      role: "passenger",
      status: "active",
      password_hash: await bcrypt.hash("correct-password", 4),
    });
    await expect(authService.login({ email: "juan@example.com", password: "wrong" })).rejects.toMatchObject({
      statusCode: 401,
      message: "Invalid password. Please try again.",
      details: { field: "password" },
    });
  });
});

describe("forgot password", () => {
  beforeEach(() => jest.clearAllMocks());

  it("says when the email is not registered instead of sending nothing", async () => {
    db.query.mockResolvedValueOnce([]);
    await expect(authV2Service.requestPasswordReset("nobody@example.com")).rejects.toMatchObject({
      statusCode: 404,
      message: "This email is not registered.",
      details: { field: "email" },
    });
    expect(db.query).toHaveBeenCalledTimes(1);
  });
});
