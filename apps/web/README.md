# Smart Money Manager Web (Frontend)

Next.js 15 App Router UI for Smart Money Manager. Auth via Supabase; data and AI go through [`../api`](../api) (`NEXT_PUBLIC_API_URL`).

## Setup

```bash
cp .env.example .env.local
# Set NEXT_PUBLIC_API_URL to local API or your VM, e.g.:
#   http://localhost:5080
#   http://<vm-ip>:8080
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

Server Actions under `src/app/actions/` call the ASP.NET API with your Supabase access token (Bearer). Auth (sign-in/up/out) stays on Supabase.

Ensure the API allows CORS origin `http://localhost:3000` if you later call it from the browser; server-side actions do not need CORS.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Dev server (Turbopack) |
| `npm run build` | Production build |
| `npm start` | Start production server |
| `npm run lint` | ESLint |
