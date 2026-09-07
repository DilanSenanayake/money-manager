# Smart Money Manager

Spend smarter. Save better. Live better. An intelligent personal finance app with a clear split between **backend**, **web**, and **mobile**, plus shared Supabase data.

> Full write-up: **[DOCUMENTATION.md](./DOCUMENTATION.md)**

## Folder tree

```
money-manager/
├── apps/
│   ├── api/          # BE  — ASP.NET Core 9 REST API
│   ├── web/          # FE  — Next.js 15 web app
│   └── mobile/       # Mobile — Flutter (Android / iOS)
├── supabase/         # Shared DB migrations (Auth + Postgres + RLS)
├── README.md
└── DOCUMENTATION.md
```

| App | Path | Stack |
|-----|------|--------|
| **Backend** | [`apps/api`](./apps/api) | ASP.NET Core 9, JWT, Groq AI, Swagger |
| **Frontend** | [`apps/web`](./apps/web) | Next.js 15, TypeScript, Tailwind |
| **Mobile** | [`apps/mobile`](./apps/mobile) | Flutter, Riverpod |
| **Database** | [`supabase`](./supabase) | Postgres migrations + RLS |

```
┌─────────────┐     ┌─────────────┐
│  apps/web   │     │ apps/mobile │
│  (Next.js)  │     │  (Flutter)  │
└──────┬──────┘     └──────┬──────┘
       │  JWT + REST       │
       └────────┬──────────┘
                ▼
       ┌────────────────┐
       │   apps/api     │  ASP.NET Core
       └────────┬───────┘
                │
       ┌────────┴────────┐
       ▼                 ▼
  Supabase Auth     Supabase Postgres
```

Clients sign in with **Supabase Auth**, then call the API with `Authorization: Bearer <token>`.

## Quick start

### 1. Database

In the Supabase SQL Editor, run [`supabase/migrations/001_initial.sql`](supabase/migrations/001_initial.sql). Enable Email auth.

### 2. Backend — `apps/api`

```bash
cd apps/api/src/Ledgerly.Api
# Configure appsettings.Development.json — see apps/api/.env.example
dotnet run
```

Swagger: [http://localhost:5080/swagger](http://localhost:5080/swagger)

### 3. Frontend — `apps/web`

```bash
cd apps/web
cp .env.example .env.local   # Supabase + NEXT_PUBLIC_API_URL (local or VM)
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

For a remote API: set `NEXT_PUBLIC_API_URL=http://<vm-host>:8080` (same Supabase project as the VM).

### 4. Mobile — `apps/mobile`

```bash
cd apps/mobile
cp .env.example .env
flutter pub get
flutter run
```

See [`apps/mobile/README.md`](./apps/mobile/README.md).

## Features

- Quick Add: receipt OCR → Groq, bank SMS, one-line text, or manual
- Multi-account wallets with live balances (DB triggers)
- Income / expense / transfer CRUD
- Category budgets with 80% / 100% alerts
- Analytics + recurring bills
- Multi-currency + manual exchange rates
- AI never auto-saves — confirm step required

## License

Private / personal project unless otherwise stated.
