require("./setup-env");
const request = require("supertest");
const app = require("../src/app");

describe("Health Endpoint", () => {
  it("should return API health message", async () => {
    const response = await request(app).get("/api/health");
    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.message).toMatch(/running/i);
  });
});

