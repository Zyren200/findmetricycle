const db = require('../src/config/db');

(async function(){
  try {
    await db.query('UPDATE notifications SET deleted_at = NOW() WHERE id = ?', [1]);
    console.log('Soft-deleted test notification id=1');
    process.exit(0);
  } catch (err) {
    console.error('Failed to delete test notification:', err);
    process.exit(1);
  }
})();
