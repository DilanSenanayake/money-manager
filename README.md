# Ledgerly — Money Manager & Expense Tracker

Next.js 15 App Router money manager with Supabase Auth/RLS, Tesseract.js receipt OCR, and free-tier Gemini Flash for structuring receipts, SMS, and one-line notes.

> Full project write-up: **[DOCUMENTATION.md](./DOCUMENTATION.md)** (architecture, schema, features, setup checklist).

## Stack

- Next.js 15 + TypeScript + Tailwind CSS
- Supabase (PostgreSQL + Auth + RLS)
- Vercel AI SDK + `@ai-sdk/google` (`gemini-2.5-flash` / `gemini-2.5-flash-lite` only)
- Zod schemas shared by forms and `generateObject`
- Recharts analytics
- PWA (manifest + service worker)

## Setup

1. **Install**

```bash
npm install
```

2. **Environment**

Copy `.env.example` to `.env.local` and fill in:

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
GOOGLE_GENERATIVE_AI_API_KEY=
```

3. **Database**

In the Supabase SQL Editor, run [`supabase/migrations/001_initial.sql`](supabase/migrations/001_initial.sql).

4. **Auth**

In Supabase Auth settings, enable Email provider (email/password).

5. **Run**

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Mobile app

Native Flutter client lives in [`mobile/`](./mobile/). It uses the same Supabase project (Auth + RLS) directly — the Next.js backend is not modified. See [`mobile/README.md`](./mobile/README.md).

## Features

- **Quick Add (~30s):** scan receipt, paste bank SMS, type one line, or amount + category
- Multi-account wallets (cash, checking, savings, credit) with live balances
- Income / expense / transfer CRUD with filters
- Category budgets with 80% / 100% alerts
- Analytics: category pie + income vs expense trends
- Recurring transactions & upcoming bill dates
- Multi-currency base + manual exchange rates
- AI results always go through a confirm step before save
- PWA manifest + production service worker

## AI constraints

- Only free-tier Gemini Flash models
- Structured extraction via `generateObject` + Zod
- AI results never auto-save — review modal is required
- Paths: receipt (Tesseract OCR → Gemini text), bank SMS, natural-language one-liner

## License

Private / personal project unless otherwise stated.
