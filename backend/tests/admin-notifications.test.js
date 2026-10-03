require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(async () => []) }));

const db = require("../src/config/db");
const notificationModel = require("../src/models/notification.model");

const ADMIN_SCOPE = /n\.user_id IS NULL AND n\.recipient_role IN \('admin', 'everyone'\)/;

const SINCE = new Date("2026-02-01T00:00:00Z");
// Sees every type (Super Admin).
const superViewer = { userId: 1, since: SINCE, types: null };
// Sees only SOS types (SOS Responder).
const sosViewer = { userId: 4, since: SINCE, types: ["sos_alert", "sos_escalation"] };

beforeEach(() => jest.clearAllMocks());

describe("admin notification feed", () => {
  it("lists only admin/everyone notifications, never a user's personal ones", async () => {
    await notificationModel.listForAdmin(superViewer, { limit: 10 });
    expect(db.query.mock.calls[0][0]).toMatch(ADMIN_SCOPE);
  });

  it("read state is the admin's own, and older notifications count as read", async () => {
    db.query.mockResolvedValueOnce([
      { id: 9, type: "sos_alert", is_read: 1, read_at: "shared", admin_is_read: 0, admin_read_at: null },
    ]);
    const [row] = await notificationModel.listForAdmin(superViewer, {});
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/LEFT JOIN admin_notification_reads r ON r\.notification_id = n\.id AND r\.admin_user_id = \?/);
    expect(sql).toMatch(/n\.created_at < \?/);
    expect(params.slice(0, 2)).toEqual([SINCE, 1]);
    // The shared is_read column no longer decides it.
    expect(row).toMatchObject({ id: 9, is_read: 0, read_at: null });
    expect(row).not.toHaveProperty("admin_is_read");
  });

  it("only lists the types the admin's permissions cover", async () => {
    await notificationModel.listForAdmin(sosViewer, {});
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/AND n\.type IN \(\?, \?\)/);
    expect(params).toEqual(expect.arrayContaining(["sos_alert", "sos_escalation"]));
  });

  it("an admin who can see no types gets nothing", async () => {
    await notificationModel.listForAdmin({ userId: 9, since: SINCE, types: [] }, {});
    expect(db.query.mock.calls[0][0]).toMatch(/AND 1 = 0/);
  });

  it("'mark all read' records reads for this admin only, inside the admin feed", async () => {
    await notificationModel.markAllReadForAdmin(sosViewer);
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/INSERT IGNORE INTO admin_notification_reads/);
    expect(sql).not.toMatch(/UPDATE notifications/);
    expect(sql).toMatch(ADMIN_SCOPE);
    expect(sql).toMatch(/n\.type IN/);
    expect(params[0]).toBe(4);
  });

  it("marking one read is limited to the admin feed and the admin's types", async () => {
    await notificationModel.markReadForAdmin(sosViewer, 5);
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/INSERT IGNORE INTO admin_notification_reads/);
    expect(sql).toMatch(ADMIN_SCOPE);
    expect(sql).toMatch(/n\.type IN/);
    expect(params.slice(0, 2)).toEqual([4, 5]);
  });

  it("counts unread for this admin only", async () => {
    db.query.mockResolvedValueOnce([{ n: 3 }]);
    await expect(notificationModel.countUnreadForAdmin(superViewer)).resolves.toBe(3);
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(ADMIN_SCOPE);
    expect(sql).toMatch(/n\.created_at >= \?/);
    expect(sql).toMatch(/NOT EXISTS/);
    expect(params).toEqual([SINCE, 1]);
  });
});

describe("passenger / driver notification feeds", () => {
  it("keeps a dual-role account's passenger and driver notifications apart", async () => {
    await notificationModel.listForUser(27, { role: "passenger" });
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/user_id = \? AND recipient_role IN \(\?, 'everyone'\)/);
    expect(params.slice(0, 3)).toEqual([27, "passenger", "passenger"]);
  });

  it("marks read only the caller's own notifications", async () => {
    await notificationModel.markReadForUser(27, "driver", [4, 5]);
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/user_id = \?/);
    expect(sql).toMatch(/id IN \(\?, \?\)/);
    expect(params).toEqual([27, "driver", 4, 5]);
  });
});
