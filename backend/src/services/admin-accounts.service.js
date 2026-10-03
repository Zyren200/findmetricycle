// Admin Accounts (Super Admin only): add admins, change roles, disable or
// enable them, and send a password reset. The safety rules live here, not
// in the dashboard: nobody can change their own role or disable
// themselves, and the last active Super Admin can't be demoted or disabled.
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const db = require("../config/db");
const roles = require("../constants/roles");
const ApiError = require("../utils/api-error");
const userModel = require("../models/user.model");
const adminAccountModel = require("../models/admin-account.model");
const mailService = require("./mail.service");
const { signOutEverywhere } = require("./admin-access.service");
const { takeEmailBudget } = require("../middlewares/rate-limit.middleware");
const { ADMIN_ROLES, ROLE_LABELS, isAdminRole, permissionsForRole } = require("../constants/admin-permissions");

function toAdminView(row, actorUserId) {
  return {
    id: Number(row.user_id),
    fullName: row.full_name,
    email: row.email,
    phone: row.phone,
    role: row.admin_role,
    roleLabel: ROLE_LABELS[row.admin_role] || row.admin_role,
    status: row.status,
    // False until they've set their own password (Forgot password).
    passwordSet: Boolean(row.password_set_at),
    lastLoginAt: row.last_login_at || null,
    createdAt: row.created_at,
    createdByName: row.created_by_name || null,
    isSelf: Number(row.user_id) === Number(actorUserId),
  };
}

/** The roles an admin can be given, for the role picker. */
function roleCatalog() {
  return Object.values(ADMIN_ROLES).map((role) => ({
    value: role,
    label: ROLE_LABELS[role],
    permissions: permissionsForRole(role),
  }));
}

function assertRole(role) {
  if (!isAdminRole(role)) {
    throw new ApiError(400, "Unknown admin role.", { field: "role" });
  }
}

// One entry per action with the target's name, on top of the generic
// request log adminAudit writes.
async function logAction(client, actor, action, target, metadata) {
  await client.query(
    `INSERT INTO activity_logs (admin_id, admin_name, action, target_type, target_id, metadata_json)
     VALUES (?, ?, ?, 'admin', ?, ?)`,
    [actor.userId, actor.name || null, action, target.userId, JSON.stringify({ name: target.name, ...metadata })]
  );
}

async function listAdmins(actor) {
  const rows = await adminAccountModel.listAll();
  return rows.map((row) => toAdminView(row, actor.userId));
}

async function createAdmin(actor, { fullName, email, phone, role }) {
  assertRole(role);
  const cleanEmail = String(email).trim();
  const cleanPhone = String(phone).trim();

  const created = await db.withTransaction(async (client) => {
    // Phone and email are unique across every account, so an address a
    // passenger already uses can't be reused for an admin.
    if (await userModel.findByEmail(cleanEmail, client)) {
      throw new ApiError(409, "This email is already used by another account.", { field: "email" });
    }
    if (await userModel.findByPhone(cleanPhone, client)) {
      throw new ApiError(409, "This phone number is already used by another account.", { field: "phone" });
    }

    // A random password nobody knows: the new admin sets their own through
    // Forgot password. The Super Admin never sees or sets it.
    const unusablePasswordHash = await bcrypt.hash(crypto.randomBytes(32).toString("hex"), 12);
    const user = await userModel.createUser(
      {
        fullName: fullName.trim(),
        phone: cleanPhone,
        email: cleanEmail,
        passwordHash: unusablePasswordHash,
        role: roles.ADMIN,
        status: "active",
      },
      client
    );
    await adminAccountModel.createProfile(user.id, { role, createdBy: actor.userId, passwordSet: false }, client);
    await logAction(client, actor, "Admin Account Created", { userId: user.id, name: user.full_name }, {
      email: cleanEmail,
      role,
    });
    return adminAccountModel.findByUserId(user.id, client);
  });

  // After the commit, so a mail failure never undoes the account; the
  // Super Admin can send it again with "Send password reset".
  takeEmailBudget(cleanEmail);
  const welcomeEmailSent = await mailService.sendAdminAccessEmail(cleanEmail, created.full_name, {
    kind: "welcome",
    roleLabel: ROLE_LABELS[role],
  });

  return { admin: toAdminView(created, actor.userId), welcomeEmailSent };
}

// Locks the active Super Admins and the target admin, and refuses changes
// that would leave no active Super Admin.
async function loadTargetForChange(client, actor, targetUserId, { selfMessage }) {
  if (Number(targetUserId) === Number(actor.userId)) {
    throw new ApiError(403, selfMessage);
  }
  const activeSuperAdmins = await adminAccountModel.lockActiveSuperAdmins(client);
  const target = await adminAccountModel.findByUserId(targetUserId, client, { forUpdate: true });
  if (!target) {
    throw new ApiError(404, "Admin account not found.");
  }
  const isLastSuperAdmin =
    target.admin_role === ADMIN_ROLES.SUPER_ADMIN &&
    target.status === "active" &&
    activeSuperAdmins.length <= 1;
  return { target, isLastSuperAdmin };
}

async function changeRole(actor, targetUserId, role) {
  assertRole(role);

  const result = await db.withTransaction(async (client) => {
    const { target, isLastSuperAdmin } = await loadTargetForChange(client, actor, targetUserId, {
      selfMessage: "You can't change your own role. Ask another Super Admin.",
    });
    if (target.admin_role === role) {
      return { target, changed: false };
    }
    if (isLastSuperAdmin) {
      throw new ApiError(409, "This is the last active Super Admin. Make someone else a Super Admin first.");
    }
    await adminAccountModel.updateRole(target.user_id, role, client);
    await logAction(client, actor, "Admin Role Changed", { userId: target.user_id, name: target.full_name }, {
      from: target.admin_role,
      to: role,
    });
    return { target: await adminAccountModel.findByUserId(target.user_id, client), changed: true };
  });

  if (result.changed) {
    await signOutEverywhere(result.target.user_id, { reason: "role_changed" });
  }
  return toAdminView(result.target, actor.userId);
}

async function setStatus(actor, targetUserId, status) {
  const disabling = status === "disabled";

  const result = await db.withTransaction(async (client) => {
    const { target, isLastSuperAdmin } = await loadTargetForChange(client, actor, targetUserId, {
      selfMessage: "You can't disable your own account.",
    });
    if (target.status === status) {
      return { target, changed: false };
    }
    if (disabling && isLastSuperAdmin) {
      throw new ApiError(409, "This is the last active Super Admin and can't be disabled.");
    }
    await adminAccountModel.updateStatus(target.user_id, status, client);
    await logAction(
      client,
      actor,
      disabling ? "Admin Disabled" : "Admin Enabled",
      { userId: target.user_id, name: target.full_name },
      { role: target.admin_role }
    );
    return { target: await adminAccountModel.findByUserId(target.user_id, client), changed: true };
  });

  if (result.changed && disabling) {
    await signOutEverywhere(result.target.user_id, { reason: "disabled" });
  }
  return toAdminView(result.target, actor.userId);
}

// Emails the admin how to set a new password (Forgot password on the sign
// in page). Also how a new admin gets their setup email again.
async function sendPasswordReset(actor, targetUserId) {
  const target = await adminAccountModel.findByUserId(targetUserId);
  if (!target) {
    throw new ApiError(404, "Admin account not found.");
  }
  if (target.status !== "active") {
    throw new ApiError(409, "This admin account is disabled. Enable it first.");
  }
  if (!takeEmailBudget(target.email)) {
    throw new ApiError(429, "Too many emails sent to this address. Please wait a few minutes and try again.");
  }

  const kind = target.password_set_at ? "reset" : "welcome";
  const sent = await mailService.sendAdminAccessEmail(target.email, target.full_name, {
    kind,
    roleLabel: ROLE_LABELS[target.admin_role],
  });
  if (!sent) {
    throw new ApiError(502, "The email couldn't be sent. Check the email settings and try again.");
  }

  await logAction(db, actor, "Admin Password Reset Sent", { userId: target.user_id, name: target.full_name }, {
    email: target.email,
  });
  return { sent: true, email: target.email };
}

module.exports = {
  roleCatalog,
  listAdmins,
  createAdmin,
  changeRole,
  setStatus,
  sendPasswordReset,
};
