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
  }),
});

module.exports = {
  requestPasswordChangeSchema,
  confirmPasswordChangeSchema,
};
