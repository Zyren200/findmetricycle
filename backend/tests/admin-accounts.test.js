require("./setup-env");

const mockClient = { query: jest.fn(async () => []) };
jest.mock("../src/config/db", () => ({
  query: jest.fn(async () => []),
  withTransaction: jest.fn(async (work) => work(mockClient)),
}));
jest.mock("../src/models/user.model");
jest.mock("../src/models/admin-account.model");
jest.mock("../src/models/refresh-token.model");
jest.mock("../src/services/mail.service");

const db = require("../src/config/db");
const userModel = require("../src/models/user.model");
const adminAccountModel = require("../src/models/admin-account.model");
const refreshTokenModel = require("../src/models/refresh-token.model");
const mailService = require("../src/services/mail.service");
const service = require("../src/services/admin-accounts.service");

const actor = { userId: 1, name: "Sally Super" };

function row(userId, role, status = "active", extra = {}) {
  return {
    user_id: userId,
    admin_role: role,
    status,
    full_name: `Admin ${userId}`,
    email: `admin${userId}@x.test`,
    phone: `0917000000${userId}`,
    created_at: new Date(),
    password_set_at: new Date(),
    ...extra,
  };
}

function activityLogs() {
  return [...mockClient.query.mock.calls, ...db.query.mock.calls]
    .filter(([sql]) => /INSERT INTO activity_logs/.test(sql))
    .map(([, params]) => ({ adminId: params[0], adminName: params[1], action: params[2], targetId: params[3] }));
}

beforeEach(() => {
  jest.clearAllMocks();
  refreshTokenModel.revokeAllByUserId.mockResolvedValue();
  mailService.sendAdminAccessEmail.mockResolvedValue(true);
});

describe("creating an admin", () => {
  beforeEach(() => {
    userModel.findByEmail.mockResolvedValue(null);
    userModel.findByPhone.mockResolvedValue(null);
    userModel.createUser.mockImplementation(async (payload) => ({ id: 9, full_name: payload.fullName, ...payload }));
    adminAccountModel.findByUserId.mockResolvedValue(row(9, "sos_responder", "active", { password_set_at: null }));
  });

  it("creates the account with a password nobody knows and emails setup steps (no password, no code)", async () => {
    const result = await service.createAdmin(actor, {
      fullName: "Sam Sos",
      email: "sam@x.test",
      phone: "09170000009",
      role: "sos_responder",
    });

    const created = userModel.createUser.mock.calls[0][0];
    expect(created).toMatchObject({ role: "admin", email: "sam@x.test", phone: "09170000009" });
    expect(created.passwordHash).toMatch(/^\$2[aby]\$12\$/);
    expect(adminAccountModel.createProfile).toHaveBeenCalledWith(
      9,
      { role: "sos_responder", createdBy: 1, passwordSet: false },
      mockClient
    );
    expect(mailService.sendAdminAccessEmail).toHaveBeenCalledWith("sam@x.test", "Admin 9", {
      kind: "welcome",
      roleLabel: "SOS Responder",
    });
    expect(result.welcomeEmailSent).toBe(true);
    expect(result.admin).toMatchObject({ id: 9, role: "sos_responder", passwordSet: false });
    expect(JSON.stringify(result)).not.toMatch(/password_hash|\$2[aby]\$/);
    expect(activityLogs()).toEqual([
      { adminId: 1, adminName: "Sally Super", action: "Admin Account Created", targetId: 9 },
    ]);
  });

  it("refuses an email any account already uses", async () => {
    userModel.findByEmail.mockResolvedValue({ id: 3, role: "passenger" });
    await expect(
      service.createAdmin(actor, { fullName: "X Y", email: "pia@x.test", phone: "09170000010", role: "operations_admin" })
    ).rejects.toMatchObject({ statusCode: 409, details: { field: "email" } });
    expect(userModel.createUser).not.toHaveBeenCalled();
  });

  it("refuses a phone any account already uses", async () => {
    userModel.findByPhone.mockResolvedValue({ id: 3 });
    await expect(
      service.createAdmin(actor, { fullName: "X Y", email: "new@x.test", phone: "09170000005", role: "operations_admin" })
    ).rejects.toMatchObject({ statusCode: 409, details: { field: "phone" } });
  });

  it("rejects unknown roles", async () => {
    await expect(
      service.createAdmin(actor, { fullName: "X Y", email: "new@x.test", phone: "09170000011", role: "root" })
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it("still creates the admin when the welcome email fails", async () => {
    mailService.sendAdminAccessEmail.mockResolvedValue(false);
    const result = await service.createAdmin(actor, {
      fullName: "Sam Sos",
      email: "sam2@x.test",
      phone: "09170000012",
      role: "sos_responder",
    });
    expect(result.welcomeEmailSent).toBe(false);
    expect(result.admin.id).toBe(9);
  });
});

describe("safety rules", () => {
  it("an admin can't change their own role", async () => {
    await expect(service.changeRole(actor, 1, "sos_responder")).rejects.toMatchObject({ statusCode: 403 });
    expect(adminAccountModel.updateRole).not.toHaveBeenCalled();
  });

  it("an admin can't disable themselves", async () => {
    await expect(service.setStatus(actor, 1, "disabled")).rejects.toMatchObject({ statusCode: 403 });
    expect(adminAccountModel.updateStatus).not.toHaveBeenCalled();
  });

  it("the last active Super Admin can't be demoted", async () => {
    adminAccountModel.lockActiveSuperAdmins.mockResolvedValue([{ user_id: 2 }]);
    adminAccountModel.findByUserId.mockResolvedValue(row(2, "super_admin"));
    await expect(service.changeRole(actor, 2, "operations_admin")).rejects.toMatchObject({ statusCode: 409 });
    expect(adminAccountModel.updateRole).not.toHaveBeenCalled();
  });

  it("the last active Super Admin can't be disabled", async () => {
    adminAccountModel.lockActiveSuperAdmins.mockResolvedValue([{ user_id: 2 }]);
    adminAccountModel.findByUserId.mockResolvedValue(row(2, "super_admin"));
    await expect(service.setStatus(actor, 2, "disabled")).rejects.toMatchObject({ statusCode: 409 });
  });

  it("checks the Super Admin count under a lock, inside the transaction", async () => {
    adminAccountModel.lockActiveSuperAdmins.mockResolvedValue([{ user_id: 1 }, { user_id: 2 }]);
    adminAccountModel.findByUserId.mockResolvedValue(row(2, "super_admin"));
    await service.changeRole(actor, 2, "operations_admin");
    expect(db.withTransaction).toHaveBeenCalled();
    expect(adminAccountModel.lockActiveSuperAdmins).toHaveBeenCalledWith(mockClient);
    expect(adminAccountModel.findByUserId).toHaveBeenCalledWith(2, mockClient, { forUpdate: true });
  });

  it("returns 404 for an account that isn't an admin", async () => {
    adminAccountModel.lockActiveSuperAdmins.mockResolvedValue([{ user_id: 1 }]);
    adminAccountModel.findByUserId.mockResolvedValue(null);
    await expect(service.setStatus(actor, 77, "disabled")).rejects.toMatchObject({ statusCode: 404 });
  });
});

describe("changes take effect at once", () => {
  beforeEach(() => {
    adminAccountModel.lockActiveSuperAdmins.mockResolvedValue([{ user_id: 1 }]);
  });

  it("changing a role revokes their sessions and logs it", async () => {
    adminAccountModel.findByUserId
      .mockResolvedValueOnce(row(3, "operations_admin"))
      .mockResolvedValueOnce(row(3, "sos_responder"));
    const result = await service.changeRole(actor, 3, "sos_responder");
    expect(adminAccountModel.updateRole).toHaveBeenCalledWith(3, "sos_responder", mockClient);
    expect(refreshTokenModel.revokeAllByUserId).toHaveBeenCalledWith(3);
    expect(result.role).toBe("sos_responder");
    expect(activityLogs()).toEqual([
      { adminId: 1, adminName: "Sally Super", action: "Admin Role Changed", targetId: 3 },
    ]);
  });

  it("setting the same role again changes nothing and signs nobody out", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(row(3, "operations_admin"));
    await service.changeRole(actor, 3, "operations_admin");
    expect(adminAccountModel.updateRole).not.toHaveBeenCalled();
    expect(refreshTokenModel.revokeAllByUserId).not.toHaveBeenCalled();
  });

  it("disabling revokes their sessions; enabling doesn't", async () => {
    adminAccountModel.findByUserId
      .mockResolvedValueOnce(row(3, "operations_admin"))
      .mockResolvedValueOnce(row(3, "operations_admin", "disabled"));
    await service.setStatus(actor, 3, "disabled");
    expect(refreshTokenModel.revokeAllByUserId).toHaveBeenCalledWith(3);

    refreshTokenModel.revokeAllByUserId.mockClear();
    adminAccountModel.findByUserId
      .mockResolvedValueOnce(row(3, "operations_admin", "disabled"))
      .mockResolvedValueOnce(row(3, "operations_admin"));
    await service.setStatus(actor, 3, "active");
    expect(refreshTokenModel.revokeAllByUserId).not.toHaveBeenCalled();
    expect(activityLogs().map((l) => l.action)).toEqual(["Admin Disabled", "Admin Enabled"]);
  });
});

describe("send password reset", () => {
  it("emails reset steps (no code) and logs it", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(row(4, "operations_admin"));
    const result = await service.sendPasswordReset(actor, 4);
    expect(mailService.sendAdminAccessEmail).toHaveBeenCalledWith("admin4@x.test", "Admin 4", {
      kind: "reset",
      roleLabel: "Operations Admin",
    });
    expect(result).toEqual({ sent: true, email: "admin4@x.test" });
    expect(activityLogs()[0].action).toBe("Admin Password Reset Sent");
  });

  it("re-sends the setup email to an admin who never set a password", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(row(5, "sos_responder", "active", { password_set_at: null }));
    await service.sendPasswordReset(actor, 5);
    expect(mailService.sendAdminAccessEmail.mock.calls[0][2].kind).toBe("welcome");
  });

  it("refuses a disabled admin", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(row(6, "sos_responder", "disabled"));
    await expect(service.sendPasswordReset(actor, 6)).rejects.toMatchObject({ statusCode: 409 });
    expect(mailService.sendAdminAccessEmail).not.toHaveBeenCalled();
  });

  it("caps emails to one address", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(row(7, "sos_responder", "active", { email: "capped@x.test" }));
    await service.sendPasswordReset(actor, 7);
    await service.sendPasswordReset(actor, 7);
    await service.sendPasswordReset(actor, 7);
    await expect(service.sendPasswordReset(actor, 7)).rejects.toMatchObject({ statusCode: 429 });
    expect(mailService.sendAdminAccessEmail).toHaveBeenCalledTimes(3);
  });
});

describe("listing", () => {
  it("marks the signed-in admin and never includes password data", async () => {
    adminAccountModel.listAll.mockResolvedValue([row(1, "super_admin"), row(2, "sos_responder", "disabled")]);
    const list = await service.listAdmins(actor);
    expect(list.map((a) => [a.id, a.isSelf, a.status])).toEqual([[1, true, "active"], [2, false, "disabled"]]);
    expect(Object.keys(list[0])).not.toContain("password_hash");
    expect(service.roleCatalog().map((r) => r.value)).toEqual(["super_admin", "operations_admin", "sos_responder"]);
  });
});
