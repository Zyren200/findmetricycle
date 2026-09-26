const express = require("express");
const validate = require("../middlewares/validate.middleware");
const { z } = require("zod");
const db = require("../config/db");
const authMiddleware = require("../middlewares/auth.middleware");
const requireRole = require("../middlewares/role.middleware");

const router = express.Router();

// Schemas
const createFavoriteSchema = z.object({
  body: z.object({
    label: z.string().min(1).max(120),
    address: z.string().min(1),
    lat: z.number(),
    lng: z.number(),
  }),
});

const updateFavoriteSchema = z.object({
  body: z.object({
    label: z.string().min(1).max(120).optional(),
    address: z.string().min(1).optional(),
    lat: z.number().optional(),
    lng: z.number().optional(),
  }),
});

// Passenger routes

/**
 * GET /favorites
 * List all favorites
 */
router.get("/", authMiddleware, async (req, res, next) => {
  try {
    const favorites = await db.query(
      `SELECT * FROM favorite_destinations
       WHERE user_id = ? AND deleted_at IS NULL
       ORDER BY updated_at DESC, created_at DESC`,
      [req.user.id]
    );

    res.json({
      success: true,
      data: favorites,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /favorites
 * Create favorite
 */
router.post(
  "/",
  authMiddleware,
  validate(createFavoriteSchema),
  async (req, res, next) => {
    try {
      const {
        label,
        address,
        lat,
        lng,
      } = req.body;

      const result = await db.query(
        `INSERT INTO favorite_destinations 
         (user_id, label, address, lat, lng)
         VALUES (?, ?, ?, ?, ?)`,
        [
          req.user.id,
          label,
          address,
          lat,
          lng,
        ]
      );

      res.json({
        success: true,
        message: "Favorite saved",
        data: {
          id: result.insertId,
          label,
          address,
          lat,
          lng,
        },
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /favorites/:id
 * Update favorite
 */
router.put(
  "/:id",
  authMiddleware,
  validate(updateFavoriteSchema),
  async (req, res, next) => {
    try {
      const { id } = req.params;
      const updates = req.body;

      // Verify ownership
      const favorite = await db.query(
        "SELECT id FROM favorite_destinations WHERE id = ? AND user_id = ? AND deleted_at IS NULL",
        [id, req.user.id]
      );

      if (favorite.length === 0) {
        return res.status(404).json({
          success: false,
          message: "Favorite not found",
        });
      }

      // Build dynamic update query
      const fields = [];
      const values = [];
      const mapping = {
        label: "label",
        address: "address",
        lat: "lat",
        lng: "lng",
      };

      for (const [key, dbColumn] of Object.entries(mapping)) {
        if (updates[key] !== undefined) {
          fields.push(`${dbColumn} = ?`);
          values.push(updates[key]);
        }
      }

      if (fields.length === 0) {
        return res.json({
          success: true,
          message: "No updates provided",
        });
      }

      values.push(new Date());
      values.push(id);

      await db.query(
        `UPDATE favorite_destinations SET ${fields.join(", ")}, updated_at = ? WHERE id = ?`,
        values
      );

      res.json({
        success: true,
        message: "Favorite updated",
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /favorites/:id
 * Delete favorite
 */
router.delete("/:id", authMiddleware, async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      `UPDATE favorite_destinations SET deleted_at = NOW() 
       WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
      [id, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Favorite not found",
      });
    }

    res.json({
      success: true,
      message: "Favorite deleted",
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /favorites/:id/use
 * Mark favorite as used (for frequency tracking)
 */
router.post("/:id/use", authMiddleware, async (req, res, next) => {
  try {
    const { id } = req.params;

    await db.query(
      `UPDATE favorite_destinations 
       SET updated_at = NOW() 
       WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
      [id, req.user.id]
    );

    res.json({
      success: true,
      message: "Favorite usage tracked",
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
