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

module.exports = {
  driverParamSchema,
  rejectDriverSchema,
  requestCorrectionSchema,
  fareUpdateSchema,
  driverLicenseQuerySchema,
};
