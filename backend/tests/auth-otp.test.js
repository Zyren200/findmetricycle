require("./setup-env");

// Scripted fake of config/db: each test pushes the rows the next matching
// query should return, and every executed statement is recorded.
jest.mock("../src/config/db", () => {
  const calls = [];
  const handlers = [];
  const query = jest.fn(async (sql, params = []) => {
    calls.push({ sql, params });
    const handler = handlers.find((h) => h.pattern.test(sql));
    return handler ? handler.respond(sql, params) : { affectedRows: 1, insertId: 1 };
  });
  return {
    query,
    withTransaction: jest.fn(async (work) => work({ query })),
    __calls: calls,
    __handlers: handlers,
  };
});
jest.mock("../src/models/refresh-token.model", () => ({
  revokeAllByUserId: jest.fn(async () => {}),
}));

const db = require("../src/config/db");
const refreshTokenModel = require("../src/models/refresh-token.model");
const authV2Service = require("../src/services/auth.v2.service");

function on(pattern, respond) {
  db.__handlers.push({ pattern, respond });
}

beforeEach(() => {
  db.__calls.length = 0;
  db.__handlers.length = 0;
  jest.clearAllMocks();
});

describe("passenger registration requires a verified email OTP", () => {
  beforeEach(() => {
    on(/SELECT id FROM users WHERE (email|phone)/, () => []);
  });

  it("rejects registration when the email was never verified", async () => {
    on(/FROM otp_codes/, () => []);

    await expect(
      authV2Service.registerPassenger("Juan Dela Cruz", "juan@example.com", "09171234567", "password123")
    ).rejects.toMatchObject({ statusCode: 400 });
    expect(db.__calls.some((c) => /INSERT INTO users/.test(c.sql))).toBe(false);
  });

  it("rejects a verification older than the allowed window", async () => {
    on(/FROM otp_codes/, () => [
      { id: 1, is_verified: 1, verified_at: new Date(Date.now() - 2 * 60 * 60 * 1000) },
    ]);

    await expect(
      authV2Service.registerPassenger("Juan", "juan@example.com", "09171234567", "password123")
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it("creates the account and consumes the OTP once verified", async () => {
    on(/SELECT is_verified, verified_at FROM otp_codes/, () => [
      { id: 1, is_verified: 1, verified_at: new Date() },
    ]);

    const result = await authV2Service.registerPassenger(
      "Juan",
      "juan@example.com",
      "09171234567",
      "password123"
    );

    expect(result.success).toBe(true);
    expect(db.__calls.some((c) => /INSERT INTO users/.test(c.sql))).toBe(true);
    expect(db.__calls.some((c) => /DELETE FROM otp_codes/.test(c.sql))).toBe(true);
  });
});

describe("password reset with OTP", () => {
  const pendingCode = (overrides = {}) => ({ id: 7, code: "123456", attempts: 0, ...overrides });

  it("locks out after too many wrong attempts", async () => {
    on(/SELECT \* FROM otp_codes/, () => [pendingCode({ attempts: 5 })]);

    await expect(
      authV2Service.resetPasswordWithOTP("juan@example.com", "123456", "newpassword1")
    ).rejects.toMatchObject({ statusCode: 429 });
    expect(db.__calls.some((c) => /UPDATE users SET password_hash/.test(c.sql))).toBe(false);
  });

  it("counts a wrong code against the attempt limit", async () => {
    on(/SELECT \* FROM otp_codes/, () => [pendingCode()]);

    await expect(
      authV2Service.resetPasswordWithOTP("juan@example.com", "000000", "newpassword1")
    ).rejects.toMatchObject({ statusCode: 400 });
    expect(db.__calls.some((c) => /SET attempts = attempts \+ 1 WHERE id = \?/.test(c.sql))).toBe(true);
  });

  it("only accepts codes issued for password reset", async () => {
    on(/SELECT \* FROM otp_codes/, (_sql, params) => {
      expect(params).toContain(authV2Service.PASSWORD_RESET_PURPOSE);
      return [];
    });

    await expect(
      authV2Service.resetPasswordWithOTP("juan@example.com", "123456", "newpassword1")
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it("updates the password and signs out every session", async () => {
    on(/SELECT \* FROM otp_codes/, () => [pendingCode()]);
    on(/SELECT id FROM users WHERE email/, () => [{ id: 42 }]);

    const result = await authV2Service.resetPasswordWithOTP(
      "juan@example.com",
      "123456",
      "newpassword1"
    );

    expect(result.success).toBe(true);
    expect(db.__calls.some((c) => /UPDATE users SET password_hash/.test(c.sql))).toBe(true);
    expect(refreshTokenModel.revokeAllByUserId).toHaveBeenCalledWith(42, expect.anything());
  });
});

describe("driver applications require a verified email OTP", () => {
  it("rejects an applicant who hasn't verified recently", async () => {
    on(/FROM otp_codes/, () => []);

    await expect(authV2Service.assertDriverApplicationOtp("rider@example.com")).rejects.toMatchObject({
      statusCode: 403,
      details: { code: "OTP_REQUIRED" },
    });
  });

  it("only counts codes issued for driver applications", async () => {
    on(/FROM otp_codes/, (_sql, params) => {
      expect(params).toContain(authV2Service.DRIVER_APPLICATION_PURPOSE);
      return [{ is_verified: 1, verified_at: new Date() }];
    });

    await expect(authV2Service.assertDriverApplicationOtp("rider@example.com")).resolves.toBeUndefined();
  });

  it("rejects an application without an email on the account", async () => {
    await expect(authV2Service.assertDriverApplicationOtp(null)).rejects.toMatchObject({ statusCode: 400 });
  });
});
