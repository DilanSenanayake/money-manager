# Ledgerly API — Backend (ASP.NET Core 9)

Shared REST backend for the Next.js web app (`apps/web`) and Flutter mobile app (`apps/mobile`).
Talks to Supabase (Postgres + Auth JWT + RLS) and Groq (free-tier LLM) for AI parse endpoints.

## Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- Supabase project (same as web/mobile)
- Optional: [Groq API key](https://console.groq.com/keys) for `/v1/ai/*`

## Configuration

Copy values into `src/Ledgerly.Api/appsettings.Development.json` or set env vars:

| Env var | Purpose |
|---------|---------|
| `Supabase__Url` | Supabase project URL (required for PostgREST + JWKS) |
| `Supabase__AnonKey` | Anon/publishable key |
| `Supabase__JwtSecret` | Optional HS256 secret; use with Url when Auth is HS256-only (JWKS empty). Not a signing-key UUID. |
| `Groq__ApiKey` | Groq API key (free tier) |
| `Cors__Origins__0` | Allowed web origin (e.g. `http://localhost:3000`) |

See [`.env.example`](./.env.example).

## Run locally

```bash
cd apps/api/src/Ledgerly.Api
dotnet restore
dotnet run
```

Swagger UI: [http://localhost:5080/swagger](http://localhost:5080/swagger)

Health: [http://localhost:5080/health](http://localhost:5080/health)

## Auth

Clients sign in with **Supabase Auth**, then send:

```
Authorization: Bearer <supabase_access_token>
```

The API is **stateless** (no server sessions). It validates the Supabase access JWT (JWKS and/or legacy HS256 secret), requires `role=authenticated`, and forwards the same Bearer token to PostgREST so **RLS still applies**.

## Endpoints (v1)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/accounts` | List accounts |
| POST | `/v1/accounts` | Create account |
| PATCH | `/v1/accounts/{id}` | Update account |
| DELETE | `/v1/accounts/{id}` | Delete account |
| GET | `/v1/categories` | List categories |
| POST/PATCH/DELETE | `/v1/categories` | Category CRUD |
| GET | `/v1/transactions` | List (filters: q, account_id, category_id, type, from, to) |
| GET | `/v1/transactions/recurring` | Recurring only |
| POST/PATCH/DELETE | `/v1/transactions` | Transaction CRUD (+ transfers) |
| GET | `/v1/dashboard` | Dashboard summary |
| GET | `/v1/dashboard/analytics` | Charts data |
| GET | `/v1/dashboard/budgets` | Budget progress |
| GET/PATCH | `/v1/settings/profile` | Profile |
| GET/PUT/DELETE | `/v1/settings/exchange-rates` | FX rates |
| POST | `/v1/ai/parse-receipt` | OCR text → structured draft |
| POST | `/v1/ai/parse-sms` | Bank SMS → draft |
| POST | `/v1/ai/parse-text` | One-liner → draft |
| POST | `/v1/ai/save-reviewed` | Persist after user confirm |

## Docker

```bash
cd apps/api
docker build -t ledgerly-api .
docker run -d --name ledgerly-api --restart unless-stopped \
  -p 8080:8080 \
  --env-file ~/ledgerly-api.env \
  ledgerly-api
```

Example `~/ledgerly-api.env`:

```env
Supabase__Url=https://your-project.supabase.co
Supabase__AnonKey=your-anon-key
Groq__ApiKey=your-groq-api-key
Cors__Origins__0=http://localhost:3000
Cors__Origins__1=http://127.0.0.1:3000
```

## Deploy

Any Docker host works (Railway, Render, Fly.io, Azure Container Apps, Oracle Cloud VM).
Set the env vars above and point web/mobile at the public API URL.

### Redeploy on VM (Docker)

Assumes: repo at `~/money-manager`, env at `~/ledgerly-api.env`, container name `ledgerly-api`, port **8080**.

```bash
ssh -i /path/to/your-ssh-key ubuntu@<vm-host>

cd ~/money-manager && git pull
cd apps/api
docker build -t ledgerly-api .
docker stop ledgerly-api && docker rm ledgerly-api
docker run -d --name ledgerly-api --restart unless-stopped \
  -p 8080:8080 \
  --env-file ~/ledgerly-api.env \
  ledgerly-api

curl http://127.0.0.1:8080/health
```

From your PC: `curl http://<vm-host>:8080/health`. Firewall must allow TCP **8080**.

Full notes: [`DOCUMENTATION.md`](../../DOCUMENTATION.md#redeploy-api-on-a-docker-vm).
