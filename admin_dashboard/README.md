# FindMeTricycle Admin Dashboard

Web dashboard for LGU/admin operations:

- Admin login
- Driver approval/rejection with document links
- Fare setting management
- Live map for online drivers and active rides
- Dashboard summary (rides, daily earnings, active drivers)

## Setup

1. Copy `.env.example` to `.env`.
2. Install dependencies:
   - `npm install`
3. Run dev server:
   - `npm run dev`
4. Open:
   - `http://localhost:5173`

## Environment Variables

- `VITE_API_BASE_URL` -> API base URL. Use `/api` for local dev with the Vite proxy, or a full URL like `https://example.ngrok-free.app/api` when pointing to a separate backend.
- `VITE_SOCKET_URL` -> backend socket URL. Leave blank to use the same origin, or set a full URL like `https://example.ngrok-free.app`.
- `VITE_GOOGLE_MAPS_API_KEY` -> Google Maps JavaScript API key

## Notes

- Admin user must exist in backend database.
- Login only accepts users with `role = admin`.
- The map still loads dashboard tables even without Google API key.
- `npm run dev` now proxies `/api`, `/uploads`, and `/socket.io` to `http://127.0.0.1:5000`, so `ngrok http 5173` can expose the full admin app through one public URL while the backend stays local.
