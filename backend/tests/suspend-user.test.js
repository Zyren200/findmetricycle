require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(), withTransaction: jest.fn() }));
jest.mock("../src/models/user.model");
jest.mock("../src/models/refresh-token.model");

const db = require("../src/config/db");
const userModel = require("../src/models/user.model");
const refreshTokenModel = require("../src/models/refresh-token.model");
const adminService = require("../src/services/admin.service");

beforeEach(() => {
  jest.clearAllMocks();
  userModel.findById.mockResolvedValue({ id: 7, role: "passenger", status: "active" });
  userModel.suspendUser.mockResolvedValue({ id: 7, status: "suspended" });
});

describe("suspending a user", () => {
  it("is refused while they have an active ride", async () => {
    db.query.mockResolvedValueOnce([{ id: 40 }]);
    await expect(adminService.suspendPassenger(7)).rejects.toMatchObject({ statusCode: 409 });
    expect(userModel.suspendUser).not.toHaveBeenCalled();
  });

  it("signs them out and takes their driver mode offline", async () => {
    db.query.mockResolvedValue([]);
    await adminService.suspendPassenger(7);
    expect(userModel.suspendUser).toHaveBeenCalledWith(7);
    expect(refreshTokenModel.revokeAllByUserId).toHaveBeenCalledWith(7);
    expect(db.query).toHaveBeenCalledWith(expect.stringMatching(/is_online = 0/), [7]);
  });
});
