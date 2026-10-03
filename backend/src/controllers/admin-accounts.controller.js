const adminAccountsService = require("../services/admin-accounts.service");

// The admin performing the action, for the safety rules and Activity Logs.
function actorOf(req) {
  return { userId: req.user.id, name: req.user.fullName };
}

async function list(req, res, next) {
  try {
    const data = await adminAccountsService.listAdmins(actorOf(req));
    res.json({ success: true, data, meta: { roles: adminAccountsService.roleCatalog() } });
  } catch (error) {
    next(error);
  }
}

async function create(req, res, next) {
  try {
    const { admin, welcomeEmailSent } = await adminAccountsService.createAdmin(actorOf(req), req.body);
    res.status(201).json({
      success: true,
      message: welcomeEmailSent
        ? `Admin added. A welcome email was sent to ${admin.email}.`
        : `Admin added, but the welcome email couldn't be sent. Use "Send password reset" to try again.`,
      data: admin,
      meta: { welcomeEmailSent },
    });
  } catch (error) {
    next(error);
  }
}

async function changeRole(req, res, next) {
  try {
    const data = await adminAccountsService.changeRole(actorOf(req), req.params.userId, req.body.role);
    res.json({ success: true, message: "Role updated.", data });
  } catch (error) {
    next(error);
  }
}

async function disable(req, res, next) {
  try {
    const data = await adminAccountsService.setStatus(actorOf(req), req.params.userId, "disabled");
    res.json({ success: true, message: "Admin disabled.", data });
  } catch (error) {
    next(error);
  }
}

async function enable(req, res, next) {
  try {
    const data = await adminAccountsService.setStatus(actorOf(req), req.params.userId, "active");
    res.json({ success: true, message: "Admin enabled.", data });
  } catch (error) {
    next(error);
  }
}

async function sendPasswordReset(req, res, next) {
  try {
    const data = await adminAccountsService.sendPasswordReset(actorOf(req), req.params.userId);
    res.json({ success: true, message: `Password reset email sent to ${data.email}.`, data });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  list,
  create,
  changeRole,
  disable,
  enable,
  sendPasswordReset,
};
