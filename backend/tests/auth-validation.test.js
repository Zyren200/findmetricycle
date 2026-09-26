require("./setup-env");
const request = require("supertest");
const app = require("../src/app");

describe("Auth Validation", () => {
  it("should reject invalid login payload", async () => {
    const response = await request(app).post("/api/auth/login").send({
      phone: "bad",
      password: "",
    });

    expect(response.statusCode).toBe(400);
    expect(response.body.success).toBe(false);
    expect(response.body.message).toMatch(/validation/i);
  });

  it("should reject refresh when token is missing", async () => {
    const response = await request(app).post("/api/auth/refresh").send({});
    expect(response.statusCode).toBe(400);
    expect(response.body.success).toBe(false);
  });
});

