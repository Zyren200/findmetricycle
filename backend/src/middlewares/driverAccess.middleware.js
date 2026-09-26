const ApiError = require("../utils/api-error");
const { hasDriverAccess } = require("../utils/driver-access");

// Gate for /driver/* routes. Distinct from requireRole(roles.DRIVER) because
// an approved dual-role (passenger + driver) account never gets
// role = 'driver' — see utils/driver-access.js.
function requireDriverAccess(req, _res, next) {
  if (!req.user) {
    return next(new ApiError(401, "Unauthorized"));
  }

  if (!hasDriverAccess(req.user)) {
    return next(new ApiError(403, "Driver access required."));
  }

  return next();
}

module.exports = requireDriverAccess;
