const jwt = require("jsonwebtoken");
const env = require("../config/env");
const ApiError = require("../utils/api-error");
const userModel = require("../models/user.model");

// Same as auth.middleware.js, except the token may also arrive as a
// ?token= query param — a plain <a href> (document links in the admin
// dashboard) can't set an Authorization header.
async function documentAuthMiddleware(req, _res, next) {
  try {
    const authHeader = req.headers.authorization || "";
    const headerToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
    const token = headerToken || req.query.token;

    if (!token) {
      throw new ApiError(401, "Authorization token is required.");
    }

    const payload = jwt.verify(token, env.jwt.secret);
    if (payload.type !== "access") {
      throw new ApiError(401, "Invalid token type.");
    }

    const user = await userModel.findById(payload.userId);
    if (!user) {
      throw new ApiError(401, "Invalid token user.");
    }

    if (user.status === "suspended" || user.status === "rejected") {
      throw new ApiError(403, "Account is not active.");
    }

    req.user = { id: user.id, role: user.role, status: user.status };
    next();
  } catch (error) {
    if (error.name === "JsonWebTokenError" || error.name === "TokenExpiredError") {
      return next(new ApiError(401, "Invalid or expired token."));
    }
    return next(error);
  }
}

module.exports = documentAuthMiddleware;
