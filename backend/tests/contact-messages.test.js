require("./setup-env");

jest.mock("../src/config/db", () => ({ query: jest.fn(async () => []), withTransaction: jest.fn() }));
jest.mock("../src/models/contact-message.model");
jest.mock("../src/models/admin-account.model");
jest.mock("../src/models/user.model");
jest.mock("../src/services/mail.service");
jest.mock("../src/services/notification.service");

const jwt = require("jsonwebtoken");
const request = require("supertest");
const env = require("../src/config/env");
const contactModel = require("../src/models/contact-message.model");
const adminAccountModel = require("../src/models/admin-account.model");
const userModel = require("../src/models/user.model");
const mailService = require("../src/services/mail.service");
const notificationService = require("../src/services/notification.service");
const app = require("../src/app");

const message = {
  id: 9,
  name: "Juan dela Cruz",
  email: "juan@gmail.com",
  subject: "Fare question",
  message: "How much is a ride to Sulangan?",
  status: "open",
  created_at: "2026-10-09T08:00:00Z",
  updated_at: "2026-10-09T08:00:00Z",
};

const adminToken = (userId = 1) => jwt.sign({ userId, role: "admin", type: "access" }, env.jwt.secret, { expiresIn: "5m" });

function signInAs(adminRole) {
  userModel.findById.mockResolvedValue({ id: 1, role: "admin", status: "active", full_name: "Ana Admin" });
  adminAccountModel.findByUserId.mockResolvedValue({
    user_id: 1,
    admin_role: adminRole,
    status: "active",
    created_at: new Date("2026-01-01T00:00:00Z"),
  });
}

beforeEach(() => {
  jest.clearAllMocks();
  notificationService.createNotification.mockResolvedValue({});
  contactModel.findById.mockResolvedValue(message);
  contactModel.listReplies.mockResolvedValue([]);
  contactModel.setStatus.mockResolvedValue(message);
});

describe("POST /api/contact (website Contact page)", () => {
  it("keeps the message and tells the admins", async () => {
    contactModel.createMessage.mockResolvedValue(message);

    const res = await request(app).post("/api/contact").send({
      name: " Juan dela Cruz ",
      email: "Juan@Gmail.com",
      subject: "Fare question",
      message: "How much is a ride to Sulangan?",
    });

    expect(res.statusCode).toBe(201);
    expect(contactModel.createMessage).toHaveBeenCalledWith(
      expect.objectContaining({ name: "Juan dela Cruz", email: "juan@gmail.com", subject: "Fare question" })
    );
    expect(notificationService.createNotification).toHaveBeenCalledWith(
      expect.objectContaining({ type: "contact_message", recipientRole: "admin", metadataJson: { contactMessageId: 9 } })
    );
  });

  it("rejects a bad email or an empty message", async () => {
    const bad = await request(app).post("/api/contact").send({ name: "Juan", email: "not-an-email", message: "Hi" });
    expect(bad.statusCode).toBe(400);
    const empty = await request(app).post("/api/contact").send({ name: "Juan", email: "juan@gmail.com", message: "   " });
    expect(empty.statusCode).toBe(400);
    expect(contactModel.createMessage).not.toHaveBeenCalled();
  });

  it("quietly drops messages from bots that fill the hidden field", async () => {
    const res = await request(app)
      .post("/api/contact")
      .send({ name: "Bot", email: "bot@spam.com", message: "Buy now", hpTrap: "http://spam" });
    expect(res.statusCode).toBe(201);
    expect(contactModel.createMessage).not.toHaveBeenCalled();
  });
});

describe("replying from Contact Support", () => {
  it("emails the reply to the sender, then records it", async () => {
    signInAs("operations_admin");
    mailService.sendContactReplyEmail.mockResolvedValue(true);

    const res = await request(app)
      .post("/api/admin/contact-messages/9/reply")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ message: "  It's about ₱40.\nSee you!  " });

    expect(res.statusCode).toBe(200);
    expect(mailService.sendContactReplyEmail).toHaveBeenCalledWith({
      to: "juan@gmail.com",
      name: "Juan dela Cruz",
      subject: "Fare question",
      originalMessage: "How much is a ride to Sulangan?",
      reply: "It's about ₱40.\nSee you!",
    });
    expect(contactModel.addReply).toHaveBeenCalledWith({
      messageId: 9,
      adminId: 1,
      adminName: "Ana Admin",
      body: "It's about ₱40.\nSee you!",
    });
    expect(contactModel.setStatus).toHaveBeenCalledWith(9, "replied");
  });

  it("keeps nothing when the email couldn't be sent", async () => {
    signInAs("operations_admin");
    mailService.sendContactReplyEmail.mockResolvedValue(false);

    const res = await request(app)
      .post("/api/admin/contact-messages/9/reply")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ message: "Hello" });

    expect(res.statusCode).toBe(502);
    expect(contactModel.addReply).not.toHaveBeenCalled();
    expect(contactModel.setStatus).not.toHaveBeenCalled();
  });

  it("is off limits to SOS Responders", async () => {
    signInAs("sos_responder");
    const list = await request(app).get("/api/admin/contact-messages").set("Authorization", `Bearer ${adminToken()}`);
    expect(list.statusCode).toBe(403);
    const reply = await request(app)
      .post("/api/admin/contact-messages/9/reply")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ message: "Hello" });
    expect(reply.statusCode).toBe(403);
    expect(mailService.sendContactReplyEmail).not.toHaveBeenCalled();
  });

  it("lists messages with their replies", async () => {
    signInAs("super_admin");
    contactModel.listForAdmin.mockResolvedValue([{ ...message, status: "replied" }]);
    contactModel.listReplies.mockResolvedValue([
      { id: 1, message_id: 9, body: "It's about ₱40.", admin_name: "Ana Admin", created_at: "2026-10-09T09:00:00Z" },
    ]);

    const res = await request(app).get("/api/admin/contact-messages").set("Authorization", `Bearer ${adminToken()}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.data[0]).toMatchObject({
      id: 9,
      email: "juan@gmail.com",
      status: "replied",
      replies: [{ body: "It's about ₱40.", adminName: "Ana Admin" }],
    });
  });
});
