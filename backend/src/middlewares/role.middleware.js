const ApiError = require("../utils/api-error");

function requireRole(...allowedRoles) {
  return (req, _res, next) => {
    if (!req.user) {
      return next(new ApiError(401, "Unauthorized"));
    }

    if (!allowedRoles.includes(req.user.role)) {
      return next(new ApiError(403, "Forbidden for this role."));
    }

    return next();
  };
}

module.exports = requireRole;

