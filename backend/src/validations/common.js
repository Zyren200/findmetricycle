const { z } = require("zod");

const phoneSchema = z
  .string()
  .trim()
  .regex(/^[0-9+ -]{7,20}$/, "phone format is invalid");

const idParamSchema = z.object({
  params: z.object({
    bookingId: z.coerce.number().int().positive(),
  }),
});

module.exports = {
  z,
  phoneSchema,
  idParamSchema,
};

