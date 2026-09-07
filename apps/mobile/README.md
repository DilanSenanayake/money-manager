# Smart Money Manager Mobile

Flutter (Android / iOS) client for [Smart Money Manager](../../README.md).

Lives under **`apps/mobile`** alongside:

- [`apps/api`](../api) — shared ASP.NET Core backend
- [`apps/web`](../web) — Next.js frontend

## Architecture (target)

- Auth: **Supabase Auth**
- Data + AI: **Ledgerly.Api** REST `/v1/*` with Bearer JWT
- Today: CRUD still talks to Supabase directly; AI Quick Add deferred until API wiring

## Setup

```bash
cd apps/mobile
cp .env.example .env
# Set SUPABASE_URL and SUPABASE_ANON_KEY
# Later: API_BASE_URL=http://localhost:5080
flutter pub get
flutter run
```

## Scripts

```bash
flutter analyze
flutter test
flutter build apk
flutter build ios
dart run flutter_launcher_icons
```

## Folder map

```
lib/
  core/         theme, router, network, utils, errors
  features/     authentication, dashboard, transactions, …
  shared/       models, widgets, components
```
