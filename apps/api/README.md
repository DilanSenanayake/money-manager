# Ledgerly API — Backend (ASP.NET Core 9)

Shared REST backend for the Next.js web app (`apps/web`) and Flutter mobile app (`apps/mobile`).
Talks to Supabase (Postgres + Auth JWT + RLS) and Google Gemini Flash for AI parse endpoints.

## Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- Supabase project (same as web/mobile)
- Optional: Google AI Studio API key for `/v1/ai/*`

## Configuration

Copy values into `src/Ledgerly.Api/appsettings.Development.json` or set env vars:

| Env var | Purpose |
|---------|---------|
| `Supabase__Url` | Supabase project URL |
| `Supabase__AnonKey` | Anon/public key |
| `Supabase__JwtSecret` | JWT secret (Project Settings → API) |
| `Gemini__ApiKey` | Google Generative AI key |
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

The API validates the JWT and forwards it to PostgREST so **RLS still applies**.

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
docker run -p 8080:8080 \
  -e Supabase__Url=... \
  -e Supabase__AnonKey=... \
  -e Supabase__JwtSecret=... \
  -e Gemini__ApiKey=... \
  ledgerly-api
```

## Deploy

Any Docker host works (Railway, Render, Fly.io, Azure Container Apps).
Set the env vars above and point web/mobile at the public API URL.
