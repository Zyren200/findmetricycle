require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(async () => []), withTransaction: jest.fn() }));
jest.mock("../src/models/booking.model");
jest.mock("../src/services/notification.service");

const mockEmit = jest.fn();
const mockTo = jest.fn(() => ({ emit: mockEmit }));
jest.mock("../src/sockets", () => ({ getIO: () => ({ to: mockTo }) }));

const db = require("../src/config/db");
const bookingModel = require("../src/models/booking.model");
const notificationService = require("../src/services/notification.service");
const sosModel = require("../src/models/sos.model");
const sosService = require("../src/services/sos.service");
const adminSchema = require("../src/validations/admin.schema");
const { SOS_ESCALATION_AFTER_MS } = require("../src/constants/sos");

const sam = { userId: 4, name: "Sam Sos" };

function alertRow(extra = {}) {
  return {
    id: 7,
    status: "active",
    booking_id: 12,
    passenger_id: 5,
    passenger_name: "Pia Passenger",
    passenger_phone: "0917",
    driver_id: 3,
    driver_name: "Dan Driver",
    driver_phone: "0918",
    triggered_by_user_id: 5,
    triggered_by_role: "passenger",
    lat: null,
    lng: null,
    created_at: new Date(),
    ...extra,
  };
}

const emitted = (event) => mockEmit.mock.calls.filter(([e]) => e === event).map(([, payload]) => payload);

beforeEach(() => {
  jest.clearAllMocks();
  notificationService.createNotification.mockResolvedValue({});
});

describe("acknowledging is first-come, first-served", () => {
  it("only changes an alert that is still open (atomic on the database)", async () => {
    db.query.mockResolvedValueOnce({ affectedRows: 1 });
    await expect(sosModel.acknowledge(7, 4)).resolves.toBe(true);
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/SET status = 'acknowledged', acknowledged_by = \?, acknowledged_at = NOW\(\)/);
    expect(sql).toMatch(/WHERE id = \? AND status = 'active'/);
    expect(params).toEqual([4, 7]);

    db.query.mockResolvedValueOnce({ affectedRows: 0 });
    await expect(sosModel.acknowledge(7, 9)).resolves.toBe(false);
  });

  it("tells every SOS admin who has it, and the sender that help is coming", async () => {
    jest.spyOn(sosModel, "acknowledge").mockResolvedValue(true);
    jest.spyOn(sosModel, "findById").mockResolvedValue(
      alertRow({ status: "acknowledged", acknowledged_by: 4, acknowledged_by_name: "Sam Sos", acknowledged_at: new Date() })
    );

    const payload = await sosService.acknowledgeForAdmin(7, sam);

    expect(payload).toMatchObject({ status: "acknowledged", acknowledgedBy: { id: 4, name: "Sam Sos" } });
    expect(mockTo).toHaveBeenCalledWith("perm:sos.view");
    expect(emitted("admin:sos_updated")[0].acknowledgedBy.name).toBe("Sam Sos");
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 5, recipientRole: "passenger", type: "sos_acknowledged" })
    );
  });

  it("a second admin is refused and told who is handling it", async () => {
    jest.spyOn(sosModel, "acknowledge").mockResolvedValue(false);
    jest.spyOn(sosModel, "findById").mockResolvedValue(
      alertRow({ status: "acknowledged", acknowledged_by: 4, acknowledged_by_name: "Sam Sos" })
    );
    await expect(sosService.acknowledgeForAdmin(7, { userId: 9, name: "Other" })).rejects.toMatchObject({
      statusCode: 409,
      message: "Sam Sos is already handling this alert.",
    });
    expect(emitted("admin:sos_updated")).toHaveLength(0);
    expect(notificationService.createNotification).not.toHaveBeenCalled();
  });

  it("tells the driver, not the passenger, when the driver sent it", async () => {
    jest.spyOn(sosModel, "acknowledge").mockResolvedValue(true);
    jest.spyOn(sosModel, "findById").mockResolvedValue(
      alertRow({ status: "acknowledged", triggered_by_user_id: 30, triggered_by_role: "driver" })
    );
    await sosService.acknowledgeForAdmin(7, sam);
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 30, recipientRole: "driver" })
    );
  });

  it("older alerts without a recorded sender are acknowledged without a message", async () => {
    jest.spyOn(sosModel, "acknowledge").mockResolvedValue(true);
    jest.spyOn(sosModel, "findById").mockResolvedValue(
      alertRow({ status: "acknowledged", triggered_by_user_id: null, triggered_by_role: null })
    );
    await sosService.acknowledgeForAdmin(7, sam);
    expect(notificationService.createNotification).not.toHaveBeenCalled();
  });
});

describe("resolving", () => {
  it("needs an acknowledged alert and saves the note", async () => {
    db.query.mockResolvedValueOnce({ affectedRows: 1 });
    await sosModel.resolve(7, 4, "Called the passenger; police informed.");
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/resolution_note = \?/);
    expect(sql).toMatch(/WHERE id = \? AND status = 'acknowledged'/);
    expect(params).toEqual([4, "Called the passenger; police informed.", 7]);
  });

  it("an open alert must be acknowledged first", async () => {
    jest.spyOn(sosModel, "resolve").mockResolvedValue(false);
    jest.spyOn(sosModel, "findById").mockResolvedValue(alertRow({ status: "active" }));
    await expect(sosService.resolveForAdmin(7, sam, "done")).rejects.toMatchObject({
      statusCode: 409,
      message: "Acknowledge the alert before resolving it.",
    });
  });

  it("can't resolve twice", async () => {
    jest.spyOn(sosModel, "resolve").mockResolvedValue(false);
    jest.spyOn(sosModel, "findById").mockResolvedValue(alertRow({ status: "resolved" }));
    await expect(sosService.resolveForAdmin(7, sam, "done")).rejects.toMatchObject({ statusCode: 409 });
  });

  it("requires a note", () => {
    const parse = (body) => adminSchema.sosResolveSchema.safeParse({ params: { id: "7" }, body }).success;
    expect(parse({})).toBe(false);
    expect(parse({ note: "  " })).toBe(false);
    expect(parse({ note: "Passenger safe, picked up by family." })).toBe(true);
  });
});

describe("escalation", () => {
  it("defaults to 2 minutes", () => {
    expect(SOS_ESCALATION_AFTER_MS).toBe(2 * 60 * 1000);
  });

  it("alerts the Super Admins once per open alert, even if two checks overlap", async () => {
    jest.spyOn(sosModel, "listDueForEscalation").mockResolvedValue([{ id: 7 }, { id: 8 }]);
    // #8 was acknowledged (or escalated elsewhere) in the meantime.
    jest.spyOn(sosModel, "claimEscalation").mockImplementation(async (id) => id === 7);
    jest.spyOn(sosModel, "findById").mockResolvedValue(alertRow({ escalated_at: new Date() }));

    const escalated = await sosService.escalateOverdueAlerts();

    expect(sosModel.listDueForEscalation).toHaveBeenCalledWith(120);
    expect(escalated.map((a) => a.id)).toEqual([7]);
    expect(notificationService.createNotification).toHaveBeenCalledTimes(1);
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ type: "sos_escalation", recipientRole: "admin" })
    );
    expect(mockTo).toHaveBeenCalledWith("perm:sos.escalations");
    expect(emitted("admin:sos_escalation")).toHaveLength(1);
  });

  it("only picks alerts still open and not yet escalated", async () => {
    sosModel.listDueForEscalation.mockRestore(); // spied on in the test above
    db.query.mockResolvedValueOnce([]);
    await sosModel.listDueForEscalation(120);
    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/status = 'active' AND escalated_at IS NULL/);
    expect(sql).toMatch(/created_at <= NOW\(\) - INTERVAL \? SECOND/);
    expect(params).toEqual([120]);
  });
});

describe("sending an SOS records who sent it", () => {
  it("a driver's SOS names the driver and remembers them as the sender", async () => {
    bookingModel.findById.mockResolvedValue({ id: 12, driver_id: 3, driver_user_id: 30, passenger_id: 5 });
    const create = jest.spyOn(sosModel, "createAlert").mockResolvedValue(
      alertRow({ triggered_by_user_id: 30, triggered_by_role: "driver" })
    );
    const payload = await sosService.createDriverSosAlert({ driverId: 3, bookingId: 12 });
    expect(create).toHaveBeenCalledWith(expect.objectContaining({ triggeredByUserId: 30, triggeredByRole: "driver" }));
    expect(payload.body).toBe("Emergency alert from Dan Driver (Booking #12).");
    expect(payload.contact).toBe("0918");
  });

  it("a passenger's SOS is unchanged for them and remembers the passenger", async () => {
    const create = jest.spyOn(sosModel, "createAlert").mockResolvedValue(alertRow({ booking_id: null }));
    const payload = await sosService.createSosAlert({ passengerId: 5 });
    expect(create).toHaveBeenCalledWith(expect.objectContaining({ triggeredByUserId: 5, triggeredByRole: "passenger" }));
    expect(payload.body).toBe("Emergency alert from Pia Passenger.");
    expect(emitted("admin:sos_alert")).toHaveLength(1);
  });
});
