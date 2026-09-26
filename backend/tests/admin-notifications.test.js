require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(async () => []) }));

const db = require("../src/config/db");
const notificationModel = require("../src/models/notification.model");

const ADMIN_SCOPE = /user_id IS NULL AND recipient_role IN \('admin', 'everyone'\)/;

beforeEach(() => jest.clearAllMocks());

describe("admin notification feed", () => {
  it("lists only admin/everyone notifications, never a user's personal ones", async () => {
    await notificationModel.listNotifications({ limit: 10 });
    expect(db.query.mock.calls[0][0]).toMatch(ADMIN_SCOPE);
  });

  it("'mark all read' can't touch passengers' or drivers' notifications", async () => {
    await notificationModel.markAllRead();
    expect(db.query.mock.calls[0][0]).toMatch(ADMIN_SCOPE);
  });

  it("marking one read is limited to the admin feed", async () => {
    await notificationModel.markRead(5);
    expect(db.query.mock.calls[0][0]).toMatch(ADMIN_SCOPE);
  });

  it("counts unread for the admin feed only", async () => {
    db.query.mockResolvedValueOnce([{ n: 3 }]);
    await expect(notificationModel.countUnreadForAdmin()).resolves.toBe(3);
    expect(db.query.mock.calls[0][0]).toMatch(ADMIN_SCOPE);
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
