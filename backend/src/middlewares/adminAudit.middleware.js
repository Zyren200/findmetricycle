const fs = require('fs');
const path = require('path');
const db = require('../config/db');

const LOG_DIR = path.resolve(__dirname, '../../logs');
const LOG_FILE = path.join(LOG_DIR, 'admin-audit.log');

function ensureLogDir() {
  try {
    if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
  } catch (err) {
    // ignore
  }
}

function sanitize(obj) {
  if (!obj) return '';
  const clone = {};
  Object.keys(obj).forEach((k) => {
    const low = k.toLowerCase();
    if (low.includes('password') || low.includes('secret') || low.includes('token')) {
      clone[k] = '[REDACTED]';
    } else {
      try {
        const v = obj[k];
        clone[k] = typeof v === 'string' && v.length > 200 ? `${v.slice(0,200)}...` : v;
      } catch (e) {
        clone[k] = '[UNSERIALIZABLE]';
      }
    }
  });
  return JSON.stringify(clone);
}

function adminAudit(req, _res, next) {
  // Only record actions that change state — GET reads would drown the
  // meaningful entries (approvals, suspensions, fare changes) in noise.
  if (req.method === "GET") {
    return next();
  }

  try {
    ensureLogDir();
    const ts = new Date().toISOString();
    const userId = req.user ? req.user.id : 'anon';
    const ip = req.headers['x-forwarded-for'] || req.ip || req.connection?.remoteAddress || '';
    const method = req.method;
    const url = req.originalUrl || req.url || '';
    const body = sanitize(req.body);
    const entry = `${ts}\t${userId}\t${ip}\t${method}\t${url}\t${body}\n`;
    fs.appendFile(LOG_FILE, entry, (err) => {
      // don't fail requests on logging errors
      if (err) {
        console.warn('adminAudit log write failed:', err && err.message ? err.message : err);
      }
    });

    db.query(
      `
        INSERT INTO activity_logs
          (admin_id, action, target_type, target_id, metadata_json, ip_address, user_agent)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `,
      [
        req.user ? req.user.id : null,
        `${method} ${url}`,
        inferTargetType(url),
        inferTargetId(url),
        body || null,
        String(ip || '').slice(0, 45),
        String(req.headers['user-agent'] || '').slice(0, 255),
      ]
    ).catch((err) => {
      if (process.env.NODE_ENV !== 'test') {
        console.warn('adminAudit database write failed:', err && err.message ? err.message : err);
      }
    });
  } catch (err) {
    // ignore logging problems
  }

  return next();
}

function inferTargetType(url) {
  const match = String(url || '').match(/\/api\/admin\/([^/?]+)/);
  return match ? match[1] : 'admin';
}

function inferTargetId(url) {
  // adminAudit runs before Express resolves the matched route's params,
  // so the numeric id is pulled directly from the URL path instead.
  const match = String(url || '').match(/\/api\/admin\/[^/?]+\/(\d+)/);
  return match ? Number(match[1]) : null;
}

module.exports = adminAudit;
