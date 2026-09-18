# Production guide — Smart Money Manager

This document is specific to this repository. Product overview lives in [DOCUMENTATION.md](./DOCUMENTATION.md). Use [PRODUCTION_CHECKLIST.md](./PRODUCTION_CHECKLIST.md) before going live.

## 1. Application architecture

Three clients share one data plane:

| Layer | Path | Stack | Production host |
|-------|------|--------|-----------------|
| Web | `apps/web` | Next.js 15 App Router, Server Actions, Supabase Auth | Vercel (Root Directory `apps/web`) |
| API | `apps/api` | ASP.NET Core 9 REST (`/v1/*`) | Docker on a VM / container platform behind TLS |
| Mobile | `apps/mobile` | Flutter | Not production-wired to the API yet (still talks to Supabase directly) |
| DB / Auth | `supabase/migrations` | Postgres + RLS + Auth | Supabase project |

```
Browser (Next.js) --Server Action + JWT--> Ledgerly.Api --user JWT + anon key--> Supabase PostgREST (RLS)
Flutter (current) --------------------Supabase JS/client----------------------> Supabase
```

The API is a **stateless BFF**. It never uses the Supabase service-role key. Business writes go through PostgREST with the caller's JWT so row-level security still applies. Groq is used only from the API for `/v1/ai/*`.

Web mutations never call the API from the browser today. CORS exists so a future browser client (or Flutter web) can call the API directly.

## 2. Required environment variables

Never put real secrets in git. Copy from the example files:

- Web: `apps/web/.env.example` → `apps/web/.env.local` (local) or Vercel project env
- API: `apps/api/.env.example` → `appsettings.Development.json` (local, gitignored) or Docker `--env-file`

### Web (`apps/web`)

| Variable | Required | Notes |
|----------|----------|--------|
| `NEXT_PUBLIC_SUPABASE_URL` | Yes | Same Supabase project as the API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Yes | Publishable anon key (RLS-backed) |
| `API_URL` | Yes (preferred) | Server-only origin of Ledgerly.Api, no trailing slash, **HTTPS in production** |
| `NEXT_PUBLIC_API_URL` | Fallback | Still read if `API_URL` is unset (existing Vercel setups) |
| `NEXT_PUBLIC_SITE_URL` | Recommended | Canonical site origin, e.g. `https://app.example.com` |
| `NEXT_PUBLIC_GA_MEASUREMENT_ID` | Optional | GA4 ID (`G-…`). Vercel Web Analytics needs the dashboard toggle; the app already injects the script. |

### API (`apps/api`)

ASP.NET Core binds nested config with `__`.

| Variable | Required in production | Notes |
|----------|------------------------|--------|
| `ASPNETCORE_ENVIRONMENT` | Yes | Must be `Production` |
| `Supabase__Url` | Yes | Fail-fast if missing in Production |
| `Supabase__AnonKey` | Yes | Fail-fast if missing in Production |
| `Cors__Origins__0` (+ `__1`, …) | Yes | Exact web origins, e.g. `https://your-app.vercel.app`. API will not start if empty. |
| `Groq__ApiKey` | If using Smart Add AI | Parse endpoints fail closed with a safe message if unset |
| `Supabase__JwtSecret` | Only for legacy HS256 Auth | Do **not** set this to a signing-key UUID. Newer projects validate via JWKS from `Supabase__Url`. |
| `ASPNETCORE_URLS` | Docker default | Image listens on `http://+:8080` |
| `Groq__BaseUrl` / `Groq__Models__N` | Optional | Defaults are in `appsettings.json` |

The Docker image sets `ASPNETCORE_ENVIRONMENT=Production`. Override only if you know you need another environment.

## 3. Local production-like setup

1. Apply SQL migrations in order in the Supabase SQL editor (see §4).
2. Enable Email auth in Supabase. Add `http://localhost:3000/**` to Redirect URLs.
3. API:

```bash
cd apps/api/src/Ledgerly.Api
# copy appsettings.Development.json.example → appsettings.Development.json
dotnet run
```

4. Web:

```bash
cd apps/web
cp .env.example .env.local
npm install
npm run build
npm start
```

Or run the API in Docker against the same env file you will use in production (minus localhost CORS if you only allow the production origin).

## 4. Database setup

Run **in order**, once per environment. Never edit an already-applied file — add `005_….sql` instead.

1. `supabase/migrations/001_initial.sql` — tables, RLS, signup seed, balance triggers
2. `supabase/migrations/002_other_budget.sql`
3. `supabase/migrations/003_credit_balance_polarity.sql`
4. `supabase/migrations/004_production_hardening.sql` — ownership trigger, UPDATE `WITH CHECK`, composite indexes

No additional index migration is required for launch. Existing indexes cover `user_id`, `(user_id, date)`, and `(user_id, category_id, date)`.

**PostgREST max rows:** dashboard month queries request up to 2,000 rows and analytics up to 5,000. If the project's "Max rows" setting is below that (Supabase default is often 1,000), monthly totals can truncate. Raise it in the Supabase API settings if a user can exceed that many transactions in the window.

The API does not open Postgres connections; pooling is entirely on the Supabase/PostgREST side.

## 5. Build commands

### API

```bash
cd apps/api
dotnet test --configuration Release
dotnet publish src/Ledgerly.Api/Ledgerly.Api.csproj -c Release
# or
docker build -t ledgerly-api .
```

### Web

```bash
cd apps/web
npm ci
npm run lint
npm test
npx tsc --noEmit
npm run build
npm start
```

## 6. Deployment steps

### A. Supabase

1. Create/use one project for web + API.
2. Run migrations 001–004.
3. Authentication → URL configuration: add the production web origin and `https://<your-domain>/**` redirect URLs.
4. Enable Point-in-Time Recovery or scheduled backups (paid) — or cron `pg_dump` on the free tier.
5. Confirm Email provider is on; customize templates if users will see them.

### B. API (Docker VM — matches this repo's existing path)

TLS belongs on Caddy/Nginx/a cloud load balancer in front of port 8080. Do not expose raw HTTP to the public internet.

```bash
cd ~/money-manager && git pull
cd apps/api
docker build -t ledgerly-api .
docker stop ledgerly-api && docker rm ledgerly-api
docker run -d --name ledgerly-api --restart unless-stopped \
  -p 127.0.0.1:8080:8080 \
  --env-file ~/ledgerly-api.env \
  ledgerly-api
```

Bind to `127.0.0.1` when a reverse proxy on the same host terminates TLS. Open `0.0.0.0:8080` only if the platform firewall + TLS proxy sits elsewhere.

Example `~/ledgerly-api.env` (no secrets in git):

```env
ASPNETCORE_ENVIRONMENT=Production
Supabase__Url=https://your-project.supabase.co
Supabase__AnonKey=your-anon-key
Groq__ApiKey=your-groq-api-key
Cors__Origins__0=https://your-app.vercel.app
Cors__Origins__1=https://your-custom-domain.com
```

The reverse proxy **must overwrite** incoming `X-Forwarded-For` / `X-Forwarded-Proto`. The API trusts those headers so per-user rate limits and HTTPS detection work behind the proxy.

### C. Web (Vercel)

1. Import the GitHub repo.
2. Root Directory: `apps/web`.
3. Framework preset: Next.js (see `apps/web/vercel.json`).
4. Set env vars from §2. Prefer `API_URL=https://api.yourdomain.com`.
5. Deploy. Confirm login → dashboard → add a transaction.

`apps/web` Server Actions call the API from Vercel's network. The API host must be reachable from Vercel (public HTTPS or a private path you have configured).

## 7. Required external services

| Service | Used for |
|---------|----------|
| Supabase | Auth JWTs, Postgres, PostgREST, RLS |
| Groq | Optional AI parse (`/v1/ai/parse-*`) |
| Vercel | Web hosting |
| TLS reverse proxy | HTTPS for the API |
| (Optional) Sentry | Error monitoring — not wired; add a DSN when you have one |

## 8. Domain / HTTPS

- Web: Vercel issues HTTPS for `*.vercel.app` and attached custom domains.
- API: put Caddy or Nginx in front. Example Caddy:

```
api.yourdomain.com {
  reverse_proxy 127.0.0.1:8080
}
```

- Set `API_URL` / `NEXT_PUBLIC_API_URL` to that `https://` origin.
- Set `Cors__Origins__*` to the exact web origins (scheme + host, no path).
- Mixed content: if the web app is HTTPS, the API must be HTTPS too (even though today's fetch is server-side, tokens still traverse that hop).

## 9. Health-check endpoints

| Endpoint | Auth | Meaning |
|----------|------|---------|
| `GET /health` | Anonymous | Process is up (liveness). Independent of Supabase. |
| `GET /health/ready` | Anonymous | Supabase REST host responds with HTTP < 500. |

Docker `HEALTHCHECK` hits `/health`. Point a load balancer liveness probe at `/health` and readiness at `/health/ready`.

```bash
curl -fsS https://api.yourdomain.com/health
curl -fsS https://api.yourdomain.com/health/ready
```

## 10. Monitoring / logging recommendations

- API logs to stdout (container logs). Production default: Warning globally, Information for `Ledgerly.Api`.
- Every response includes `X-Request-Id` (incoming header or ASP.NET `TraceIdentifier`). Unhandled exceptions log `{RequestId}`.
- Do not log JWTs, Groq keys, or raw bank SMS / OCR in new code. Groq failures are logged server-side; clients get generic AI messages.
- Add Sentry (or equivalent) for Next.js + ASP.NET when you have a production DSN. Error boundaries today only `console.error`.
- Watch 429s (global 120 req/min/user, AI 20/min/user), 401 spikes, and `/health/ready` 503s.
- Web traffic: Vercel Web Analytics (enable in the project) plus optional GA4 via `NEXT_PUBLIC_GA_MEASUREMENT_ID`.
- `npm audit` on Next 15.5.25 still reports a nested `postcss` advisory. Fixing it requires Next 16 (breaking). Do not `npm audit fix --force`. Vitest's `@vitest/mocker` advisory is **dev-only**.

## 11. Backup recommendations

- **Supabase paid:** enable PITR.
- **Supabase free:** nightly `pg_dump` of `public` (and auth if required) to object storage you control.
- Test a restore once before launch.
- Treat Groq and Supabase keys as rotatable; keep the Docker env file off the repo disk backups that get copied around.

## 12. Rollback procedure

### API (Docker)

Keep the previous image tag:

```bash
docker build -t ledgerly-api:$(git rev-parse --short HEAD) .
docker tag ledgerly-api:PREVIOUS ledgerly-api:rollback   # after a known-good deploy
# rollback:
docker stop ledgerly-api && docker rm ledgerly-api
docker run -d --name ledgerly-api --restart unless-stopped \
  -p 127.0.0.1:8080:8080 \
  --env-file ~/ledgerly-api.env \
  ledgerly-api:rollback
curl -fsS http://127.0.0.1:8080/health
```

SQL: do not roll back `001`–`004` on a live database. If a future `005` is bad, write `006` that undoes it.

### Web (Vercel)

Use Vercel → Deployments → Promote an earlier production deployment.

## 13. Common production troubleshooting

| Symptom | Likely cause | What to do |
|---------|--------------|------------|
| API container exits immediately | Missing `Supabase__Url` / `AnonKey` or empty `Cors__Origins` | `docker logs ledgerly-api` |
| `401` on every `/v1/*` | JWT issuer mismatch, or `JwtSecret` set to a UUID kid | Leave `Supabase__JwtSecret` unset; confirm `Supabase__Url` matches the project that issued the token |
| CORS errors in the browser | Origin not in `Cors__Origins__*` | Add the exact `https://` origin; restart API |
| Web login works, data fails | `API_URL` unreachable from Vercel, or HTTP blocked | `curl` the API from a public host; require HTTPS |
| Dashboard numbers look low | PostgREST max rows truncating | Raise max rows; heavy users can exceed 1,000 txs/month |
| AI parse always errors | Missing/invalid `Groq__ApiKey` or model names | Check API logs; confirm models in `Groq__Models` |
| Users bounced to `/login` | Middleware `getUser()` timeout or cookie domain | Confirm Supabase URL/key; check Auth redirect URLs |
| Stale PWA after deploy | Old service worker | `sw.js` is `ledgerly-v3` and skips caching navigations; users may need one refresh |
| Rate limit hits everyone | Proxy not sending `X-Forwarded-For` | Fix forwarded headers on Caddy/Nginx |

## Query limits (API)

These are caps in application code, not schema changes:

- Transaction list: 200 rows
- Recurring list: 200 rows
- Dashboard month: 2,000 rows
- Analytics (6 months): 5,000 rows

Request body max: 1 MB (Kestrel).

## What is intentionally not changed

- Flutter still uses Supabase for CRUD (`DOCUMENTATION.md`). Do not point mobile at the API until that work is done.
- No Sentry DSN is hardcoded.
- No major dependency upgrades.
- No destructive SQL.
