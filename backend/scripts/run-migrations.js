#!/usr/bin/env node
// Applies backend/sql/migrations/*.sql in order, recording each file in a
// `schema_migrations` table so it only ever runs once.
//
// schema.sql (run on every server start) already contains some of the
// columns later migrations add, so on a fresh database a migration can hit
// "duplicate column / key / table" errors. Those mean the change is already
// present and are skipped statement-by-statement instead of aborting.
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const env = require('../src/config/env');

const ALREADY_APPLIED_ERRORS = new Set([
  'ER_DUP_FIELDNAME', // column already exists
  'ER_DUP_KEYNAME', // index already exists
  'ER_TABLE_EXISTS_ERROR',
  'ER_CANT_DROP_FIELD_OR_KEY', // already dropped
  'ER_FK_DUP_NAME',
]);

// Splits a SQL file into statements on `;`, ignoring semicolons inside
// quoted strings and `--` / `#` line comments. Migrations here are plain
// DDL/SET/PREPARE statements (no DELIMITER blocks), which this handles.
function splitStatements(sql) {
  const statements = [];
  let current = '';
  let quote = null;

  for (let i = 0; i < sql.length; i += 1) {
    const ch = sql[i];
    const next = sql[i + 1];

    if (quote) {
      current += ch;
      if (ch === quote && next === quote) {
        current += next;
        i += 1;
      } else if (ch === quote) {
        quote = null;
      }
      continue;
    }

    if ((ch === '-' && next === '-') || ch === '#') {
      const end = sql.indexOf('\n', i);
      i = end === -1 ? sql.length : end;
      current += '\n';
      continue;
    }

    if (ch === "'" || ch === '"' || ch === '`') {
      quote = ch;
      current += ch;
      continue;
    }

    if (ch === ';') {
      if (current.trim()) statements.push(current.trim());
      current = '';
      continue;
    }

    current += ch;
  }

  if (current.trim()) statements.push(current.trim());
  return statements;
}

async function run() {
  let connection;
  try {
    const migrationsDir = path.resolve(__dirname, '..', 'sql', 'migrations');
    if (!fs.existsSync(migrationsDir)) {
      console.log('No migrations directory found:', migrationsDir);
      return;
    }

    const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
    if (!files.length) {
      console.log('No .sql migration files found in', migrationsDir);
      return;
    }

    connection = await mysql.createConnection({
      host: env.db.host,
      port: env.db.port,
      user: env.db.user,
      password: env.db.password,
      database: env.db.database,
    });

    await connection.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name VARCHAR(255) PRIMARY KEY,
        applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);
    const [appliedRows] = await connection.query('SELECT name FROM schema_migrations');
    const applied = new Set(appliedRows.map((row) => row.name));

    let ranAny = false;
    for (const file of files) {
      if (applied.has(file)) continue;
      ranAny = true;

      console.log('Applying migration:', file);
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');

      for (const statement of splitStatements(sql)) {
        try {
          await connection.query(statement);
        } catch (err) {
          if (!ALREADY_APPLIED_ERRORS.has(err.code)) {
            throw new Error(`${file}: ${err.message}\n  in: ${statement.slice(0, 200)}`);
          }
          console.log(`  skipped (already applied): ${err.code}`);
        }
      }

      await connection.query('INSERT INTO schema_migrations (name) VALUES (?)', [file]);
    }

    console.log(ranAny ? 'Migrations applied successfully' : 'Database is already up to date');
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

if (require.main === module) {
  run().catch((err) => {
    console.error('Migration failed:', err.message);
    process.exitCode = 1;
  });
}

module.exports = { splitStatements };
