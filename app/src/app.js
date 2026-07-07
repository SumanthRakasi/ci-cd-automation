const express = require('express');

const app = express();

const APP_VERSION = process.env.APP_VERSION || 'dev';

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from the CI/CD demo app',
    version: APP_VERSION,
    hostname: require('os').hostname(),
  });
});

// Kept intentionally dependency-free: the deploy script polls this to decide
// whether a freshly started container is ready to take traffic.
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/api/info', (req, res) => {
  res.json({
    version: APP_VERSION,
    uptimeSeconds: process.uptime(),
    hostname: require('os').hostname(),
  });
});

module.exports = app;
