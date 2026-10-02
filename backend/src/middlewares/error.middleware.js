function errorMiddleware(error, req, res, _next) {
  // A unique-key clash no service check caught (e.g. two identical requests
  // racing) is the client's conflict, not a server fault.
  if (!error.statusCode && error.code === "ER_DUP_ENTRY") {
    error.statusCode = 409;
    error.message = "That already exists.";
  }
  const statusCode = error.statusCode || error.status || 500;

  // Unexpected errors (SQL errors, bugs) are logged server-side and never
  // echoed to the client — their messages can expose schema and internals.
  if (statusCode >= 500) {
    console.error(`[${req.method} ${req.originalUrl}]`, error);
  }

  const payload = {
    success: false,
    message: statusCode >= 500 ? "Internal server error" : error.message || "Request failed",
  };

  if (error.details) {
    payload.details = error.details;
  }

  res.status(statusCode).json(payload);
}

module.exports = errorMiddleware;
