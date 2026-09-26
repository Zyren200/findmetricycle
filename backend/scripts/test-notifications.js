const fetch = global.fetch || require('node-fetch');

(async function(){
  try {
    const loginRes = await fetch('http://localhost:5000/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '09990000000', password: 'Admin@123' }),
    });

    const loginJson = await loginRes.json();
    if (!loginJson.success) {
      console.error('Login failed:', loginJson);
      process.exit(1);
    }

    const token = loginJson.data.accessToken || loginJson.data.token;
    const notifRes = await fetch('http://localhost:5000/api/admin/notifications', {
      headers: { Authorization: 'Bearer ' + token },
    });
    const notifJson = await notifRes.json();
    console.log('Notifications response:', JSON.stringify(notifJson, null, 2));
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
})();
