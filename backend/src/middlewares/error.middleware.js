function errorMiddleware(error, req, res, _next) {
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
