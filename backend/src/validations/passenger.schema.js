const { z, phoneSchema } = require("./common");
const { MIN_PASSENGERS, MAX_PASSENGERS } = require("../constants/fare");

const findRideSchema = z.object({
  body: z.object({
    pickupAddress: z.string().trim().max(255).optional().or(z.literal("")),
    pickupLat: z.coerce.number().min(-90).max(90),
    pickupLng: z.coerce.number().min(-180).max(180),
    dropoffAddress: z.string().trim().max(255).optional().or(z.literal("")),
    dropoffLat: z.coerce.number().min(-90).max(90),
    dropoffLng: z.coerce.number().min(-180).max(180),
    autoAssign: z.boolean().optional(),
    passengerCount: z.coerce
      .number()
      .int()
      .min(MIN_PASSENGERS)
      .max(MAX_PASSENGERS)
      .optional(),
  }),
});

const bookingIdParamSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
});

const ratingSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
  body: z.object({
    stars: z.coerce.number().int().min(1).max(5),
    feedback: z.string().trim().max(1000).optional().or(z.literal("")),
  }),
});

const sosSchema = z.object({
  body: z.object({
    bookingId: z.coerce.number().int().positive().optional(),
    lat: z.coerce.number().min(-90).max(90).optional(),
    lng: z.coerce.number().min(-180).max(180).optional(),
    message: z.string().trim().max(500).optional().or(z.literal("")),
  }),
});

const chooseDriverSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
  body: z.object({
    driverId: z.coerce.number().int().positive(),
  }),
});

const updateProfileSchema = z.object({
  body: z.object({
    fullName: z.string().trim().min(1).max(120).optional(),
    phone: phoneSchema.optional(),
    email: z.string().trim().email().optional().or(z.literal("")),
    address: z.string().trim().max(255).optional().or(z.literal("")),
  }),
});

const deleteAccountSchema = z.object({
  body: z.object({
    password: z.string().min(1),
  }),
});

module.exports = {
  findRideSchema,
  bookingIdParamSchema,
  ratingSchema,
  chooseDriverSchema,
  sosSchema,
  updateProfileSchema,
  deleteAccountSchema,
};
