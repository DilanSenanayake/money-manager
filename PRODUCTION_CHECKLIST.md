# Production checklist — Smart Money Manager

Use this before the first production cutover and after each release. Details: [PRODUCTION.md](./PRODUCTION.md).

## Platform

- [ ] Environment variables configured (web + API)
- [ ] Secrets removed from repository (no `.env`, no `appsettings.Development.json`, no Groq/Supabase secrets in git)
- [ ] Production database configured (one Supabase project for web + API)
- [ ] Database migrations completed (`001` → `004` in order)
- [ ] PostgREST / Supabase **max rows** reviewed (raise above 1,000 if users can exceed that many transactions in a month)
- [ ] Authentication verified (sign up, email confirm if enabled, login, logout)
- [ ] Authorization verified (user A cannot read/update user B rows; RLS + API ownership checks)
- [ ] CORS configured (`Cors__Origins__*` = exact production web origins)
- [ ] HTTPS configured (Vercel for web; reverse proxy TLS for API)
- [ ] Security headers configured (web `next.config.ts`; API middleware)
- [ ] Error handling verified (no stack traces or secrets in API/JSON responses)
- [ ] Logging configured (container stdout; `X-Request-Id` present)
- [ ] Health check verified (`GET /health` and `GET /health/ready`)
- [ ] Frontend production build verified (`cd apps/web && npm run build && npm start`)
- [ ] Backend production build verified (`docker build` or `dotnet publish -c Release`)
- [ ] Tests passing (`dotnet test`, `npm test`, `npm run lint`, `npx tsc --noEmit`)
- [ ] Dependencies reviewed (`npm audit`, `dotnet list package --vulnerable` if credentials allow)
- [ ] Backups configured (Supabase PITR or scheduled `pg_dump`)
- [ ] Monitoring configured (at least log drain + optional Sentry)
- [ ] Domain configured (web custom domain; `api.` hostname)
- [ ] Rollback procedure tested (previous Docker image tag + Vercel prior deployment)

## This application

- [ ] `API_URL` (or `NEXT_PUBLIC_API_URL`) is `https://` and reachable from Vercel
- [ ] `NEXT_PUBLIC_SITE_URL` is `https://www.smoneymanager.com`
- [ ] Vercel Web Analytics enabled on the project
- [ ] `NEXT_PUBLIC_GA_MEASUREMENT_ID` set if using Google Analytics (`G-…`)
- [ ] Supabase Auth redirect URLs include the production domain
- [ ] `Supabase__JwtSecret` is **unset** unless Auth is still HS256 (never a signing-key UUID)
- [ ] Groq key set if Smart Add (receipt / SMS / text) is required
- [ ] Reverse proxy overwrites `X-Forwarded-For` and `X-Forwarded-Proto`
- [ ] API published as non-root Docker user; container `HEALTHCHECK` is healthy
- [ ] API bound to localhost or a private network when TLS terminates on the same VM
- [ ] PWA: hard-refresh once after deploy so `ledgerly-v3` service worker replaces the previous cache
- [ ] Receipt scan works in production (camera permission + Tesseract; CSP `wasm-unsafe-eval`)
- [ ] Rate limits observed (120/min global, 20/min AI) per authenticated user
- [ ] Privacy policy / terms published if this handles other people's financial data
- [ ] Flutter mobile **not** advertised as production API client until it is wired to `apps/api`
- [ ] Exchange rates entered for any non-base-currency accounts (missing rate currently converts 1:1)
- [ ] Restore from backup tested once
