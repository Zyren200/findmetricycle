const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const multer = require("multer");
const sharp = require("sharp");
const env = require("../config/env");
const ApiError = require("../utils/api-error");

const ALLOWED_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"];
const ALLOWED_IMAGE_FORMATS = ["jpeg", "png", "webp"];
const MAX_IMAGE_PIXELS = 40_000_000;
const TRACKED_UPLOAD_PATHS = Symbol("trackedUploadPaths");

function fileFilter(_req, file, cb) {
  if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    return cb(
      new ApiError(400, "Only JPG, PNG, and WEBP files are allowed.")
    );
  }

  cb(null, true);
}

function getUploadedFiles(req) {
  const files = [];

  if (req.file) files.push(req.file);

  if (Array.isArray(req.files)) {
    files.push(...req.files);
  } else if (req.files && typeof req.files === "object") {
    for (const list of Object.values(req.files)) {
      if (Array.isArray(list)) files.push(...list);
    }
  }

  return [...new Map(files.map((file) => [file.path, file])).values()];
}

async function cleanupUploadedFiles(req) {
  const paths = new Set(req[TRACKED_UPLOAD_PATHS] || []);

  for (const file of getUploadedFiles(req)) {
    if (file.path) paths.add(file.path);
  }

  await Promise.all(
    [...paths].flatMap((filePath) => [
      fs.promises.unlink(filePath).catch(() => {}),
      fs.promises.unlink(`${filePath}.processing`).catch(() => {}),
      fs.promises.unlink(`${filePath}.original`).catch(() => {}),
    ])
  );
}

async function sanitizeImage(file) {
  const processingPath = `${file.path}.processing`;

  try {
    const options = {
      limitInputPixels: MAX_IMAGE_PIXELS,
      failOn: "error",
    };

    const metadata = await sharp(file.path, options).metadata();

    if (!ALLOWED_IMAGE_FORMATS.includes(metadata.format)) {
      throw new ApiError(400, "The uploaded file is not a supported image.");
    }

    // Decode, correct orientation, remove metadata, and re-encode.
    await sharp(file.path, options)
      .rotate()
      .flatten({ background: "#ffffff" })
      .jpeg({ quality: 90 })
      .toFile(processingPath);

    const backupPath = `${file.path}.original`;

    try {
      await fs.promises.rename(file.path, backupPath);
      await fs.promises.rename(processingPath, file.path);
      await fs.promises.unlink(backupPath);
    } catch (error) {
      // Restore the original if replacing it failed.
      try {
        await fs.promises.access(backupPath);
        await fs.promises.rename(backupPath, file.path);
      } catch {
        // Keep the original error for the caller.
      }

      throw error;
    }

    const stats = await fs.promises.stat(file.path);

    file.filename = path.basename(file.path);
    file.mimetype = "image/jpeg";
    file.size = stats.size;
  } catch (error) {
    await fs.promises.unlink(processingPath).catch(() => {});

    if (error instanceof ApiError) throw error;

    throw new ApiError(
      400,
      "The uploaded file is invalid, corrupted, or too large to process."
    );
  }
}

function createImageUpload(subDirectory = "driver-docs") {
  const uploadDir = path.resolve(process.cwd(), env.upload.dir, subDirectory);

  fs.mkdirSync(uploadDir, { recursive: true });

  const storage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadDir),
    filename: (req, _file, cb) => {
      const filename = `${Date.now()}-${crypto.randomUUID()}.jpg`;
      const trackedPaths = (req[TRACKED_UPLOAD_PATHS] ||= []);

      // Track paths before the write finishes, so failed multi-file uploads
      // can clean files that Multer has not added to req.files yet.
      trackedPaths.push(path.join(uploadDir, filename));
      cb(null, filename);
    },
  });

  const uploader = multer({
    storage,
    fileFilter,
    limits: {
      fileSize: env.upload.maxUploadMb * 1024 * 1024,
    },
  });

  function wrapUpload(uploadMiddleware) {
    return (req, res, next) => {
      req[TRACKED_UPLOAD_PATHS] = [];

      uploadMiddleware(req, res, async (error) => {
        if (error) {
          await cleanupUploadedFiles(req);
          delete req[TRACKED_UPLOAD_PATHS];
          return next(error);
        }

        try {
          for (const file of getUploadedFiles(req)) {
            await sanitizeImage(file);
          }

          delete req[TRACKED_UPLOAD_PATHS];
          return next();
        } catch (validationError) {
          await cleanupUploadedFiles(req);
          delete req[TRACKED_UPLOAD_PATHS];
          return next(validationError);
        }
      });
    };
  }

  return {
    single: (fieldName) => wrapUpload(uploader.single(fieldName)),
    array: (fieldName, maxCount) =>
      wrapUpload(uploader.array(fieldName, maxCount)),
    fields: (fields) => wrapUpload(uploader.fields(fields)),
    any: () => wrapUpload(uploader.any()),
  };
}

const upload = createImageUpload();

module.exports = upload;
module.exports.createImageUpload = createImageUpload;
