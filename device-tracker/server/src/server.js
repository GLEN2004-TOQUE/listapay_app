const express = require('express');
const cors = require('cors');
require('dotenv').config();

const { createStore } = require('./store');

const app = express();
const port = Number(process.env.PORT || 3000);
const corsOrigin = process.env.CORS_ORIGIN || '*';

app.use(cors({ origin: corsOrigin === '*' ? true : corsOrigin.split(',') }));
app.use(express.json());

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.socket.remoteAddress ?? null;
}

function createApp(store) {
  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });

  app.post('/api/register-device', async (req, res) => {
    try {
      const {
        device_id: deviceId,
        platform,
        app_version: appVersion,
        build_number: buildNumber,
        store_id: storeId,
        user_id: userId,
        device_label: deviceLabel,
      } = req.body ?? {};

      if (!deviceId || !platform) {
        return res.status(400).json({
          success: false,
          message: 'device_id and platform are required.',
        });
      }

      const existing = await store.getDevice(deviceId);
      if (existing?.is_blocked) {
        return res.status(403).json({
          success: false,
          blocked: true,
          message:
            existing.blocked_reason ??
            'This device has been blocked by an administrator.',
        });
      }

      const { device, isNew } = await store.registerDevice({
        device_id: deviceId,
        platform,
        app_version: appVersion ?? null,
        build_number: buildNumber ?? null,
        store_id: storeId ?? null,
        user_id: userId ?? null,
        device_label: deviceLabel ?? null,
        ip_address: clientIp(req),
      });

      return res.json({
        success: true,
        blocked: false,
        is_new_device: isNew,
        is_suspicious: device.is_suspicious,
        device,
      });
    } catch (error) {
      console.error('register-device failed:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to register device.',
      });
    }
  });

  app.get('/api/devices/:deviceId/status', async (req, res) => {
    try {
      const device = await store.getDevice(req.params.deviceId);
      if (!device) {
        return res.status(404).json({
          success: false,
          message: 'Device not found.',
        });
      }

      return res.json({
        success: true,
        blocked: device.is_blocked,
        message: device.blocked_reason,
        device,
      });
    } catch (error) {
      console.error('device status failed:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to read device status.',
      });
    }
  });

  app.get('/api/devices', async (_req, res) => {
    try {
      const devices = await store.listDevices();
      return res.json({ success: true, devices });
    } catch (error) {
      console.error('list devices failed:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to list devices.',
      });
    }
  });

  app.get('/api/stats', async (_req, res) => {
    try {
      const stats = await store.stats();
      return res.json({ success: true, stats });
    } catch (error) {
      console.error('stats failed:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to load stats.',
      });
    }
  });

  app.patch('/api/devices/:deviceId/block', async (req, res) => {
    try {
      const reason =
        typeof req.body?.reason === 'string' ? req.body.reason : 'Blocked by admin';
      const device = await store.setBlocked(req.params.deviceId, true, reason);
      if (!device) {
        return res.status(404).json({
          success: false,
          message: 'Device not found.',
        });
      }
      return res.json({ success: true, device });
    } catch (error) {
      console.error('block device failed:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to block device.',
      });
    }
  });

  app.patch('/api/devices/:deviceId/unblock', async (req, res) => {
    try {
      const device = await store.setBlocked(req.params.deviceId, false, null);
      if (!device) {
        return res.status(404).json({
          success: false,
          message: 'Device not found.',
        });
      }
      return res.json({ success: true, device });
    } catch (error) {
      console.error('unblock device failed:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to unblock device.',
      });
    }
  });

  return app;
}

async function start() {
  const store = await createStore();
  createApp(store);

  app.listen(port, () => {
    console.log(`Device tracker API listening on http://localhost:${port}`);
    if (!process.env.DATABASE_URL) {
      console.log('Using in-memory store. Set DATABASE_URL for PostgreSQL.');
    }
  });
}

start().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
