const contactModel = require("../models/contact-message.model");
const mailService = require("./mail.service");
const notificationService = require("./notification.service");
const ApiError = require("../utils/api-error");

function toView(row, replies = []) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    subject: row.subject || null,
    message: row.message,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    replies: replies.map((r) => ({
      id: r.id,
      body: r.body,
      adminName: r.admin_name || "Admin",
      createdAt: r.created_at,
    })),
  };
}

// A message from the website's Contact page. It waits in the admin's
// Contact Support inbox; the admins are told it arrived.
async function submitMessage({ name, email, subject, message, ipAddress }) {
  const row = await contactModel.createMessage({
    name,
    email,
    subject: subject || null,
    message,
    ipAddress: ipAddress ? String(ipAddress).slice(0, 45) : null,
  });

  await notificationService
    .createNotification({
      type: "contact_message",
      title: "New contact message",
      body: `${name}: ${subject ? `${subject} — ` : ""}${message.slice(0, 120)}`,
      recipientRole: "admin",
      metadataJson: { contactMessageId: row.id },
    })
    .catch(() => {});

  return { id: row.id };
}

async function listForAdmin() {
  const rows = await contactModel.listForAdmin();
  const replies = await contactModel.listReplies(rows.map((r) => r.id));
  return rows.map((row) => toView(row, replies.filter((r) => Number(r.message_id) === Number(row.id))));
}

async function getForAdmin(id) {
  const row = await contactModel.findById(id);
  if (!row) throw new ApiError(404, "Message not found.");
  return toView(row, await contactModel.listReplies([row.id]));
}

// Emails the admin's reply to the address the person wrote from. The reply
// is only kept once the email went out, so a failed send can simply be
// tried again.
async function replyForAdmin(id, admin, body) {
  const row = await contactModel.findById(id);
  if (!row) throw new ApiError(404, "Message not found.");

  const sent = await mailService.sendContactReplyEmail({
    to: row.email,
    name: row.name,
    subject: row.subject,
    originalMessage: row.message,
    reply: body,
  });
  if (!sent) {
    throw new ApiError(502, `Couldn't send the email to ${row.email}. Please try again.`);
  }

  await contactModel.addReply({
    messageId: row.id,
    adminId: admin.id,
    adminName: admin.fullName ? String(admin.fullName).slice(0, 120) : null,
    body,
  });
  await contactModel.setStatus(row.id, "replied");
  return getForAdmin(row.id);
}

// Close a conversation that needs nothing more, or reopen it.
async function setStatusForAdmin(id, status) {
  const row = await contactModel.findById(id);
  if (!row) throw new ApiError(404, "Message not found.");
  await contactModel.setStatus(row.id, status);
  return getForAdmin(row.id);
}

module.exports = {
  submitMessage,
  listForAdmin,
  getForAdmin,
  replyForAdmin,
  setStatusForAdmin,
};
