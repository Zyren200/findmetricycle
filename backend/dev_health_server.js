const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());

app.get('/api/health', (req, res) => {
  res.json({ ok: true, timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => res.send('Dev health server'));

const port = process.env.PORT || 5000;
app.listen(port, () => console.log(`Dev health server listening on ${port}`));
