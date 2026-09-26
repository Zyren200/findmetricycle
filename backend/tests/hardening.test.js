require("./setup-env");
const escapeHtml = require("../src/utils/escape-html");
const errorMiddleware = require("../src/middlewares/error.middleware");
const ApiError = require("../src/utils/api-error");
const { splitStatements } = require("../scripts/run-migrations");

function fakeRes() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

describe("escapeHtml", () => {
  it("neutralises markup in user-supplied names", () => {
    expect(escapeHtml(`<img src=x onerror="alert('x')">`)).toBe(
      "&lt;img src=x onerror=&quot;alert(&#39;x&#39;)&quot;&gt;"
    );
    expect(escapeHtml(null)).toBe("");
  });
});

describe("error middleware", () => {
  const req = { method: "GET", originalUrl: "/api/test" };

  it("hides internal error details from the client", () => {
    const spy = jest.spyOn(console, "error").mockImplementation(() => {});
    const res = fakeRes();
    errorMiddleware(new Error("ER_NO_SUCH_TABLE: Table 'otp_codes' doesn't exist"), req, res);
    expect(res.statusCode).toBe(500);
    expect(res.body.message).toBe("Internal server error");
    spy.mockRestore();
  });

  it("passes through expected client errors", () => {
    const res = fakeRes();
    errorMiddleware(new ApiError(409, "Email already registered"), req, res);
    expect(res.statusCode).toBe(409);
    expect(res.body.message).toBe("Email already registered");
  });

  it("keeps the status of body-parser errors instead of turning them into 500s", () => {
    const res = fakeRes();
    const parseError = Object.assign(new Error("Unexpected token"), { status: 400 });
    errorMiddleware(parseError, req, res);
    expect(res.statusCode).toBe(400);
  });
});

describe("migration statement splitter", () => {
  it("splits on semicolons but not inside strings or comments", () => {
    const sql = `
      -- comment; with a semicolon
      SET @sql = IF(@x = 0, 'ALTER TABLE t ADD c ENUM(''a;b'')', 'SELECT 1');
      PREPARE stmt FROM @sql; EXECUTE stmt;
    `;
    expect(splitStatements(sql)).toEqual([
      "SET @sql = IF(@x = 0, 'ALTER TABLE t ADD c ENUM(''a;b'')', 'SELECT 1')",
      "PREPARE stmt FROM @sql",
      "EXECUTE stmt",
    ]);
  });
});

describe("request logging", () => {
  it("never writes document access tokens to the log", async () => {
    const request = require("supertest");
    const app = require("../src/app");
    const lines = [];
    const spy = jest.spyOn(process.stdout, "write").mockImplementation((chunk) => {
      lines.push(String(chunk));
      return true;
    });
    await request(app).get("/api/documents/driver/x.jpg?token=SECRET_TOKEN_VALUE");
    await new Promise((r) => setImmediate(r));
    spy.mockRestore();
    const log = lines.join("");
    expect(log).toContain("token=[redacted]");
    expect(log).not.toContain("SECRET_TOKEN_VALUE");
  });
});
