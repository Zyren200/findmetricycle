const { z } = require("./common");

// The website's Contact page. [hpTrap] is a field people never see; only
// bots fill it in. (It was called "website" before, which browser autofill
// could fill in, so real messages were thrown away.)
const contactMessageSchema = z.object({
  body: z.object({
    name: z.string().trim().min(1, "Please enter your name.").max(120),
    email: z.string().trim().toLowerCase().email("Please enter a valid email address.").max(190),
    subject: z.string().trim().max(160).optional().default(""),
    message: z.string().trim().min(1, "Please write your message.").max(5000),
    hpTrap: z.string().optional().default(""),
  }),
});

const contactParamSchema = z.object({
  params: z.object({
    id: z.coerce.number().int().positive(),
  }),
});

const contactReplySchema = contactParamSchema.extend({
  body: z.object({
    message: z.string().trim().min(1, "Write a reply first.").max(5000),
  }),
});

const contactStatusSchema = contactParamSchema.extend({
  body: z.object({
    status: z.enum(["open", "closed"]),
  }),
});

module.exports = {
  contactMessageSchema,
  contactReplySchema,
  contactStatusSchema,
};
