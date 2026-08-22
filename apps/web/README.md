# Ledgerly Web (Frontend)

Next.js 15 App Router UI for Ledgerly. Auth via Supabase; data/AI should call [`../api`](../api) (`NEXT_PUBLIC_API_URL`).

## Setup

```bash
cp .env.example .env.local
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Dev server (Turbopack) |
| `npm run build` | Production build |
| `npm start` | Start production server |
| `npm run lint` | ESLint |

## Note

Server Actions under `src/app/actions/` are **transitional**. Prefer the shared ASP.NET API in `apps/api`.
