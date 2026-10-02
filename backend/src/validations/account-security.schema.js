const { z } = require("./common");

const requestPasswordChangeSchema = z.object({
  body: z.object({
    currentPassword: z.string().min(1),
  }),
});

const confirmPasswordChangeSchema = z.object({
  body: z.object({
    currentPassword: z.string().min(1),
    newPassword: z.string().min(8).max(100),
    otp: z.string().trim().regex(/^\d{6}$/, "otp must be a 6-digit code"),
    // This device's refresh token, so it stays signed in when the others
    // are signed out.
    keepRefreshToken: z.string().min(20).max(1000).optional(),
  }),
});

module.exports = {
  requestPasswordChangeSchema,
  confirmPasswordChangeSchema,
};
