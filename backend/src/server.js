const http = require("http");
const app = require("./app");
const env = require("./config/env");
const { initSocket } = require("./sockets");
const db = require("./config/db");
const rideOfferScheduler = require("./services/ride-offer-scheduler.service");
const sosEscalationScheduler = require("./services/sos-escalation-scheduler.service");
const barangayService = require("./services/barangay.service");

const server = http.createServer(app);
initSocket(server);

async function bootstrap() {
  try {
    await db.ensureDatabaseAndSchema();
    await db.initPool();
    await db.query("SELECT 1");
    await barangayService.syncDefaultBarangays();
    server.listen(env.port, () => {
      console.log(`FindMeTricycle API running on http://localhost:${env.port}`);
    });
    rideOfferScheduler.start();
    sosEscalationScheduler.start();
  } catch (error) {
    console.error(
      "Failed to start server:",
      error.message,
      "- please ensure MySQL is running and .env credentials are correct."
    );
    process.exit(1);
  }
}

bootstrap();
