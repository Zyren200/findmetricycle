const mysql = require('mysql2/promise');
const env = require('./src/config/env');

async function check() {
  const conn = await mysql.createConnection({
    host: env.db.host,
    user: env.db.user,
    password: env.db.password,
    database: env.db.database
  });
  
  try {
    console.log('\n=== Users by Role ===');
    const [users] = await conn.query('SELECT role, COUNT(*) as count FROM users GROUP BY role');
    console.table(users);
    
    console.log('\n=== Drivers by Status ===');
    const [drivers] = await conn.query('SELECT COUNT(*) as total, approval_status FROM drivers GROUP BY approval_status');
    console.table(drivers);
    
    console.log('\n=== Online Drivers ===');
    const [onlineDrivers] = await conn.query('SELECT COUNT(*) as online FROM drivers WHERE is_online=1');
    console.log(onlineDrivers[0]);
    
    console.log('\n=== Sample Drivers (with location data) ===');
    const [sampleDrivers] = await conn.query('SELECT id, tricycle_number, is_online, current_lat, current_lng, approval_status FROM drivers ORDER BY id ASC LIMIT 3');
    console.table(sampleDrivers);
    
    console.log('\n=== Bookings/Rides Data ===');
    const [bookings] = await conn.query('SELECT status, COUNT(*) as count FROM bookings GROUP BY status');
    console.table(bookings);
    
  } finally {
    await conn.end();
  }
}

check().catch(console.error);
