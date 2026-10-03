const { z, phoneSchema } = require("./common");

const registerPassengerSchema = z.object({
  body: z.object({
    fullName: z.string().trim().min(2).max(120),
    phone: phoneSchema,
    email: z.string().trim().email().max(120),
    password: z.string().min(8).max(100),
  }),
});

const loginSchema = z.object({
  body: z.object({
    email: z.string().trim().email().max(120).optional().or(z.literal("")),
    phone: phoneSchema.optional(),
    password: z.string().min(1).max(100),
  }),
});

const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(20),
  }),
});

const logoutSchema = refreshSchema;

const registerAdminSchema = z.object({
  body: z.object({
    fullName: z.string().trim().min(2).max(120),
    phone: phoneSchema,
    email: z.string().trim().email().max(120),
    password: z.string().min(8).max(100),
  }),
});

const adminSendOtpSchema = z.object({
  body: z.object({
    email: z.string().trim().email().max(120),
  }),
});

const adminVerifyOtpSchema = z.object({
  body: z.object({
    email: z.string().trim().email().max(120),
    code: z.string().trim().regex(/^\d{6}$/, "Code must be 6 digits"),
  }),
});

// Each admin resets their own password through their own email.
const adminForgotPasswordRequestSchema = z.object({
  body: z.object({
    email: z.string().trim().email().max(120),
  }),
});

const adminForgotPasswordVerifySchema = z.object({
  body: z.object({
    email: z.string().trim().email().max(120),
    code: z.string().trim().regex(/^\d{6}$/, "Code must be 6 digits"),
  }),
});

const adminForgotPasswordResetSchema = z.object({
  body: z.object({
    email: z.string().trim().email().max(120),
    code: z.string().trim().regex(/^\d{6}$/, "Code must be 6 digits"),
    newPassword: z.string().min(8).max(100),
  }),
});

module.exports = {
  registerPassengerSchema,
  loginSchema,
  refreshSchema,
  logoutSchema,
  registerAdminSchema,
  adminSendOtpSchema,
  adminVerifyOtpSchema,
  adminForgotPasswordRequestSchema,
  adminForgotPasswordVerifySchema,
  adminForgotPasswordResetSchema,
};
