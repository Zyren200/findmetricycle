require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(async () => []), withTransaction: jest.fn() }));
jest.mock("../src/models/admin-account.model");
jest.mock("../src/models/user.model");

const jwt = require("jsonwebtoken");
const request = require("supertest");
const db = require("../src/config/db");
const env = require("../src/config/env");
const adminAccountModel = require("../src/models/admin-account.model");
const userModel = require("../src/models/user.model");
const ApiError = require("../src/utils/api-error");
const {
  ADMIN_ROLES,
  PERMISSIONS: P,
  ROLE_PERMISSIONS,
  NOTIFICATION_TYPE_PERMISSIONS,
  isAdminRole,
  permissionsForRole,
  visibleNotificationTypes,
} = require("../src/constants/admin-permissions");
const {
  requireActiveAdmin,
  requirePermission,
  requireAnyPermission,
  requireBookingAccess,
} = require("../src/middlewares/adminAccess.middleware");

function adminRow(role, status = "active", userId = 1) {
  return { user_id: userId, admin_role: role, status, created_at: new Date("2026-01-01T00:00:00Z") };
}

function run(middleware, req) {
  return new Promise((resolve) => {
    const out = middleware(req, {}, (error) => resolve(error));
    if (out && typeof out.then === "function") out.catch(resolve);
  });
}

beforeEach(() => jest.clearAllMocks());

describe("role → permission map", () => {
  it("Super Admin holds every permission", () => {
    expect(permissionsForRole(ADMIN_ROLES.SUPER_ADMIN).sort()).toEqual(Object.values(P).sort());
  });

  it("Operations Admin can't touch SOS, earnings, system settings or admins", () => {
    const ops = permissionsForRole(ADMIN_ROLES.OPERATIONS_ADMIN);
    for (const p of [P.SOS_VIEW, P.SOS_RESPOND, P.EARNINGS_VIEW, P.SETTINGS_MANAGE, P.FARES_MANAGE,
      P.BARANGAYS_MANAGE, P.ACTIVITY_LOGS_VIEW, P.ADMINS_MANAGE]) {
      expect(ops).not.toContain(p);
    }
    expect(ops).toEqual(expect.arrayContaining([P.DRIVER_APPLICATIONS_REVIEW, P.BOOKINGS_CLOSE, P.COMPLAINTS_RESOLVE]));
  });

  it("SOS Responder gets only the dashboard, map, SOS and notifications", () => {
    expect(permissionsForRole(ADMIN_ROLES.SOS_RESPONDER).sort()).toEqual(
      [P.DASHBOARD_VIEW, P.LIVE_MAP_VIEW, P.SOS_VIEW, P.SOS_RESPOND, P.NOTIFICATIONS_VIEW].sort()
    );
  });

  it("unknown roles get nothing", () => {
    expect(isAdminRole("admin")).toBe(false);
    expect(isAdminRole("__proto__")).toBe(false);
    expect(permissionsForRole("root")).toEqual([]);
  });

  it("every role only uses defined permissions", () => {
    const defined = new Set(Object.values(P));
    for (const list of Object.values(ROLE_PERMISSIONS)) {
      for (const p of list) expect(defined.has(p)).toBe(true);
    }
    for (const p of Object.values(NOTIFICATION_TYPE_PERMISSIONS)) expect(defined.has(p)).toBe(true);
  });

  it("notification types follow the permissions", () => {
    expect(visibleNotificationTypes(permissionsForRole(ADMIN_ROLES.SUPER_ADMIN))).toBeNull();
    // Escalations (an SOS nobody acknowledged) go to Super Admins only.
    expect(visibleNotificationTypes(permissionsForRole(ADMIN_ROLES.SOS_RESPONDER))).toEqual(["sos_alert"]);
    expect(permissionsForRole(ADMIN_ROLES.SUPER_ADMIN)).toContain(P.SOS_ESCALATIONS_RECEIVE);
    const ops = visibleNotificationTypes(permissionsForRole(ADMIN_ROLES.OPERATIONS_ADMIN));
    expect(ops).toEqual(expect.arrayContaining(["driver_application", "new_booking", "driver_report"]));
    expect(ops).not.toContain("sos_alert");
  });
});

describe("every admin route checks a permission", () => {
  const router = require("../src/routes/admin.routes");
  const routes = router.stack.filter((layer) => layer.route);

  it("has routes to check", () => {
    expect(routes.length).toBeGreaterThan(30);
  });

  it("runs requireActiveAdmin for the whole router", () => {
    const shared = router.stack.filter((layer) => !layer.route).map((layer) => layer.handle);
    expect(shared).toContain(requireActiveAdmin);
  });

  it.each(routes.map((layer) => [`${Object.keys(layer.route.methods).join(",").toUpperCase()} ${layer.route.path}`, layer]))(
    "%s",
    (_name, layer) => {
      const handlers = layer.route.stack.map((l) => l.handle);
      const guardIndex = handlers.findIndex((h) => Array.isArray(h.requiredPermissions));
      expect(guardIndex).toBeGreaterThanOrEqual(0);
      // The guard runs before the controller (the last handler).
      expect(guardIndex).toBeLessThan(handlers.length - 1);
    }
  );

  it("driver documents and applications need driver application access", () => {
    const layer = routes.find((l) => l.route.path === "/drivers/:driverId" && l.route.methods.get);
    const guard = layer.route.stack.map((l) => l.handle).find((h) => h.requiredPermissions);
    expect(guard.requiredPermissions).toEqual([P.DRIVER_APPLICATIONS_VIEW]);
  });
});

describe("admin access middleware", () => {
  it("refuses a disabled admin with 401", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("super_admin", "disabled"));
    const error = await run(requireActiveAdmin, { user: { id: 1, role: "admin" } });
    expect(error).toBeInstanceOf(ApiError);
    expect(error.statusCode).toBe(401);
  });

  it("refuses non-admins with 403", async () => {
    const error = await run(requireActiveAdmin, { user: { id: 5, role: "passenger" } });
    expect(error.statusCode).toBe(403);
    expect(adminAccountModel.findByUserId).not.toHaveBeenCalled();
  });

  it("puts the admin's permissions on the request", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("sos_responder"));
    const req = { user: { id: 1, role: "admin" } };
    expect(await run(requireActiveAdmin, req)).toBeUndefined();
    expect(req.admin).toMatchObject({ userId: 1, role: "sos_responder", status: "active" });
    expect(req.admin.permissions).toContain(P.SOS_VIEW);
  });

  it("asks for a database update when the role columns are missing", async () => {
    adminAccountModel.findByUserId.mockRejectedValue(Object.assign(new Error("x"), { code: "ER_BAD_FIELD_ERROR" }));
    const error = await run(requireActiveAdmin, { user: { id: 1, role: "admin" } });
    expect(error.statusCode).toBe(503);
    expect(error.message).toMatch(/npm run migrate/);
  });

  it("requirePermission needs every listed permission", async () => {
    const req = { admin: { permissions: [P.BOOKINGS_VIEW] } };
    expect(await run(requirePermission(P.BOOKINGS_VIEW), req)).toBeUndefined();
    expect((await run(requirePermission(P.BOOKINGS_VIEW, P.BOOKINGS_CLOSE), req)).statusCode).toBe(403);
  });

  it("requireAnyPermission needs one of them", async () => {
    const req = { admin: { permissions: [P.EARNINGS_VIEW] } };
    expect(await run(requireAnyPermission(P.REPORTS_VIEW, P.EARNINGS_VIEW), req)).toBeUndefined();
    expect((await run(requireAnyPermission(P.REPORTS_VIEW), req)).statusCode).toBe(403);
  });

  it("an SOS responder can open only bookings that have an SOS alert", async () => {
    const req = { admin: { permissions: permissionsForRole("sos_responder") }, params: { bookingId: "12" } };
    db.query.mockResolvedValueOnce([{ id: 3 }]);
    expect(await run(requireBookingAccess, req)).toBeUndefined();
    expect(db.query.mock.calls[0][1]).toEqual([12]);

    db.query.mockResolvedValueOnce([]);
    expect((await run(requireBookingAccess, req)).statusCode).toBe(403);
  });

  it("anyone with bookings.view can open any booking", async () => {
    const req = { admin: { permissions: [P.BOOKINGS_VIEW] }, params: { bookingId: "12" } };
    expect(await run(requireBookingAccess, req)).toBeUndefined();
    expect(db.query).not.toHaveBeenCalled();
  });
});

describe("through the real routes", () => {
  const app = require("../src/app");
  const token = (userId) => jwt.sign({ userId, role: "admin", type: "access" }, env.jwt.secret, { expiresIn: "5m" });

  beforeEach(() => {
    userModel.findById.mockResolvedValue({ id: 4, role: "admin", status: "active", full_name: "Sos Sam" });
  });

  it("an SOS Responder can't read passengers, fares, settings or earnings", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("sos_responder", "active", 4));
    for (const path of ["/api/admin/passengers", "/api/admin/fare", "/api/admin/settings", "/api/admin/activity-logs",
      "/api/admin/drivers/pending", "/api/admin/complaints"]) {
      const res = await request(app).get(path).set("Authorization", `Bearer ${token(4)}`);
      expect([path, res.statusCode]).toEqual([path, 403]);
    }
  });

  it("an SOS Responder can't change fares even with a valid body", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("sos_responder", "active", 4));
    const res = await request(app)
      .put("/api/admin/fare")
      .set("Authorization", `Bearer ${token(4)}`)
      .send({ base_fare: 1 });
    expect(res.statusCode).toBe(403);

    // Logged as refused, under the admin's name — not as a fare change.
    await new Promise((resolve) => setImmediate(resolve));
    const log = db.query.mock.calls.find(([sql]) => /INSERT INTO activity_logs/.test(sql));
    expect(log[1][1]).toBe("Sos Sam");
    expect(log[1][2]).toBe("DENIED PUT /api/admin/fare");
  });

  it("a disabled admin's still-valid token gets 401 everywhere", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("super_admin", "disabled", 4));
    for (const path of ["/api/admin/sos", "/api/auth/me"]) {
      const res = await request(app).get(path).set("Authorization", `Bearer ${token(4)}`);
      expect([path, res.statusCode]).toEqual([path, 401]);
    }
  });

  it("/auth/me tells the dashboard the admin's role and permissions, never secrets", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("sos_responder", "active", 4));
    const res = await request(app).get("/api/auth/me").set("Authorization", `Bearer ${token(4)}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.data.admin).toEqual({
      role: "sos_responder",
      roleLabel: "SOS Responder",
      status: "active",
      permissions: permissionsForRole("sos_responder"),
    });
    expect(JSON.stringify(res.body)).not.toMatch(/password|token|otp/i);
  });

  it("driver documents are refused to admins without driver application access", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("sos_responder", "active", 4));
    const res = await request(app).get(`/api/documents/driver/license-1.jpg?token=${token(4)}`);
    expect(res.statusCode).toBe(403);
  });

  it("driver documents still reach admins who review applications", async () => {
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("operations_admin", "active", 4));
    const res = await request(app).get(`/api/documents/driver/does-not-exist.jpg?token=${token(4)}`);
    // Allowed through the access check; the file just isn't there.
    expect(res.statusCode).toBe(404);
  });
});

describe("general API rate limit key", () => {
  const { apiRateLimitKey } = require("../src/middlewares/rate-limit.middleware");
  const reqWith = (token) => ({ ip: "203.0.113.7", headers: token ? { authorization: `Bearer ${token}` } : {} });

  it("counts each admin account separately, so admins in one office don't throttle each other", () => {
    const a = jwt.sign({ userId: 3, role: "admin", type: "access" }, env.jwt.secret);
    const b = jwt.sign({ userId: 4, role: "admin", type: "access" }, env.jwt.secret);
    expect(apiRateLimitKey(reqWith(a))).toBe("admin:3");
    expect(apiRateLimitKey(reqWith(b))).toBe("admin:4");
  });

  it("still counts passengers, drivers, bad tokens and anonymous requests by IP", () => {
    const passenger = jwt.sign({ userId: 5, role: "passenger", type: "access" }, env.jwt.secret);
    const forged = jwt.sign({ userId: 3, role: "admin", type: "access" }, "not-the-secret");
    const refresh = jwt.sign({ userId: 3, role: "admin", type: "refresh" }, env.jwt.secret);
    for (const token of [passenger, forged, refresh, null]) {
      expect(apiRateLimitKey(reqWith(token))).toBe("203.0.113.7");
    }
  });
});

describe("sockets", () => {
  const { socketAuthMiddleware, onSocketConnection } = require("../src/sockets");
  const socketFor = (userId) => ({
    handshake: { auth: { token: jwt.sign({ userId, role: "admin", type: "access" }, env.jwt.secret) }, headers: {} },
    join: jest.fn(),
    on: jest.fn(),
  });

  it("refuse a disabled admin", async () => {
    userModel.findById.mockResolvedValue({ id: 4, role: "admin", status: "active" });
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("operations_admin", "disabled", 4));
    const socket = socketFor(4);
    const error = await new Promise((resolve) => socketAuthMiddleware(socket, resolve));
    expect(error).toBeInstanceOf(Error);
  });

  it("refuse an admin whose user account isn't active (no more admin bypass)", async () => {
    userModel.findById.mockResolvedValue({ id: 4, role: "admin", status: "suspended" });
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("super_admin", "active", 4));
    const error = await new Promise((resolve) => socketAuthMiddleware(socketFor(4), resolve));
    expect(error).toBeInstanceOf(Error);
  });

  it("join one room per permission, so SOS events reach only those allowed", async () => {
    userModel.findById.mockResolvedValue({ id: 4, role: "admin", status: "active" });
    adminAccountModel.findByUserId.mockResolvedValue(adminRow("sos_responder", "active", 4));
    const socket = socketFor(4);
    expect(await new Promise((resolve) => socketAuthMiddleware(socket, resolve))).toBeUndefined();
    await onSocketConnection(socket);
    const rooms = socket.join.mock.calls.map(([room]) => room);
    expect(rooms).toEqual(expect.arrayContaining(["user:4", "perm:sos.view", "perm:live_map.view"]));
    expect(rooms).not.toContain("perm:bookings.view");
    expect(rooms).not.toContain("perm:admins.manage");
  });
});
