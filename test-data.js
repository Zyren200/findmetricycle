const mysql = require('mysql2/promise');

async function checkData() {
  const conn = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'findme_tricycle'
  });

  console.log('=== BOOKINGS/RIDES ===');
  const [bookings] = await conn.execute('SELECT id, user_id, driver_id, booking_status, pickup_location, dropoff_location, fare_amount, created_at FROM bookings LIMIT 5');
  console.log(JSON.stringify(bookings, null, 2));
  
  const [cnt] = await conn.execute('SELECT COUNT(*) as cnt FROM bookings');
  console.log('\nTotal bookings:', cnt[0].cnt);

  console.log('\n=== PENDING DRIVERS ===');
  const [pending] = await conn.execute('SELECT d.id, u.full_name, u.phone, d.approval_status, d.created_at FROM drivers d JOIN users u ON d.user_id = u.id WHERE d.approval_status = ' + "'pending'");
  console.log(JSON.stringify(pending, null, 2));

  console.log('\n=== ALL DRIVER STATUSES ===');
  const [statuses] = await conn.execute('SELECT approval_status, COUNT(*) as count FROM drivers GROUP BY approval_status');
  console.log(JSON.stringify(statuses, null, 2));

  await conn.end();
}

checkData().catch(console.error);
