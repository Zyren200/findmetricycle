const express = require("express");
const authMiddleware = require("../middlewares/auth.middleware");
const validate = require("../middlewares/validate.middleware");
const { z } = require("../validations/common");
const pushTokenModel = require("../models/push-token.model");

const router = express.Router();

const tokenSchema = z.object({
  body: z.object({
    token: z.string().trim().min(20).max(255),
    platform: z.enum(["android", "ios"]).optional(),
  }),
});

// The app calls this after login and whenever Firebase rotates the token.
router.post("/push-token", authMiddleware, validate(tokenSchema), async (req, res, next) => {
  try {
    await pushTokenModel.saveToken(req.user.id, req.body.token, req.body.platform || "android");
    res.json({ success: true, message: "Device registered for notifications." });
  } catch (error) {
    next(error);
  }
});

// Called on logout, after the access token is already gone — knowing the
// device's token is what proves the request, and all it can do is stop
// pushes to that device.
router.post("/push-token/unregister", validate(tokenSchema), async (req, res, next) => {
  try {
    await pushTokenModel.removeTokens([req.body.token]);
    res.json({ success: true, message: "Device unregistered." });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
