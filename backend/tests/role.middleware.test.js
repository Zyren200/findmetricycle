require("./setup-env");
const ApiError = require("../src/utils/api-error");
const requireRole = require("../src/middlewares/role.middleware");

describe("Role middleware", () => {
  it("allows access when role is included", () => {
    const middleware = requireRole("admin", "driver");
    const req = { user: { role: "admin" } };
    const next = jest.fn();

    middleware(req, null, next);

    expect(next).toHaveBeenCalledWith();
  });

  it("rejects access when role is not included", () => {
    const middleware = requireRole("admin");
    const req = { user: { role: "driver" } };
    const next = jest.fn();

    middleware(req, null, next);

    expect(next).toHaveBeenCalled();
    const error = next.mock.calls[0][0];
    expect(error).toBeInstanceOf(ApiError);
    expect(error.statusCode).toBe(403);
  });

  it("rejects anonymous access", () => {
    const middleware = requireRole("admin");
    const req = {};
    const next = jest.fn();

    middleware(req, null, next);

    expect(next).toHaveBeenCalled();
    const error = next.mock.calls[0][0];
    expect(error).toBeInstanceOf(ApiError);
    expect(error.statusCode).toBe(401);
  });
});
