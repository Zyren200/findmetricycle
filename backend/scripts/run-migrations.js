#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const env = require('../src/config/env');

async function run() {
  let connection;
  try {
    const migrationsDir = path.resolve(__dirname, '..', 'sql', 'migrations');
    if (!fs.existsSync(migrationsDir)) {
      console.log('No migrations directory found:', migrationsDir);
      process.exit(0);
    }

    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();
    if (!files.length) {
      console.log('No .sql migration files found in', migrationsDir);
      process.exit(0);
    }

    connection = await mysql.createConnection({
      host: env.db.host,
      port: env.db.port,
      user: env.db.user,
      password: env.db.password,
      database: env.db.database,
      multipleStatements: true,
    });

    for (const file of files) {
      const filePath = path.join(migrationsDir, file);
      console.log('Applying migration:', file);
      const sql = fs.readFileSync(filePath, 'utf8');
      await connection.query(sql);
    }

    console.log('Migrations applied successfully');
    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

run();
