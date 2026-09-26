const http = require("http");
const app = require("./app");
const env = require("./config/env");
const { initSocket } = require("./sockets");
const db = require("./config/db");
const rideOfferScheduler = require("./services/ride-offer-scheduler.service");

const server = http.createServer(app);
initSocket(server);

async function bootstrap() {
  try {
    await db.ensureDatabaseAndSchema();
    await db.initPool();
    await db.query("SELECT 1");
    server.listen(env.port, () => {
      // eslint-disable-next-line no-console
      console.log(`FindMeTricycle API running on http://localhost:${env.port}`);
    });
    rideOfferScheduler.start();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(
      "Failed to start server:",
      error.message,
      "- please ensure MySQL is running and .env credentials are correct."
    );
    process.exit(1);
  }
}

bootstrap();
