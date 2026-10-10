const express = require("express");
const rateLimit = require("express-rate-limit");
const validate = require("../middlewares/validate.middleware");
const contactController = require("../controllers/contact.controller");
const { contactMessageSchema } = require("../validations/contact.schema");

const router = express.Router();

// Public, so kept to a few messages per visitor.
const contactLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, _next, options) => {
    console.warn(`Contact form: rate limit reached for ${req.ip}.`);
    res.status(options.statusCode).json({
      success: false,
      message: "You've sent several messages already. Please try again later.",
    });
  },
});

// POST /contact — the website's Contact page.
router.post("/", contactLimiter, validate(contactMessageSchema), contactController.submitMessage);

module.exports = router;
