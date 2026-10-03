require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(), withTransaction: jest.fn() }));
jest.mock("../src/models/complaint.model");

const complaintModel = require("../src/models/complaint.model");
const adminService = require("../src/services/admin.service");

const openReport = {
  id: 7,
  status: "open",
  reporter_name: "Renz",
  reporter_phone: "09170000000",
  reported_user_name: null,
  booking_id: 14,
  category: "no_show",
  description: "Passenger never came.",
  created_at: "2026-10-01T10:00:00Z",
};

beforeEach(() => jest.clearAllMocks());

describe("resolving a report", () => {
  it("can be dismissed with a note, and the note comes back", async () => {
    complaintModel.findById.mockResolvedValue(openReport);
    complaintModel.resolveComplaint.mockResolvedValue({
      ...openReport,
      status: "dismissed",
      resolution_note: "Duplicate of #6",
      resolved_by_name: "admin",
      resolved_at: "2026-10-03T08:00:00Z",
    });

    const report = await adminService.resolveComplaint(7, 1, { status: "dismissed", note: "  Duplicate of #6 " });

    expect(complaintModel.resolveComplaint).toHaveBeenCalledWith(7, 1, {
      status: "dismissed",
      resolutionNote: "Duplicate of #6",
    });
    expect(report).toMatchObject({
      status: "dismissed",
      resolutionNote: "Duplicate of #6",
      resolvedByName: "admin",
      reporterPhone: "09170000000",
      reportedUser: null,
      rideId: 14,
    });
  });

  it("won't close a report twice", async () => {
    complaintModel.findById.mockResolvedValue({ ...openReport, status: "resolved" });
    await expect(adminService.resolveComplaint(7, 1)).rejects.toMatchObject({ statusCode: 409 });
    expect(complaintModel.resolveComplaint).not.toHaveBeenCalled();
  });
});
