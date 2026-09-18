# Smart Money Manager Mobile

Flutter (Android / iOS) client for [Smart Money Manager](../../README.md).

Lives under **`apps/mobile`** alongside:

- [`apps/api`](../api) — shared ASP.NET Core backend
- [`apps/web`](../web) — Next.js frontend

## Architecture

- Auth: **Supabase Auth** (email/password, secure session storage)
- Data + AI: **Ledgerly.Api** REST `/v1/*` with `Authorization: Bearer <access_token>`
- Receipt OCR runs on-device; only extracted text is sent to `/v1/ai/parse-receipt`

## Setup

```bash
cd apps/mobile
cp .env.example .env
# Set SUPABASE_URL, SUPABASE_ANON_KEY, and API_BASE_URL
flutter pub get
flutter run
```

`API_BASE_URL` examples:

| Where you run the app | Typical value |
|---|---|
| Flutter desktop / iOS simulator against local API | `http://localhost:5080` |
| Android emulator | `http://10.0.2.2:5080` |
| Physical phone on LAN | `http://<your-pc-ip>:5080` |
| Production | `https://api.yourdomain.com` |

The API must use the **same Supabase project** as the app.

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
  core/         config, theme, router, Dio client, OCR, errors
  features/     authentication, dashboard, transactions, quick_add, …
  shared/       models, widgets, components
```
