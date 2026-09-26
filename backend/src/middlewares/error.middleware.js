function errorMiddleware(error, _req, res, _next) {
  const statusCode = error.statusCode || 500;
  const payload = {
    success: false,
    message: error.message || "Internal server error",
  };

  if (error.details) {
    payload.details = error.details;
  }

  res.status(statusCode).json(payload);
}

module.exports = errorMiddleware;

