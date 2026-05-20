const express = require('express');

const app = express();
const port = process.env.PORT || 8080;
const appName = process.env.APP_NAME || 'app2';
const podName = process.env.POD_NAME || 'unknown';
const podIP = process.env.POD_IP || 'unknown';
const nodeName = process.env.NODE_NAME || 'unknown';
const namespace = process.env.NAMESPACE || 'unknown';
const startedAt = Date.now();

app.get('/healthz', (_req, res) => res.status(200).send('ok'));

app.get('/', (_req, res) => {
  res.json({
    app: appName,
    podName,
    podIP,
    nodeName,
    namespace,
    uptimeSec: Math.floor((Date.now() - startedAt) / 1000),
  });
});

// app2-exclusive endpoint: echo request headers. Useful for debugging
// ingress + reverse-proxy header rewriting, and visibly different from app1.
app.get('/headers', (req, res) => {
  res.json({
    app: appName,
    podName,
    headers: req.headers,
  });
});

app.listen(port, () => {
  console.log(`${appName} listening on :${port} (pod=${podName} ip=${podIP} node=${nodeName} ns=${namespace})`);
});
