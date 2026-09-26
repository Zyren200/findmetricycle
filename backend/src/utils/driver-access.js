// A user can act as a driver two ways: the legacy single-role account
// (users.role = 'driver', set at v1 registration) or the current dual-role
// account (role stays 'passenger' forever; users.is_driver_account +
// users.driver_approval_status track admin approval instead). Every place
// that used to check `role === 'driver'` needs to accept both.
function hasDriverAccess(user) {
  if (!user) return false;
  if (user.role === "driver") return true;
  return Boolean(user.isDriverAccount) && user.driverApprovalStatus === "approved";
}

module.exports = { hasDriverAccess };
