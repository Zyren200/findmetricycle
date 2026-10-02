require("./setup-env");

const crypto = require("crypto");

jest.mock("../src/config/db", () => ({ query: jest.fn(), withTransaction: jest.fn() }));
jest.mock("../src/models/push-token.model");

// A throwaway service account: a real RSA key so the token request is
// signed for real, but every call to Google is mocked below.
const { privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const SERVICE_ACCOUNT = JSON.stringify({
  project_id: "findme-test",
  client_email: "push@findme-test.iam.gserviceaccount.com",
  private_key: privateKey.export({ type: "pkcs8", format: "pem" }),
});

function jsonResponse(status, body) {
  return { ok: status >= 200 && status < 300, status, json: async () => body };
}

function loadPush({ configured }) {
  jest.resetModules();
  if (configured) process.env.FIREBASE_SERVICE_ACCOUNT_JSON = SERVICE_ACCOUNT;
  else delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  return {
    push: require("../src/services/push.service"),
    tokens: require("../src/models/push-token.model"),
  };
}

const RIDE_REQUEST = {
  id: 9,
  type: "ride_request",
  title: "New ride request",
  body: "A passenger chose you for a ride from Plaza.",
  metadata: { bookingId: 50 },
};

beforeEach(() => {
  global.fetch = jest.fn();
});

afterAll(() => {
  delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
});

describe("push notifications", () => {
  it("stay off without a Firebase service account", async () => {
    const { push } = loadPush({ configured: false });
    expect(push.isEnabled()).toBe(false);
    await push.notifyUser(7, RIDE_REQUEST);
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it("send a ride request as a short-lived, high-priority push", async () => {
    const { push, tokens } = loadPush({ configured: true });
    tokens.listTokensForUser.mockResolvedValue(["device-token-aaaaaaaaaaaaaaaa"]);
    global.fetch
      .mockResolvedValueOnce(jsonResponse(200, { access_token: "ya29.test", expires_in: 3600 }))
      .mockResolvedValueOnce(jsonResponse(200, { name: "projects/findme-test/messages/1" }));

    await push.notifyUser(7, RIDE_REQUEST);

    const [authUrl, authInit] = global.fetch.mock.calls[0];
    expect(authUrl).toBe("https://oauth2.googleapis.com/token");
    expect(String(authInit.body)).toContain("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer");

    const [sendUrl, sendInit] = global.fetch.mock.calls[1];
    expect(sendUrl).toBe("https://fcm.googleapis.com/v1/projects/findme-test/messages:send");
    expect(sendInit.headers.Authorization).toBe("Bearer ya29.test");
    const { message } = JSON.parse(sendInit.body);
    expect(message).toMatchObject({
      token: "device-token-aaaaaaaaaaaaaaaa",
      notification: { title: "New ride request" },
      data: { type: "ride_request", bookingId: "50", notificationId: "9" },
      android: { priority: "HIGH", ttl: "30s", notification: { channel_id: "ride_requests" } },
    });
  });

  it("forget a device whose app was uninstalled", async () => {
    const { push, tokens } = loadPush({ configured: true });
    tokens.listTokensForUser.mockResolvedValue(["gone-token-aaaaaaaaaaaaaaaaaa", "live-token-aaaaaaaaaaaaaaaaaa"]);
    global.fetch.mockImplementation(async (url, init) => {
      if (url.includes("oauth2")) return jsonResponse(200, { access_token: "ya29.test", expires_in: 3600 });
      const { message } = JSON.parse(init.body);
      return message.token.startsWith("gone")
        ? jsonResponse(404, { error: { status: "NOT_FOUND", details: [{ errorCode: "UNREGISTERED" }] } })
        : jsonResponse(200, {});
    });

    await push.notifyUser(7, { ...RIDE_REQUEST, type: "booking_accepted" });

    expect(tokens.removeTokens).toHaveBeenCalledWith(["gone-token-aaaaaaaaaaaaaaaaaa"]);
  });

  it("never throws into the ride flow when Firebase is down", async () => {
    const { push, tokens } = loadPush({ configured: true });
    tokens.listTokensForUser.mockResolvedValue(["device-token-aaaaaaaaaaaaaaaa"]);
    global.fetch.mockRejectedValue(new Error("network down"));
    const warn = jest.spyOn(console, "warn").mockImplementation(() => {});

    await expect(push.notifyUser(7, RIDE_REQUEST)).resolves.toBeUndefined();
    warn.mockRestore();
  });
});

describe("notifications reach the phone", () => {
  it("pushes every notification addressed to a user", async () => {
    jest.resetModules();
    jest.doMock("../src/models/notification.model", () => ({
      createNotification: jest.fn(async (row) => ({ id: 3, ...row, user_id: row.userId, metadata_json: row.metadataJson })),
    }));
    jest.doMock("../src/services/push.service", () => ({ notifyUser: jest.fn(), notifyAudience: jest.fn() }));
    const notificationService = require("../src/services/notification.service");
    const push = require("../src/services/push.service");

    await notificationService.createNotification({
      type: "driver_arrived",
      title: "Your driver has arrived",
      body: "Give the driver your pickup PIN.",
      userId: 7,
      recipientRole: "passenger",
      metadataJson: { bookingId: 50 },
    });
    await notificationService.createNotification({ type: "new_booking", title: "x", body: "y", recipientRole: "admin" });

    expect(push.notifyUser).toHaveBeenCalledTimes(1);
    expect(push.notifyUser).toHaveBeenCalledWith(7, expect.objectContaining({ type: "driver_arrived" }));
  });
});
