const fetch = global.fetch || (async () => { throw new Error('global fetch not available') })();

(async function(){
  try {
    const loginRes = await fetch('http://localhost:5000/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '09990000000', password: 'Admin@123' }),
    });
    const loginJson = await loginRes.json();
    const token = loginJson.data.accessToken || loginJson.data.token;

    // mark id=1 read
    await fetch('http://localhost:5000/api/admin/notifications/1/read', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + token },
    });

    const resp = await fetch('http://localhost:5000/api/admin/notifications', { headers: { Authorization: 'Bearer ' + token } });
    const j = await resp.json();
    console.log('After mark-read:', JSON.stringify(j, null, 2));
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
