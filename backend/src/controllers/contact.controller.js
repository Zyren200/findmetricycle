const contactService = require("../services/contact.service");

async function submitMessage(req, res, next) {
  try {
    const { name, email, subject, message, hpTrap } = req.body;
    // A bot filled in the hidden field: answer as usual, keep nothing (but
    // say so in the server log, so a dropped message can be traced).
    if (hpTrap) {
      console.warn(`Contact form: dropped a message from ${email} (hidden anti-bot field was filled in).`);
    } else {
      await contactService.submitMessage({ name, email, subject, message, ipAddress: req.ip });
    }
    res.status(201).json({
      success: true,
      message: "Message sent. We'll reply to your email.",
    });
  } catch (error) {
    next(error);
  }
}

async function listMessages(_req, res, next) {
  try {
    res.json({ success: true, data: await contactService.listForAdmin() });
  } catch (error) {
    next(error);
  }
}

async function replyToMessage(req, res, next) {
  try {
    const data = await contactService.replyForAdmin(req.params.id, req.user, req.body.message);
    res.json({ success: true, message: "Reply sent.", data });
  } catch (error) {
    next(error);
  }
}

async function setMessageStatus(req, res, next) {
  try {
    const data = await contactService.setStatusForAdmin(req.params.id, req.body.status);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  submitMessage,
  listMessages,
  replyToMessage,
  setMessageStatus,
};
