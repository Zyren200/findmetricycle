const { z } = require("./common");

function optionalTrimmedString(schema) {
  return z.preprocess((value) => {
    if (typeof value !== "string") return value;
    const trimmed = value.trim();
    return trimmed === "" ? undefined : trimmed;
  }, schema.optional());
}

const optionalEmailSchema = z.preprocess((value) => {
  if (typeof value !== "string") return value;
  const trimmed = value.trim();
  return trimmed === "" ? null : trimmed;
}, z.string().email().max(120).nullable().optional());

const statusSchema = z.object({
  body: z.object({
    isOnline: z
      .union([z.boolean(), z.enum(["true", "false", "1", "0"])])
      .transform((value) => value === true || value === "true" || value === "1"),
  }),
});

const locationSchema = z.object({
  body: z.object({
    lat: z.coerce.number().min(-90).max(90),
    lng: z.coerce.number().min(-180).max(180),
  }),
});

const bookingResponseSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
  body: z.object({
    action: z.enum(["accept", "decline"]),
    reason: z.string().trim().max(255).optional().or(z.literal("")),
  }),
});

const bookingParamSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
});

const startRideSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
  body: z.object({
    pin: z.string().trim().regex(/^\d{4}$/, "pin must be a 4-digit code"),
  }),
});

const reportDriverSchema = z.object({
  body: z.object({
    bookingId: z.coerce.number().int().positive().optional(),
    category: z.enum([
      "no_show",
      "incorrect_pickup",
      "fare_dispute",
      "safety_concern",
      "passenger_behavior",
      "other",
    ]),
    description: z.string().trim().min(1).max(1000),
  }),
});

const sosSchema = z.object({
  body: z.object({
    bookingId: z.coerce.number().int().positive().optional(),
    lat: z.coerce.number().min(-90).max(90).optional(),
    lng: z.coerce.number().min(-180).max(180).optional(),
    message: z.string().trim().max(500).optional(),
  }),
});

const noShowSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
  body: z.object({
    note: z.string().trim().max(500).optional(),
  }),
});

const completeRideSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
  body: z.object({
    actualDistanceKm: z.coerce.number().min(0).max(1000).optional(),
  }),
});

const profileUpdateSchema = z.object({
  body: z.object({
    fullName: optionalTrimmedString(z.string().min(2).max(120)),
    phone: optionalTrimmedString(
      z.string().regex(/^[0-9+ -]{7,20}$/, "phone format is invalid")
    ),
    email: optionalEmailSchema,
    tricycleNumber: optionalTrimmedString(z.string().min(2).max(60)),
  }),
});

module.exports = {
  statusSchema,
  locationSchema,
  bookingResponseSchema,
  bookingParamSchema,
  startRideSchema,
  noShowSchema,
  completeRideSchema,
  profileUpdateSchema,
  reportDriverSchema,
  sosSchema,
};
