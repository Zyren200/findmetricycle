const fetch = global.fetch || require('node-fetch');

(async function(){
  try {
    // login
    const loginRes = await fetch('http://localhost:5000/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '09990000000', password: 'Admin@123' }),
    });
    const loginJson = await loginRes.json();
    if (!loginJson.success) throw new Error('Login failed: '+JSON.stringify(loginJson));
    const token = loginJson.data.accessToken || loginJson.data.token;

    // create notification
    const createRes = await fetch('http://localhost:5000/api/admin/notifications', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
      body: JSON.stringify({ type: 'test', title: 'Test Notification', body: 'This is a test notification created by script.' }),
    });
    const createJson = await createRes.json();
    console.log('Create response:', JSON.stringify(createJson, null, 2));

    // fetch notifications
    const notifRes = await fetch('http://localhost:5000/api/admin/notifications', {
      headers: { Authorization: 'Bearer ' + token },
    });
    const notifJson = await notifRes.json();
    console.log('Notifications:', JSON.stringify(notifJson, null, 2));
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
})();
