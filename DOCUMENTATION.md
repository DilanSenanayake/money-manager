# Ledgerly — Project Documentation

Complete record of what was built for the **Ledgerly** money manager & expense tracker.

---

## 1. Overview

Ledgerly is a full-stack personal finance web app focused on **logging income and expenses in about 30 seconds**. AI (receipt scan, bank SMS, one-line text) fills the form; the user always confirms before save. Accounts, budgets, analytics, and recurring bills support day-to-day tracking.

**Product name:** Ledgerly  
**App type:** Progressive Web App (PWA)  
**Auth:** Supabase Email/Password  
**Primary UX goal:** Add expense/income in ≤30 seconds with few taps  

---

## 2. Tech Stack

| Layer | Choice |
|--------|--------|
| Framework | Next.js 15 (App Router) + Turbopack |
| Language | TypeScript |
| UI | Tailwind CSS v4, Radix UI primitives, Lucide icons |
| Charts | Recharts |
| Auth & DB | Supabase (PostgreSQL, Auth, Row Level Security) |
| Validation | Zod (shared by forms and AI `generateObject`) |
| AI | Vercel AI SDK + `@ai-sdk/google` — **Gemini Flash free tier only** |
| Toasts | Sonner |
| Dates | date-fns |

### AI model constraints

Only free-tier Flash models are allowed:

- `gemini-2.5-flash` (preferred)
- `gemini-1.5-flash` (fallback)

Paid / Pro models are intentionally excluded in `src/lib/ai.ts`.

---

## 3. Features Delivered

### 3.1 Authentication

- Email/password **sign up** and **login** (`src/app/(auth)/`)
- Server actions in `src/app/actions/auth.ts`
- Middleware session refresh via `@supabase/ssr` (`src/middleware.ts`, `src/lib/supabase/middleware.ts`)
- Protected app routes under `src/app/(app)/`

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
- Actions: `src/app/actions/transactions.ts`

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
- Data helpers: `src/app/actions/dashboard.ts`

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
- Helpers: `src/lib/currency.ts`, `src/app/actions/settings.ts`

### 3.9 Quick Add (AI-first, ~30 seconds)

Primary entry: **`/add`** (mobile center FAB + sidebar “Add”).

| Path | Steps |
|------|--------|
| Scan receipt | Camera/gallery → Confirm → Save |
| Paste bank SMS | Paste/clipboard → Parse → Confirm → Save |
| Describe it | One line e.g. `Coffee 450` → Parse → Confirm → Save |
| Quick manual | Amount + category chip → Save (defaults: today, first account) |

- Confirm modal shows amount, type, category chips, account — extra fields under “More”
- AI never auto-saves
- `/import` redirects to `/add`
- Components: `quick-add-panel.tsx`, `ai-review-modal.tsx`
- Actions: `parseReceiptImage`, `parseBankSms`, `parseQuickText`, `saveReviewedTransaction`

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
├── public/
│   ├── icons/                 # PWA icons
│   ├── manifest.webmanifest
│   └── sw.js                  # Service worker
├── src/
│   ├── app/
│   │   ├── (app)/             # Authenticated app shell
│   │   │   ├── add/           # Quick Add hub (AI + manual)
│   │   │   ├── accounts/
│   │   │   ├── analytics/
│   │   │   ├── budgets/
│   │   │   ├── dashboard/
│   │   │   ├── import/        # Redirects to /add
│   │   │   ├── more/          # Secondary links (mobile)
│   │   │   ├── recurring/
│   │   │   ├── settings/
│   │   │   ├── transactions/
│   │   │   └── layout.tsx
│   │   ├── (auth)/
│   │   │   ├── login/
│   │   │   └── signup/
│   │   ├── actions/           # Server Actions
│   │   │   ├── accounts.ts
│   │   │   ├── ai.ts
│   │   │   ├── auth.ts
│   │   │   ├── categories.ts
│   │   │   ├── dashboard.ts
│   │   │   ├── settings.ts
│   │   │   └── transactions.ts
│   │   ├── layout.tsx
│   │   ├── page.tsx           # Marketing / landing
│   │   └── globals.css
│   ├── components/
│   │   ├── accounts/
│   │   ├── ai/
│   │   ├── analytics/
│   │   ├── budgets/
│   │   ├── layout/
│   │   ├── pwa/
│   │   ├── settings/
│   │   ├── transactions/
│   │   └── ui/                # Button, Card, Dialog, etc.
│   ├── lib/
│   │   ├── ai.ts              # Gemini Flash helpers
│   │   ├── currency.ts
│   │   ├── schemas.ts         # Zod schemas
│   │   ├── types.ts
│   │   ├── utils.ts
│   │   └── supabase/          # client, server, middleware
│   └── middleware.ts
└── supabase/
    └── migrations/
        └── 001_initial.sql    # Schema + RLS + triggers
```

---

## 5. Database Schema

Defined in `supabase/migrations/001_initial.sql`.

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

Copy `.env.example` → `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
GOOGLE_GENERATIVE_AI_API_KEY=your-google-ai-api-key
```

| Variable | Used for |
|----------|----------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Browser + server Supabase client |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Gemini Flash via AI SDK (receipt/SMS) |

Never commit `.env.local`.

---

## 7. Setup & Run

1. `npm install`
2. Configure `.env.local` (see above)
3. In Supabase SQL Editor, run `supabase/migrations/001_initial.sql`
4. Enable Email provider in Supabase Auth
5. Get a free Gemini API key from [Google AI Studio](https://aistudio.google.com/)
6. `npm run dev` → [http://localhost:3000](http://localhost:3000)

### Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Dev server (Turbopack) |
| `npm run build` | Production build |
| `npm start` | Start production server |
| `npm run lint` | ESLint |

---

## 8. Key Design Decisions

1. **30-second add first** — `/add` is the primary daily action; secondary tools live under More.  
2. **Server Actions over REST** — mutations live under `src/app/actions/` for type-safe Next.js data flow.  
3. **Shared Zod schemas** — same schemas validate UI input and AI `generateObject` output.  
4. **Human-in-the-loop AI** — extraction always goes through a review modal; nothing saves until the user confirms.  
5. **Flash-only AI** — keeps cost at free-tier; automatic fallback from 2.5 → 1.5 Flash.  
6. **Sensible defaults** — today, first account, AI category guess; user only fixes mistakes.  
7. **DB-owned balances** — triggers update balances so the app cannot drift from transaction history.  
8. **RLS by default** — every table is user-scoped; no service-role key in the client.  
9. **PWA-ready** — manifest + SW for installable / offline-capable shell.  

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

- [x] Next.js 15 + TypeScript + Tailwind project scaffold  
- [x] Supabase client/server/middleware helpers  
- [x] Auth pages + server actions  
- [x] Full SQL migration (tables, RLS, signup seed, balance triggers)  
- [x] Accounts management UI  
- [x] Transactions CRUD + filters + transfers  
- [x] Categories & budget tracking with alerts  
- [x] Dashboard summary + Quick Add launch pad  
- [x] Analytics charts (Recharts)  
- [x] Recurring transactions page  
- [x] Settings (profile, base currency, exchange rates)  
- [x] Quick Add hub: receipt, SMS, one-line text, manual  
- [x] Slim confirm modal (category chips, More for extras)  
- [x] Nav: Home / Add / Activity / More  
- [x] PWA manifest, icons, service worker  
- [x] Landing page branding (Ledgerly)  

---

## 11. Possible Next Steps (not implemented)

- Automated recurring transaction generation on schedule  
- Bank CSV import without AI  
- Shared household / multi-user households  
- Push notifications for budget overruns  
- End-to-end test suite  
- Remember last-used account as default  

---

*This document reflects the application including the 30-second Quick Add UX.*
