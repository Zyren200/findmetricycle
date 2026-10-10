require("./setup-env");

// Scripted fake of config/db (same shape as auth-otp.test.js).
jest.mock("../src/config/db", () => {
  const calls = [];
  const handlers = [];
  const query = jest.fn(async (sql, params = []) => {
    calls.push({ sql, params });
    const handler = handlers.find((h) => h.pattern.test(sql));
    return handler ? handler.respond(sql, params) : { affectedRows: 1, insertId: 1 };
  });
  return {
    query,
    withTransaction: jest.fn(async (work) => work({ query })),
    __calls: calls,
    __handlers: handlers,
  };
});
jest.mock("../src/services/notification.service", () => ({
  createNotification: jest.fn(async () => {}),
}));
jest.mock("../src/models/application-status-history.model", () => ({
  logStatus: jest.fn(async () => {}),
  listForApplication: jest.fn(async () => []),
}));

const db = require("../src/config/db");
const authV2Service = require("../src/services/auth.v2.service");

function on(pattern, respond) {
  db.__handlers.push({ pattern, respond });
}

// A readable LTO license that belongs to the applicant.
const LICENSE_TEXT = `REPUBLIC OF THE PHILIPPINES DEPARTMENT OF TRANSPORTATION
LAND TRANSPORTATION OFFICE DRIVER'S LICENSE
DELA CRUZ, JUAN SANTOS  LICENSE NO. A12-34-567890  NON-PROFESSIONAL`;

const previous = {
  plate_number: "ABC 1234",
  franchise_number: "FR-001",
  license_type: "Non-Professional",
  address: "Old address",
  emergency_contact_name: "Maria Dela Cruz",
  emergency_contact_phone: "09170000000",
};

function insertedValues() {
  const insert = db.__calls.find((c) => /INSERT INTO driver_applications/.test(c.sql));
  const [, , , , address, emergencyName, emergencyPhone, plate, franchise, , , , , licenseType] = insert.params;
  return { address, emergencyName, emergencyPhone, plate, franchise, licenseType };
}

beforeEach(() => {
  db.__calls.length = 0;
  db.__handlers.length = 0;
  jest.clearAllMocks();
  on(/SELECT \* FROM users WHERE id/, () => [
    { id: 27, role: "passenger", email: "juan@example.com", full_name: "Juan Dela Cruz", phone: "09171234567" },
  ]);
  on(/FROM otp_codes/, () => [{ is_verified: 1, verified_at: new Date() }]);
  on(/SELECT plate_number, franchise_number/, () => [previous]);
  on(/INSERT INTO driver_applications/, () => ({ insertId: 41 }));
});

describe("resubmitting a driver application", () => {
  it("keeps the applicant's corrected details", async () => {
    const result = await authV2Service.resubmitDriverApplication(
      27,
      "/uploads/driver-docs/license.jpg",
      "/uploads/driver-docs/permit.jpg",
      LICENSE_TEXT,
      null,
      null,
      {},
      {
        address: "New address, Brgy. Ward 2",
        emergencyContactName: "Pedro Dela Cruz",
        emergencyContactPhone: "09181111111",
        franchiseNumber: "FR-999",
        licenseType: "Professional",
      }
    );

    expect(result.applicationId).toBe(41);
    expect(insertedValues()).toEqual({
      address: "New address, Brgy. Ward 2",
      emergencyName: "Pedro Dela Cruz",
      emergencyPhone: "09181111111",
      plate: "ABC 1234", // the plate always carries over
      franchise: "FR-999",
      licenseType: "Professional",
    });
  });

  it("carries over whatever the applicant didn't send", async () => {
    await authV2Service.resubmitDriverApplication(
      27,
      "/uploads/driver-docs/license.jpg",
      "/uploads/driver-docs/permit.jpg",
      LICENSE_TEXT,
      null,
      null,
      {},
      { address: "New address" }
    );

    expect(insertedValues()).toEqual({
      address: "New address",
      emergencyName: "Maria Dela Cruz",
      emergencyPhone: "09170000000",
      plate: "ABC 1234",
      franchise: "FR-001",
      licenseType: "Non-Professional",
    });
  });
});
