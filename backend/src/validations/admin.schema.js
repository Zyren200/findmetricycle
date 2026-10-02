const { z } = require("./common");

const driverParamSchema = z.object({
  params: z.object({
    driverId: z.coerce.number().int().positive(),
  }),
});

const rejectDriverSchema = z.object({
  params: z.object({
    driverId: z.coerce.number().int().positive(),
  }),
  body: z.object({
    reason: z.string().trim().min(3).max(255),
  }),
});

const requestCorrectionSchema = z.object({
  params: z.object({
    driverId: z.coerce.number().int().positive(),
  }),
  body: z.object({
    note: z.string().trim().min(3).max(255),
  }),
});

const fareUpdateSchema = z.object({
  body: z.object({
    baseFare: z.coerce.number().min(0).max(100000),
    perKmRate: z.coerce.number().min(0).max(100000),
    minimumFare: z.coerce.number().min(0).max(100000).optional(),
    nightFee: z.coerce.number().min(0).max(100000).optional(),
    additionalPassengerFee: z.coerce.number().min(0).max(100000).optional(),
  }),
});

const driverLicenseQuerySchema = z.object({
  query: z.object({
    days: z.coerce.number().int().positive().max(365).optional(),
  }),
});

// An announcement broadcast by an admin to passengers, drivers or both.
const announcementSchema = z.object({
  body: z.object({
    title: z.string().trim().min(1).max(150),
    body: z.string().trim().min(1).max(1000),
    audience: z.enum(["everyone", "passenger", "driver"]).default("everyone"),
  }),
});

const barangayUpdateSchema = z.object({
  params: z.object({
    barangayId: z.coerce.number().int().positive(),
  }),
  body: z
    .object({
      is_enabled: z.boolean().optional(),
      // Guiuan and its islands sit around 10.7–11.1°N, 125.6–126.0°E;
      // the box is loose so a pin can still go anywhere nearby.
      lat: z.number().min(10).max(12).optional(),
      lng: z.number().min(125).max(126.5).optional(),
    })
    .refine((body) => (body.lat === undefined) === (body.lng === undefined), {
      message: "Send lat and lng together.",
    }),
});

const bookingCloseSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
  body: z.object({
    outcome: z.enum(["cancelled", "completed"]),
    reason: z.string().trim().min(3, "Give a short reason (at least 3 characters).").max(255),
  }),
});

const timeOfDay = z
  .string()
  .trim()
  .regex(/^([01]\d|2[0-3]):[0-5]\d$/, "Use a time like 05:00 or 22:00.");

const systemSettingsSchema = z.object({
  body: z.object({
    appName: z.string().trim().min(1, "App name is required.").max(60),
    supportEmail: z.union([z.literal(""), z.string().trim().email("Enter a valid support email.").max(120)]),
    contactNumber: z.union([
      z.literal(""),
      z.string().trim().regex(/^[0-9+ ()-]{7,20}$/, "Enter a valid contact number."),
    ]),
    operatingHoursStart: timeOfDay,
    operatingHoursEnd: timeOfDay,
    enforceOperatingHours: z.boolean(),
  }),
});

module.exports = {
  bookingCloseSchema,
  barangayUpdateSchema,
  systemSettingsSchema,
  announcementSchema,
  driverParamSchema,
  rejectDriverSchema,
  requestCorrectionSchema,
  fareUpdateSchema,
  driverLicenseQuerySchema,
};
