const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const multer = require("multer");
const env = require("../config/env");
const ApiError = require("../utils/api-error");

function fileFilter(_req, file, cb) {
  const allowed = ["image/jpeg", "image/png", "image/webp"];
  if (!allowed.includes(file.mimetype)) {
    return cb(new ApiError(400, "Only JPG, PNG, and WEBP files are allowed."));
  }
  return cb(null, true);
}

function createImageUpload(subDirectory = "driver-docs") {
  const uploadDir = path.resolve(process.cwd(), env.upload.dir, subDirectory);
  fs.mkdirSync(uploadDir, { recursive: true });

  const storage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadDir),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase();
      cb(null, `${Date.now()}-${crypto.randomUUID()}${ext}`);
    },
  });

  return multer({
    storage,
    fileFilter,
    limits: {
      fileSize: env.upload.maxUploadMb * 1024 * 1024,
    },
  });
}

const upload = createImageUpload();

module.exports = upload;
module.exports.createImageUpload = createImageUpload;
