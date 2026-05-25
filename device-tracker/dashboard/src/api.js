const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:3000';

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
    ...options,
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.message || `Request failed (${response.status})`);
  }
  return data;
}

export function fetchDevices() {
  return request('/api/devices');
}

export function fetchStats() {
  return request('/api/stats');
}

export function blockDevice(deviceId, reason) {
  return request(`/api/devices/${deviceId}/block`, {
    method: 'PATCH',
    body: JSON.stringify({ reason }),
  });
}

export function unblockDevice(deviceId) {
  return request(`/api/devices/${deviceId}/unblock`, {
    method: 'PATCH',
  });
}

export { API_BASE };
