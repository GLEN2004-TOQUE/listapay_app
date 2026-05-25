import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  API_BASE,
  blockDevice,
  fetchDevices,
  fetchStats,
  unblockDevice,
} from './api';

function formatDate(value) {
  if (!value) return '—';
  return new Date(value).toLocaleString();
}

function truncate(value, length = 12) {
  if (!value) return '—';
  if (value.length <= length) return value;
  return `${value.slice(0, length)}…`;
}

function StatCard({ label, value, accent }) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5 shadow-lg shadow-black/20">
      <p className="text-sm text-slate-400">{label}</p>
      <p className={`mt-2 text-3xl font-semibold ${accent}`}>{value}</p>
    </div>
  );
}

function StatusBadge({ status, blocked }) {
  if (blocked) {
    return (
      <span className="rounded-full bg-rose-500/15 px-2.5 py-1 text-xs font-medium text-rose-300">
        Blocked
      </span>
    );
  }

  const online = status === 'online';
  return (
    <span
      className={`rounded-full px-2.5 py-1 text-xs font-medium ${
        online
          ? 'bg-emerald-500/15 text-emerald-300'
          : 'bg-slate-700 text-slate-300'
      }`}
    >
      {online ? 'Online' : 'Offline'}
    </span>
  );
}

export default function App() {
  const [devices, setDevices] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [platformFilter, setPlatformFilter] = useState('all');
  const [actionId, setActionId] = useState('');

  const load = useCallback(async () => {
    try {
      setError('');
      const [deviceResponse, statsResponse] = await Promise.all([
        fetchDevices(),
        fetchStats(),
      ]);
      setDevices(deviceResponse.devices ?? []);
      setStats(statsResponse.stats ?? null);
    } catch (err) {
      setError(err.message || 'Failed to load devices.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
    const timer = setInterval(load, 10000);
    return () => clearInterval(timer);
  }, [load]);

  const filteredDevices = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return devices.filter((device) => {
      const matchesPlatform =
        platformFilter === 'all' || device.platform === platformFilter;
      const matchesQuery =
        !normalizedQuery ||
        device.device_id.toLowerCase().includes(normalizedQuery) ||
        (device.store_id ?? '').toLowerCase().includes(normalizedQuery) ||
        (device.device_label ?? '').toLowerCase().includes(normalizedQuery) ||
        (device.ip_address ?? '').toLowerCase().includes(normalizedQuery);
      return matchesPlatform && matchesQuery;
    });
  }, [devices, platformFilter, query]);

  async function handleBlock(deviceId) {
    const reason =
      window.prompt('Block reason (optional):') ?? 'Blocked by admin';
    setActionId(deviceId);
    try {
      await blockDevice(deviceId, reason);
      await load();
    } catch (err) {
      setError(err.message || 'Failed to block device.');
    } finally {
      setActionId('');
    }
  }

  async function handleUnblock(deviceId) {
    setActionId(deviceId);
    try {
      await unblockDevice(deviceId);
      await load();
    } catch (err) {
      setError(err.message || 'Failed to unblock device.');
    } finally {
      setActionId('');
    }
  }

  return (
    <div className="min-h-screen bg-slate-950 px-4 py-8 text-slate-100 sm:px-8">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm uppercase tracking-[0.2em] text-emerald-400">
              ListaPay
            </p>
            <h1 className="mt-2 text-3xl font-semibold">Device Tracker</h1>
            <p className="mt-2 max-w-2xl text-slate-400">
              Monitor installed devices, detect shared APK copies, and block
              unauthorized installs in real time.
            </p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-900/60 px-4 py-3 text-sm text-slate-400">
            API: <span className="text-slate-200">{API_BASE}</span>
          </div>
        </header>

        {stats && (
          <section className="mb-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-6">
            <StatCard label="Total devices" value={stats.total} accent="text-white" />
            <StatCard label="Online" value={stats.online} accent="text-emerald-400" />
            <StatCard label="Blocked" value={stats.blocked} accent="text-rose-400" />
            <StatCard
              label="Suspicious"
              value={stats.suspicious}
              accent="text-amber-400"
            />
            <StatCard label="Android" value={stats.android} accent="text-cyan-300" />
            <StatCard label="iOS" value={stats.ios} accent="text-indigo-300" />
          </section>
        )}

        <section className="mb-6 flex flex-col gap-3 sm:flex-row">
          <input
            type="search"
            placeholder="Search device ID, store, label, IP…"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="w-full rounded-xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm outline-none ring-emerald-500/30 focus:ring-2"
          />
          <select
            value={platformFilter}
            onChange={(event) => setPlatformFilter(event.target.value)}
            className="rounded-xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm outline-none"
          >
            <option value="all">All platforms</option>
            <option value="Android">Android</option>
            <option value="iOS">iOS</option>
          </select>
          <button
            type="button"
            onClick={load}
            className="rounded-xl bg-emerald-500 px-4 py-3 text-sm font-medium text-slate-950 hover:bg-emerald-400"
          >
            Refresh
          </button>
        </section>

        {error && (
          <div className="mb-6 rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
            {error}
          </div>
        )}

        <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900/50 shadow-xl shadow-black/20">
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="bg-slate-900 text-slate-400">
                <tr>
                  <th className="px-4 py-3 font-medium">Device ID</th>
                  <th className="px-4 py-3 font-medium">Platform</th>
                  <th className="px-4 py-3 font-medium">Version</th>
                  <th className="px-4 py-3 font-medium">Store</th>
                  <th className="px-4 py-3 font-medium">IP</th>
                  <th className="px-4 py-3 font-medium">First seen</th>
                  <th className="px-4 py-3 font-medium">Last seen</th>
                  <th className="px-4 py-3 font-medium">Status</th>
                  <th className="px-4 py-3 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={9} className="px-4 py-10 text-center text-slate-400">
                      Loading devices…
                    </td>
                  </tr>
                ) : filteredDevices.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="px-4 py-10 text-center text-slate-400">
                      No devices registered yet. Open the ListaPay app on a phone to
                      send its first heartbeat.
                    </td>
                  </tr>
                ) : (
                  filteredDevices.map((device) => (
                    <tr
                      key={device.device_id}
                      className="border-t border-slate-800/80 hover:bg-slate-900/70"
                    >
                      <td className="px-4 py-3 font-mono text-xs">
                        <div title={device.device_id}>
                          {truncate(device.device_id, 16)}
                        </div>
                        {device.is_suspicious && (
                          <span className="mt-1 inline-block rounded-full bg-amber-500/15 px-2 py-0.5 text-[10px] text-amber-300">
                            Shared APK?
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3">{device.platform}</td>
                      <td className="px-4 py-3">
                        {device.app_version ?? '—'}
                        {device.build_number ? ` (${device.build_number})` : ''}
                      </td>
                      <td className="px-4 py-3">
                        {device.device_label ?? '—'}
                        {device.store_id ? (
                          <div className="text-xs text-slate-500">
                            {truncate(device.store_id, 10)}
                          </div>
                        ) : null}
                      </td>
                      <td className="px-4 py-3 font-mono text-xs">
                        {device.ip_address ?? '—'}
                      </td>
                      <td className="px-4 py-3">{formatDate(device.first_seen)}</td>
                      <td className="px-4 py-3">{formatDate(device.last_seen)}</td>
                      <td className="px-4 py-3">
                        <StatusBadge
                          status={device.status}
                          blocked={device.is_blocked}
                        />
                      </td>
                      <td className="px-4 py-3">
                        {device.is_blocked ? (
                          <button
                            type="button"
                            disabled={actionId === device.device_id}
                            onClick={() => handleUnblock(device.device_id)}
                            className="rounded-lg border border-emerald-500/30 px-3 py-1.5 text-xs text-emerald-300 hover:bg-emerald-500/10 disabled:opacity-50"
                          >
                            Unblock
                          </button>
                        ) : (
                          <button
                            type="button"
                            disabled={actionId === device.device_id}
                            onClick={() => handleBlock(device.device_id)}
                            className="rounded-lg border border-rose-500/30 px-3 py-1.5 text-xs text-rose-300 hover:bg-rose-500/10 disabled:opacity-50"
                          >
                            Block
                          </button>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
