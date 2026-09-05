# Ledgerly — Project Documentation

Complete record of what was built for the **Ledgerly** money manager & expense tracker.

---

## 1. Overview

Ledgerly is a personal finance product focused on **logging income and expenses in about 30 seconds**. AI (receipt scan, bank SMS, one-line text) fills the form; the user always confirms before save. Accounts, budgets, analytics, and recurring bills support day-to-day tracking.

**Product name:** Ledgerly  
**Clients:** Progressive Web App (Next.js) + Flutter mobile  
**Shared backend:** ASP.NET Core 9 REST API (`apps/api`)  
**Auth:** Supabase Email/Password (JWT passed to API)  
**Primary UX goal:** Add expense/income in ≤30 seconds with few taps  

---

## 2. Tech Stack

| Layer | Choice |
|--------|--------|
| API | ASP.NET Core 9 (Web API) + JWT Bearer + Swagger |
| Web UI | Next.js 15 (App Router) + Turbopack + TypeScript |
| Mobile UI | Flutter + Riverpod + go_router |
| Auth & DB | Supabase (PostgreSQL, Auth, Row Level Security) |
| Validation | C# DataAnnotations (API); Zod still used in web transitional layer |
| AI | Google Gemini Flash free tier via API (`GeminiService`) |
| Charts (web) | Recharts |
| Toasts (web) | Sonner |
| Dates | date-fns (web); `DateHelpers` (API) |

### AI model constraints

Only free-tier Flash models are allowed:

- `gemini-2.5-flash` (preferred)
- `gemini-2.5-flash-lite` / `gemini-flash-latest` (fallback)

Configured in `apps/api` under `Gemini:Models`.

---

## 2b. Repository layout

```
money-manager/
├── apps/
│   ├── api/                 # BE  — ASP.NET Core REST API
│   │   ├── Dockerfile
│   │   ├── Ledgerly.sln
│   │   └── src/Ledgerly.Api/
│   ├── web/                 # FE  — Next.js web app
│   │   ├── src/
│   │   ├── public/
│   │   └── package.json
│   └── mobile/              # Mobile — Flutter
│       ├── lib/
│       └── pubspec.yaml
├── supabase/migrations/     # Shared DB schema + RLS
├── README.md
└── DOCUMENTATION.md
```

**Data flow**

1. Web/mobile sign in with Supabase Auth → access token  
2. Client calls `GET/POST …/v1/*` with `Authorization: Bearer <token>`  
3. API validates JWT (JWKS / optional legacy `Supabase:JwtSecret`)  
4. API calls Supabase PostgREST with the same JWT → **RLS enforced**  
5. AI parse endpoints use Gemini; secrets stay on the API  

**Migration status**

| Concern | Status |
|---------|--------|
| Shared REST API | ✅ Implemented in `apps/api` |
| Folder split BE / FE / mobile | ✅ `apps/api`, `apps/web`, `apps/mobile` |
| Web → API | ✅ Web Server Actions call Ledgerly.Api (`NEXT_PUBLIC_API_URL`) |
| Mobile → API | ⏳ Mobile still uses Supabase client for CRUD |
| Auth | ✅ Clients keep Supabase Auth |
| DB / RLS | ✅ Unchanged |

See [`apps/api/README.md`](./apps/api/README.md) for endpoints and run instructions.

---

## 3. Features Delivered

### 3.1 Authentication

- Email/password **sign up** and **login** (`apps/web/src/app/(auth)/`)
- Server actions in `apps/web/src/app/actions/auth.ts`
- Middleware session refresh via `@supabase/ssr` (`apps/web/src/middleware.ts`)
- Protected app routes under `apps/web/src/app/(app)/`

### 3.2 Multi-account wallets

- Account types: `cash`, `checking`, `savings`, `credit`
- CRUD UI: `src/components/accounts/accounts-manager.tsx`
- Page: `/accounts`
- Balances stay in sync via PostgreSQL triggers on transaction insert/update/delete

### 3.3 Transactions

- Types: `income`, `expense`, `transfer`
- Transfers create paired rows (`transfer_pair_id`, `transfer_direction`)
- Filters: search, account, category, type, date range
- Recurring flag + frequency (`weekly` / `monthly` / `yearly`)
- Page: `/transactions`
- Actions: `apps/web/src/app/actions/transactions.ts`

### 3.4 Categories & budgets

- Default categories seeded on signup (Salary, Groceries, Rent, etc.)
- Optional `monthly_budget` per expense category
- Budget progress with **80% warn** and **100% over** status
- Pages: `/budgets`
- Components: `budgets-manager.tsx`, `budget-bars.tsx`

### 3.5 Dashboard

- Launch pad: **Add expense**, **Scan receipt**, **Paste SMS**
- Empty-state guidance for first transaction
- Summary of balances, recent activity, and budget health
- Page: `/dashboard`
- Data helpers: `apps/web/src/app/actions/dashboard.ts`

### 3.6 Analytics

- Category spend pie chart
- Income vs expense trends
- Page: `/analytics`
- Component: `analytics-charts.tsx` (Recharts)

### 3.7 Recurring & bills

- List of recurring transactions and upcoming bill dates
- Page: `/recurring`

### 3.8 Settings & multi-currency

- Profile: display name + base currency
- Manual exchange rates (`exchange_rates` table)
- Supported currencies: USD, EUR, GBP, LKR, INR, JPY, AUD, CAD, CHF, SGD
- Page: `/settings`
- Helpers: `apps/web/src/lib/currency.ts`, `apps/web/src/app/actions/settings.ts`

### 3.9 Quick Add (AI-first, ~30 seconds)

Primary entry: **`/add`** (mobile center FAB + sidebar “Add”).

| Path | Steps |
|------|--------|
| Scan receipt | Tesseract OCR → Gemini text parse → Confirm → Save |
| Paste bank SMS | Paste/clipboard → Parse → Confirm → Save |
| Describe it | One line e.g. `Coffee 450` → Parse → Confirm → Save |
| Quick manual | Amount + category chip → Save (defaults: today, first account) |

- Confirm modal shows amount, type, category chips, account — extra fields under “More”
- AI never auto-saves
- `/import` redirects to `/add`
- Components: `quick-add-panel.tsx`, `ai-review-modal.tsx`
- Actions: `parseReceiptText` (after client OCR), `parseBankSms`, `parseQuickText`, `saveReviewedTransaction`
- Receipt pipeline: **Tesseract.js** (browser OCR) → Gemini Flash text-only `generateObject` → review modal
- Helper: `src/lib/ocr.ts` (`extractTextFromImage`)

### 3.10 PWA

- Web app manifest: `public/manifest.webmanifest`
- Icons: `public/icons/icon-192.png`, `icon-512.png`
- Service worker: `public/sw.js`
- Client registration: `src/components/pwa/sw-register.tsx`
- Standalone display, teal theme (`#0f766e`)

### 3.11 Layout & UX

- Desktop: Home / Add / Activity + More group (accounts, budgets, analytics, recurring, settings)
- Mobile: Home / Activity / **Add** (center) / More
- More page: `/more` for secondary destinations on mobile
- Landing page branding Ledgerly (`src/app/page.tsx`)

---

## 4. Application Structure

```
money-manager/
├── apps/
│   ├── api/                   # Backend (.NET)
│   │   ├── Dockerfile
│   │   ├── Ledgerly.sln
│   │   └── src/Ledgerly.Api/
│   │       ├── Controllers/   # /v1/* endpoints
│   │       ├── Services/
│   │       ├── Infrastructure/
│   │       ├── Models/
│   │       └── Helpers/
│   ├── web/                   # Frontend (Next.js)
│   │   ├── public/            # PWA assets
│   │   ├── src/
│   │   │   ├── app/           # routes + Server Actions (API proxy)
│   │   │   ├── components/
│   │   │   └── lib/
│   │   └── package.json
│   └── mobile/                # Mobile (Flutter)
│       ├── lib/
│       └── pubspec.yaml
└── supabase/migrations/       # Schema + RLS + triggers
```

---

## 5. Database Schema

Defined in `supabase/migrations/001_initial.sql` (plus later migrations).

Run in order:
1. `001_initial.sql`
2. `002_other_budget.sql`
3. `003_credit_balance_polarity.sql` — credit cards use positive “owed”; charges increase owed, payments decrease it

### Tables

| Table | Purpose |
|--------|---------|
| `profiles` | 1:1 with `auth.users` — base currency, display name |
| `accounts` | Wallets with type, balance, currency |
| `categories` | Income/expense categories + optional monthly budget |
| `transactions` | Income, expense, transfer rows |
| `exchange_rates` | Per-user manual FX rates |

### Triggers & functions

1. **`handle_new_user`** — on signup: create profile, seed default categories, create Cash + Checking accounts  
2. **`apply_transaction_balance`** — keep account balances correct on insert/update/delete  
3. **`set_updated_at`** — maintain `updated_at` on profiles and accounts  

### Security

- RLS enabled on all public tables  
- Policies restrict rows to `auth.uid() = user_id` (or `id` for profiles)  

---

## 6. Environment Variables

### Web (`.env.local` in `apps/web`)

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NEXT_PUBLIC_API_URL=http://localhost:5080
# NEXT_PUBLIC_API_URL=http://<vm-host>:8080   # local FE → remote API
```

### API (`apps/api` — env or appsettings)

```env
Supabase__Url=https://your-project.supabase.co
Supabase__AnonKey=your-anon-key
# Optional legacy HS256 only — asymmetric keys use JWKS automatically from Url
# Supabase__JwtSecret=your-legacy-jwt-secret
Gemini__ApiKey=your-google-ai-api-key
```

Never commit secrets. With asymmetric JWT signing keys (default on newer Supabase projects), the API validates tokens via JWKS — do not put a signing-key id in `JwtSecret`.

---

## 7. Setup & Run

### API

1. Install [.NET 9 SDK](https://dotnet.microsoft.com/download)
2. Configure Supabase + Gemini (see §6 / `apps/api/.env.example`)
3. `cd apps/api/src/Ledgerly.Api && dotnet run`
4. Swagger: http://localhost:5080/swagger

### Web

1. `cd apps/web && npm install`
2. Configure `apps/web/.env.local` (see §6) — set `NEXT_PUBLIC_API_URL` to local API or VM
3. In Supabase SQL Editor, run `supabase/migrations/001_initial.sql`
4. Enable Email provider in Supabase Auth
5. `npm run dev` → http://localhost:3000

Local FE against a VM API: set `NEXT_PUBLIC_API_URL=http://<vm-host>:8080` and keep Supabase env pointing at the same project the VM uses.

### Scripts (web)

| Command | Description |
|---------|-------------|
| `npm run dev` | Dev server (Turbopack) |
| `npm run build` | Production build |
| `npm start` | Start production server |
| `npm run lint` | ESLint |

### Scripts (API)

| Command | Description |
|---------|-------------|
| `dotnet run` | Run API (port 5080) |
| `dotnet build` | Build |
| `docker build -t ledgerly-api .` | From `apps/api/` |

---

## 8. Key Design Decisions

1. **Shared .NET API** — web and mobile share one REST backend (`apps/api`); business logic lives once.  
2. **30-second add first** — `/add` is the primary daily action; secondary tools live under More.  
3. **Supabase Auth + JWT to API** — clients login with Supabase; API validates and forwards the token for RLS.  
4. **Human-in-the-loop AI** — extraction always goes through a review step; nothing saves until the user confirms.  
5. **Flash-only AI** — keeps cost at free-tier; automatic fallback across Flash models.  
6. **DB-owned balances** — triggers update balances so the app cannot drift from transaction history.  
7. **RLS by default** — every table is user-scoped; no service-role key in clients.  
8. **PWA-ready web** — manifest + SW for installable / offline-capable shell.  
9. **Thin Server Actions** — Next.js `apps/web/src/app/actions/` forward to Ledgerly.Api with the Supabase JWT; auth stays on Supabase.  

---

## 9. Routes Map

| Path | Access | Description |
|------|--------|-------------|
| `/` | Public | Landing |
| `/login` | Public | Sign in |
| `/signup` | Public | Register |
| `/dashboard` | Auth | Home / launch pad |
| `/add` | Auth | Quick Add (AI + manual) |
| `/transactions` | Auth | Activity / full ledger |
| `/more` | Auth | Secondary destinations |
| `/accounts` | Auth | Wallets |
| `/budgets` | Auth | Category budgets |
| `/analytics` | Auth | Charts |
| `/recurring` | Auth | Recurring / bills |
| `/import` | Auth | Redirects to `/add` |
| `/settings` | Auth | Profile & FX rates |

---

## 10. What Was Built (Checklist)

- [x] ASP.NET Core 9 shared API (`apps/api`) with JWT + `/v1` resources + AI  
- [x] Docker support for API deploy  
- [x] Next.js 15 + TypeScript + Tailwind project scaffold  
- [x] Supabase client/server/middleware helpers  
- [x] Auth pages + server actions (Supabase auth; data via API)  
- [x] Full SQL migration (tables, RLS, signup seed, balance triggers)  
- [x] Accounts / transactions / budgets / dashboard / analytics / settings (web)  
- [x] Quick Add hub: receipt, SMS, one-line text, manual  
- [x] Flutter mobile scaffold (direct Supabase CRUD; API next)  
- [x] PWA manifest, icons, service worker  
- [x] Wire Next.js UI to Ledgerly.Api (`NEXT_PUBLIC_API_URL`)  
- [ ] Wire Flutter repositories to Ledgerly.Api  

---

## 11. Possible Next Steps

- Point Flutter repositories at the same REST API (keep Supabase only for auth)  
- Optionally call Ledgerly.Api from the browser (drop Server Action proxy)  
- Automated recurring transaction generation on schedule  
- Bank CSV import without AI  
- Shared household / multi-user households  
- Push notifications for budget overruns  
- End-to-end test suite  
- Remember last-used account as default  

---

*This document reflects the application including the ASP.NET Core shared-API architecture.*
