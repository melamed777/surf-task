const express = require('express');

const app = express();
const port = process.env.PORT || 8080;
const appName = process.env.APP_NAME || 'app1';
const podName = process.env.POD_NAME || 'unknown';
const podIP = process.env.POD_IP || 'unknown';

app.get('/healthz', (_req, res) => res.status(200).send('ok'));

app.get('/', (_req, res) => {
  res.json({
    app: appName,
    podName,
    podIP,
  });
});

app.listen(port, () => {
  console.log(`${appName} listening on :${port} (pod=${podName} ip=${podIP})`);
});
