const jwt = require("jsonwebtoken");
const env = require("../config/env");
const ApiError = require("../utils/api-error");
const userModel = require("../models/user.model");

async function authMiddleware(req, _res, next) {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7)
      : null;

    if (!token) {
      throw new ApiError(401, "Authorization token is required.");
    }

    const payload = jwt.verify(token, env.jwt.secret);
    if (payload.type && payload.type !== "access") {
      throw new ApiError(401, "Invalid token type.");
    }

    const user = await userModel.findById(payload.userId);

    if (!user) {
      throw new ApiError(401, "Invalid token user.");
    }

    if (user.status === "suspended" || user.status === "rejected") {
      throw new ApiError(403, "Account is not active.");
    }

    req.user = {
      id: user.id,
      role: user.role,
      status: user.status,
      fullName: user.full_name,
      phone: user.phone,
      email: user.email,
      isDriverAccount: Boolean(user.is_driver_account),
      driverApprovalStatus: user.driver_approval_status || "none",
    };

    next();
  } catch (error) {
    if (error.name === "JsonWebTokenError" || error.name === "TokenExpiredError") {
      return next(new ApiError(401, "Invalid or expired token."));
    }
    return next(error);
  }
}

module.exports = authMiddleware;
