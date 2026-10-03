require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(async () => []), withTransaction: jest.fn() }));
jest.mock("../src/models/user.model");
jest.mock("../src/models/refresh-token.model");
jest.mock("../src/models/admin-account.model");

const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const db = require("../src/config/db");
const env = require("../src/config/env");
const userModel = require("../src/models/user.model");
const refreshTokenModel = require("../src/models/refresh-token.model");
const adminAccountModel = require("../src/models/admin-account.model");
const authService = require("../src/services/auth.service");
const authV2Service = require("../src/services/auth.v2.service");

let passwordHash;
beforeAll(async () => {
  passwordHash = await bcrypt.hash("correct-password", 4);
});

beforeEach(() => {
  jest.clearAllMocks();
  refreshTokenModel.createToken.mockResolvedValue();
  refreshTokenModel.revokeAllByUserId.mockResolvedValue();
  refreshTokenModel.revokeTokenByHash.mockResolvedValue();
});

function adminUser(id) {
  return { id, role: "admin", status: "active", email: `admin${id}@x.test`, full_name: "Admin", password_hash: passwordHash };
}

function adminRow(id, role, status = "active") {
  return { user_id: id, admin_role: role, status, created_at: new Date(), email: `admin${id}@x.test` };
}

describe("admin login", () => {
  it("returns the admin's role and permissions and records the login", async () => {
    userModel.findByEmail.mockResolvedValue(adminUser(11));
    adminAccountModel.findByUserId.mockResolvedValue(adminRow(11, "operations_admin"));

    const result = await authService.login({ email: "admin11@x.test", password: "correct-password" });

    expect(result.user.admin).toMatchObject({ role: "operations_admin", roleLabel: "Operations Admin" });
    expect(result.user.admin.permissions).toContain("bookings.view");
    expect(result.user.admin.permissions).not.toContain("admins.manage");
    expect(result.user).not.toHaveProperty("password_hash");
    expect(adminAccountModel.touchLastLogin).toHaveBeenCalledWith(11);
  });

  it("refuses a disabled admin even with the right password, without issuing tokens", async () => {
    userModel.findByEmail.mockResolvedValue(adminUser(12));
    adminAccountModel.findByUserId.mockResolvedValue(adminRow(12, "super_admin", "disabled"));

    await expect(authService.login({ email: "admin12@x.test", password: "correct-password" })).rejects.toMatchObject({
      statusCode: 403,
      message: "This admin account has been disabled.",
    });
    expect(refreshTokenModel.createToken).not.toHaveBeenCalled();
  });

  it("locks one admin account after 10 wrong passwords, whatever the IP", async () => {
    userModel.findByEmail.mockResolvedValue(adminUser(13));
    adminAccountModel.findByUserId.mockResolvedValue(adminRow(13, "super_admin"));

    for (let i = 0; i < 10; i += 1) {
      await expect(authService.login({ email: "admin13@x.test", password: "wrong" })).rejects.toMatchObject({
        statusCode: 401,
      });
    }
    // Even the right password is refused until the window passes.
    await expect(authService.login({ email: "admin13@x.test", password: "correct-password" })).rejects.toMatchObject({
      statusCode: 429,
    });
  });

  it("doesn't add the per-account lock to passengers", async () => {
    userModel.findByEmail.mockResolvedValue({ ...adminUser(14), role: "passenger" });
    for (let i = 0; i < 12; i += 1) {
      await expect(authService.login({ email: "p@x.test", password: "wrong" })).rejects.toMatchObject({ statusCode: 401 });
    }
    const result = await authService.login({ email: "p@x.test", password: "correct-password" });
    expect(result.user).not.toHaveProperty("admin");
  });
});

describe("admin token refresh", () => {
  function refreshTokenFor(userId) {
    return jwt.sign({ userId, role: "admin", tokenId: "t", type: "refresh" }, env.jwt.refreshSecret);
  }

  it("refuses a disabled admin and revokes all their sessions", async () => {
    refreshTokenModel.findActiveTokenByHash.mockResolvedValue({ user_id: 15 });
    userModel.findById.mockResolvedValue(adminUser(15));
    adminAccountModel.findByUserId.mockResolvedValue(adminRow(15, "sos_responder", "disabled"));

    await expect(authService.refreshAccessToken({ refreshToken: refreshTokenFor(15) })).rejects.toMatchObject({
      statusCode: 401,
    });
    expect(refreshTokenModel.revokeAllByUserId).toHaveBeenCalledWith(15);
    expect(refreshTokenModel.createToken).not.toHaveBeenCalled();
  });

  it("hands an active admin the current permissions (a role change shows up on refresh)", async () => {
    refreshTokenModel.findActiveTokenByHash.mockResolvedValue({ user_id: 16 });
    userModel.findById.mockResolvedValue(adminUser(16));
    adminAccountModel.findByUserId.mockResolvedValue(adminRow(16, "sos_responder"));

    const result = await authService.refreshAccessToken({ refreshToken: refreshTokenFor(16) });
    expect(result.user.admin.role).toBe("sos_responder");
  });
});

describe("admin forgot password uses each admin's own email", () => {
  it("rejects an email that isn't an admin account", async () => {
    adminAccountModel.findByEmail.mockResolvedValue(null);
    const send = jest.spyOn(authV2Service, "requestPasswordReset");
    await expect(authService.requestAdminPasswordReset("passenger@x.test")).rejects.toMatchObject({
      statusCode: 404,
      details: { field: "email" },
    });
    expect(send).not.toHaveBeenCalled();
  });

  it("rejects a disabled admin", async () => {
    adminAccountModel.findByEmail.mockResolvedValue(adminRow(17, "operations_admin", "disabled"));
    await expect(authService.requestAdminPasswordReset("admin17@x.test")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("sends the code to the admin's own email", async () => {
    adminAccountModel.findByEmail.mockResolvedValue(adminRow(18, "operations_admin"));
    const send = jest.spyOn(authV2Service, "requestPasswordReset").mockResolvedValue({ success: true });
    await authService.requestAdminPasswordReset("  admin18@x.test ");
    expect(send).toHaveBeenCalledWith("admin18@x.test");
  });

  it("won't reset without the verified code itself", async () => {
    adminAccountModel.findByEmail.mockResolvedValue(adminRow(19, "operations_admin"));
    db.query.mockResolvedValueOnce([{ code: "123456", is_verified: 1, verified_at: new Date() }]);
    await expect(authService.resetAdminPassword("admin19@x.test", "654321", "new-password-1")).rejects.toMatchObject({
      statusCode: 400,
    });
    expect(userModel.updatePasswordHash).not.toHaveBeenCalled();
  });

  it("resets that admin's password and signs out their sessions", async () => {
    adminAccountModel.findByEmail.mockResolvedValue(adminRow(20, "operations_admin"));
    db.query.mockResolvedValueOnce([{ code: "123456", is_verified: 1, verified_at: new Date() }]);

    await authService.resetAdminPassword("admin20@x.test", "123456", "new-password-1");

    expect(userModel.updatePasswordHash).toHaveBeenCalledWith(20, expect.any(String));
    expect(adminAccountModel.markPasswordSet).toHaveBeenCalledWith(20);
    expect(refreshTokenModel.revokeAllByUserId).toHaveBeenCalledWith(20);
  });

  it("won't accept a code verified more than 30 minutes ago", async () => {
    adminAccountModel.findByEmail.mockResolvedValue(adminRow(21, "operations_admin"));
    db.query.mockResolvedValueOnce([
      { code: "123456", is_verified: 1, verified_at: new Date(Date.now() - 31 * 60 * 1000) },
    ]);
    await expect(authService.resetAdminPassword("admin21@x.test", "123456", "new-password-1")).rejects.toMatchObject({
      statusCode: 400,
    });
  });
});
