require("./setup-env");

jest.mock("../src/config/db", () => ({
  query: jest.fn(),
  withTransaction: jest.fn(async (work) => work({ query: jest.fn() })),
}));
jest.mock("../src/models/driver-application.model");
jest.mock("../src/models/driver.model");

const driverApplicationModel = require("../src/models/driver-application.model");
const driverModel = require("../src/models/driver.model");
const adminService = require("../src/services/admin.service");

function application(overrides = {}) {
  return {
    id: 11,
    user_id: 27,
    driver_id: 5,
    status: "pending",
    documents_checked_at: new Date(),
    license_check_status: "verified",
    permit_check_status: "verified",
    ...overrides,
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  driverModel.findById.mockResolvedValue({ id: 5 });
  driverModel.approveDriver.mockResolvedValue({ id: 5, approval_status: "approved" });
  driverApplicationModel.markApproved.mockResolvedValue({ id: 11, status: "approved" });
});

describe("approving a driver with flagged documents", () => {
  it("is refused until the admin acknowledges the warnings", async () => {
    driverApplicationModel.findById.mockResolvedValue(
      application({ license_check_status: "suspicious", permit_check_status: "unreadable" })
    );

    await expect(adminService.approveDriver(11, 1)).rejects.toMatchObject({
      statusCode: 409,
      details: { code: "DOCUMENT_CHECK_WARNING", warnings: expect.arrayContaining([expect.stringMatching(/license/)]) },
    });
    expect(driverModel.approveDriver).not.toHaveBeenCalled();
  });

  it("is refused while the check hasn't run yet", async () => {
    driverApplicationModel.findById.mockResolvedValue(application({ documents_checked_at: null }));

    await expect(adminService.approveDriver(11, 1)).rejects.toMatchObject({ statusCode: 409 });
  });

  it("goes through once acknowledged", async () => {
    driverApplicationModel.findById.mockResolvedValue(application({ permit_check_status: "suspicious" }));

    await adminService
      .approveDriver(11, 1, { acknowledgeDocumentWarnings: true })
      .catch(() => {}); // later steps (notifications/emails) aren't under test here
    expect(driverModel.approveDriver).toHaveBeenCalled();
  });

  it("needs no acknowledgement when both documents were verified", async () => {
    driverApplicationModel.findById.mockResolvedValue(application());

    await adminService.approveDriver(11, 1).catch(() => {});
    expect(driverModel.approveDriver).toHaveBeenCalled();
  });
});

describe("revoking a driver's approval", () => {
  it("refuses while the driver is on a ride", async () => {
    driverModel.findById.mockResolvedValue({ id: 5, user_id: 27, approval_status: "approved" });
    const db = require("../src/config/db");
    db.withTransaction.mockImplementationOnce(async (work) =>
      work({ query: jest.fn(async (sql) => (/FROM bookings/.test(sql) ? [{ id: 12 }] : [])) })
    );

    await expect(adminService.revokeDriverApproval(5, 1, "wrong documents")).rejects.toMatchObject({
      statusCode: 409,
    });
  });

  it("refuses for a driver who isn't approved", async () => {
    driverModel.findById.mockResolvedValue({ id: 5, user_id: 27, approval_status: "pending" });

    await expect(adminService.revokeDriverApproval(5, 1)).rejects.toMatchObject({ statusCode: 400 });
  });
});
