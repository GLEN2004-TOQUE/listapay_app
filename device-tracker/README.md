# ListaPay Device Tracker

Monitor every phone that installs ListaPay, detect shared APK copies, and block unauthorized devices from a web dashboard.

## Architecture

```text
Flutter App (Android/iOS)
    ↓ POST /api/register-device
Node.js API (Express)
    ↓ PostgreSQL or in-memory store
React Dashboard (Vite + Tailwind)
```

The Flutter app reuses the existing SHA-256 device fingerprint (`DeviceFingerprintService` + `DeviceIdGenerator`). Each phone gets a stable ID from Android ID or iOS `identifierForVendor`.

## Quick start (local)

### 1. Start the API

```bash
cd device-tracker/server
npm install
npm run dev
```

The server runs at `http://localhost:3000`. Without `DATABASE_URL`, it uses an in-memory store (fine for testing).

### 2. Start the dashboard

```bash
cd device-tracker/dashboard
npm install
npm run dev
```

Open `http://localhost:5173`. The dashboard polls every 10 seconds.

### 3. Run the Flutter app with tracker enabled

Use your machine's LAN IP so a physical phone can reach the API:

```bash
flutter run --dart-define=DEVICE_TRACKER_URL=http://192.168.1.10:3000
```

On Android emulator, use `http://10.0.2.2:3000`.

## PostgreSQL (production)

```bash
cd device-tracker/server
cp .env.example .env
# Edit DATABASE_URL, then:
npm run db:init
npm start
```

Schema lives in `device-tracker/server/db/schema.sql`.

## API endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/register-device` | Register or update a device heartbeat |
| GET | `/api/devices` | List all devices |
| GET | `/api/devices/:id/status` | Check if a device is blocked |
| GET | `/api/stats` | Aggregate counts |
| PATCH | `/api/devices/:id/block` | Block a device |
| PATCH | `/api/devices/:id/unblock` | Unblock a device |

### Register payload (from Flutter)

```json
{
  "device_id": "a81c2f991ab81e...",
  "platform": "Android",
  "app_version": "1.0.0",
  "build_number": "1",
  "store_id": "optional-store-uuid",
  "user_id": "optional-local-user-id",
  "device_label": "POS Device"
}
```

The server captures the client IP automatically.

## Flutter integration

The tracker runs automatically when `DEVICE_TRACKER_URL` is set:

- **App launch** — after local device binding passes
- **User login** — sends `user_id` with the heartbeat
- **Reconnect** — when connectivity returns after being offline

If the server returns `blocked: true`, the app shows `DeviceBlockedScreen`.

Key files:

- `lib/core/config/device_tracker_config.dart`
- `lib/data/services/device_tracker_service.dart`
- `lib/app.dart` (bootstrap + login hooks)

## Shared APK detection

When the same APK is sideloaded to another phone:

1. Phone B generates a **different** device ID (different Android ID / vendor ID)
2. The server registers it as a **new device**
3. If both devices share the same `store_id`, the newer one is flagged **suspicious**

Use the dashboard **Block** button to revoke access.

## Deployment

| Component | Suggested host |
|-----------|----------------|
| API | Railway, Render, VPS |
| Database | Supabase Postgres, Neon, Railway Postgres |
| Dashboard | Vercel, Netlify |

Set `VITE_API_URL` when building the dashboard:

```bash
VITE_API_URL=https://your-api.example.com npm run build
```

Set `CORS_ORIGIN` on the API to your dashboard URL.

## Security notes

- Device IDs can change after factory reset
- Do not rely on device ID alone — combine with account login and server verification
- Use HTTPS in production
- Consider adding an admin API key before exposing the dashboard publicly
