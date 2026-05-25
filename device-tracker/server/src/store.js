const { Pool } = require('pg');

const ONLINE_THRESHOLD_MS =
  Number(process.env.ONLINE_THRESHOLD_MINUTES || 5) * 60 * 1000;

function normalizeDevice(row) {
  const lastSeen = new Date(row.last_seen);
  const online = Date.now() - lastSeen.getTime() <= ONLINE_THRESHOLD_MS;

  return {
    id: row.id,
    device_id: row.device_id,
    platform: row.platform,
    app_version: row.app_version,
    build_number: row.build_number,
    store_id: row.store_id,
    user_id: row.user_id,
    device_label: row.device_label,
    ip_address: row.ip_address,
    first_seen: row.first_seen,
    last_seen: row.last_seen,
    is_blocked: row.is_blocked,
    blocked_reason: row.blocked_reason,
    is_suspicious: row.is_suspicious,
    status: online ? 'online' : 'offline',
  };
}

class MemoryStore {
  constructor() {
    this.devices = new Map();
    this.nextId = 1;
  }

  async registerDevice(payload) {
    const now = new Date();
    const existing = this.devices.get(payload.device_id);

    if (!existing) {
      const device = {
        id: this.nextId++,
        ...payload,
        first_seen: now,
        last_seen: now,
        is_blocked: false,
        blocked_reason: null,
        is_suspicious: false,
      };
      this.devices.set(payload.device_id, device);
      return { device: normalizeDevice(device), isNew: true };
    }

    existing.platform = payload.platform ?? existing.platform;
    existing.app_version = payload.app_version ?? existing.app_version;
    existing.build_number = payload.build_number ?? existing.build_number;
    existing.store_id = payload.store_id ?? existing.store_id;
    existing.user_id = payload.user_id ?? existing.user_id;
    existing.device_label = payload.device_label ?? existing.device_label;
    existing.ip_address = payload.ip_address ?? existing.ip_address;
    existing.last_seen = now;

    if (payload.store_id) {
      const siblings = [...this.devices.values()].filter(
        (item) =>
          item.store_id === payload.store_id &&
          item.device_id !== payload.device_id,
      );
      if (siblings.length > 0) {
        existing.is_suspicious = true;
      }
    }

    return { device: normalizeDevice(existing), isNew: false };
  }

  async listDevices() {
    return [...this.devices.values()]
      .sort((a, b) => new Date(b.last_seen) - new Date(a.last_seen))
      .map(normalizeDevice);
  }

  async getDevice(deviceId) {
    const device = this.devices.get(deviceId);
    return device ? normalizeDevice(device) : null;
  }

  async setBlocked(deviceId, blocked, reason = null) {
    const device = this.devices.get(deviceId);
    if (!device) return null;
    device.is_blocked = blocked;
    device.blocked_reason = blocked ? reason : null;
    return normalizeDevice(device);
  }

  async stats() {
    const devices = [...this.devices.values()];
    const onlineCutoff = Date.now() - ONLINE_THRESHOLD_MS;
    return {
      total: devices.length,
      online: devices.filter(
        (d) => new Date(d.last_seen).getTime() >= onlineCutoff,
      ).length,
      blocked: devices.filter((d) => d.is_blocked).length,
      suspicious: devices.filter((d) => d.is_suspicious).length,
      android: devices.filter((d) => d.platform === 'Android').length,
      ios: devices.filter((d) => d.platform === 'iOS').length,
    };
  }
}

class PostgresStore {
  constructor(pool) {
    this.pool = pool;
  }

  async registerDevice(payload) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const existingResult = await client.query(
        'SELECT * FROM devices WHERE device_id = $1',
        [payload.device_id],
      );
      const existing = existingResult.rows[0];
      const isNew = !existing;

      const upsertResult = await client.query(
        `
        INSERT INTO devices (
          device_id, platform, app_version, build_number,
          store_id, user_id, device_label, ip_address, last_seen
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
        ON CONFLICT (device_id) DO UPDATE SET
          platform = EXCLUDED.platform,
          app_version = EXCLUDED.app_version,
          build_number = EXCLUDED.build_number,
          store_id = COALESCE(EXCLUDED.store_id, devices.store_id),
          user_id = COALESCE(EXCLUDED.user_id, devices.user_id),
          device_label = COALESCE(EXCLUDED.device_label, devices.device_label),
          ip_address = COALESCE(EXCLUDED.ip_address, devices.ip_address),
          last_seen = NOW()
        RETURNING *
        `,
        [
          payload.device_id,
          payload.platform,
          payload.app_version,
          payload.build_number,
          payload.store_id,
          payload.user_id,
          payload.device_label,
          payload.ip_address,
        ],
      );

      const device = upsertResult.rows[0];

      if (payload.store_id) {
        const siblings = await client.query(
          `
          SELECT COUNT(*)::int AS count
          FROM devices
          WHERE store_id = $1 AND device_id <> $2
          `,
          [payload.store_id, payload.device_id],
        );
        if (siblings.rows[0].count > 0) {
          await client.query(
            'UPDATE devices SET is_suspicious = TRUE WHERE device_id = $1',
            [payload.device_id],
          );
          device.is_suspicious = true;
        }
      }

      await client.query('COMMIT');
      return { device: normalizeDevice(device), isNew };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async listDevices() {
    const result = await this.pool.query(
      'SELECT * FROM devices ORDER BY last_seen DESC',
    );
    return result.rows.map(normalizeDevice);
  }

  async getDevice(deviceId) {
    const result = await this.pool.query(
      'SELECT * FROM devices WHERE device_id = $1',
      [deviceId],
    );
    return result.rows[0] ? normalizeDevice(result.rows[0]) : null;
  }

  async setBlocked(deviceId, blocked, reason = null) {
    const result = await this.pool.query(
      `
      UPDATE devices
      SET is_blocked = $2,
          blocked_reason = CASE WHEN $2 THEN $3 ELSE NULL END
      WHERE device_id = $1
      RETURNING *
      `,
      [deviceId, blocked, reason],
    );
    return result.rows[0] ? normalizeDevice(result.rows[0]) : null;
  }

  async stats() {
    const onlineCutoff = new Date(
      Date.now() - ONLINE_THRESHOLD_MS,
    ).toISOString();
    const result = await this.pool.query(
      `
      SELECT
        COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE last_seen >= $1)::int AS online,
        COUNT(*) FILTER (WHERE is_blocked)::int AS blocked,
        COUNT(*) FILTER (WHERE is_suspicious)::int AS suspicious,
        COUNT(*) FILTER (WHERE platform = 'Android')::int AS android,
        COUNT(*) FILTER (WHERE platform = 'iOS')::int AS ios
      FROM devices
      `,
      [onlineCutoff],
    );
    return result.rows[0];
  }
}

async function createStore() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.warn('DATABASE_URL not set — using in-memory device store.');
    return new MemoryStore();
  }

  const pool = new Pool({ connectionString: databaseUrl });
  await pool.query('SELECT 1');
  return new PostgresStore(pool);
}

module.exports = {
  createStore,
  normalizeDevice,
};