const fs = require("fs");
const path = require("path");
const mysql = require("mysql2/promise");
const env = require("./env");

let pool;

async function ensureDatabaseAndSchema() {
  const connection = await mysql.createConnection({
    host: env.db.host,
    port: env.db.port,
    user: env.db.user,
    password: env.db.password,
    multipleStatements: true,
  });

  const schemaPath = path.resolve(__dirname, "../../sql/schema.sql");
  const schemaSql = fs
    .readFileSync(schemaPath, "utf8")
    .replace(/findme_tricycle/g, env.db.database);

  await connection.query(schemaSql);
  await connection.end();
}

async function initPool() {
  if (pool) return pool;
  pool = mysql.createPool({
    host: env.db.host,
    port: env.db.port,
    user: env.db.user,
    password: env.db.password,
    database: env.db.database,
    waitForConnections: true,
    connectionLimit: 20,
    queueLimit: 0,
  });
  return pool;
}

async function query(sql, params = []) {
  const dbPool = await initPool();
  const [rows] = await dbPool.execute(sql, params);
  return rows;
}

async function withTransaction(work) {
  const dbPool = await initPool();
  const connection = await dbPool.getConnection();

  try {
    await connection.beginTransaction();

    const client = {
      query: async (sql, params = []) => {
        const [rows] = await connection.execute(sql, params);
        return rows;
      },
    };

    const result = await work(client, connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

module.exports = {
  ensureDatabaseAndSchema,
  initPool,
  query,
  withTransaction,
};
