const express = require("express");
const path = require("path");
const fs = require("fs");
const documentAuthMiddleware = require("../middlewares/documentAuth.middleware");
const roles = require("../constants/roles");
const env = require("../config/env");
const db = require("../config/db");

const router = express.Router();

const DRIVER_DOCS_DIR = path.resolve(process.cwd(), env.upload.dir, "driver-docs");

// Driver license / business permit / selfie images are sensitive documents.
// They're served here instead of the public /uploads static mount, gated to
// the applicant who owns them or an admin — never to an arbitrary URL holder.
router.get("/driver/:filename", documentAuthMiddleware, async (req, res, next) => {
  try {
    const { filename } = req.params;

    if (!/^[A-Za-z0-9._-]+$/.test(filename)) {
      return res.status(400).json({ success: false, message: "Invalid filename." });
    }

    const filePath = path.join(DRIVER_DOCS_DIR, filename);
    if (!filePath.startsWith(DRIVER_DOCS_DIR) || !fs.existsSync(filePath)) {
      return res.status(404).json({ success: false, message: "Document not found." });
    }

    if (req.user.role !== roles.ADMIN) {
      const relativePath = `/uploads/driver-docs/${filename}`;
      const rows = await db.query(
        `
          SELECT id FROM driver_applications
          WHERE user_id = ?
            AND (license_image_url = ? OR business_permit_image_url = ? OR selfie_image_url = ?)
          LIMIT 1
        `,
        [req.user.id, relativePath, relativePath, relativePath]
      );
      if (rows.length === 0) {
        return res.status(403).json({ success: false, message: "You do not have access to this document." });
      }
    }

    res.sendFile(filePath);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
