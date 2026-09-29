# Smart Money Manager Mobile

Flutter (Android / iOS) client for [Smart Money Manager](../../README.md).

Lives under **`apps/mobile`** alongside:

- [`apps/api`](../api) — shared ASP.NET Core backend
- [`apps/web`](../web) — Next.js frontend

## Architecture

- Auth: **Supabase Auth** (email/password, secure session storage)
- Data + AI: **Ledgerly.Api** REST `/v1/*` with `Authorization: Bearer <access_token>`
- Receipt OCR runs on-device; only extracted text is sent to `/v1/ai/parse-receipt`
- Changing payee, category, or account on the review sheet is sent back with the original draft. The API stores that combination in `fill_feedback` for this user only.

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
flutter build appbundle
flutter build ios
dart run flutter_launcher_icons
```

## Release signing (Play App Signing)

The release build does not use the debug keystore. You create the upload key once, outside this repo, and enroll the app in **Play App Signing**. Google holds the app signing key. You keep the upload key.

1. Create a keystore somewhere that is not in this repository, for example `%USERPROFILE%\keystores\smoneymanager-upload.jks`.
2. Copy `android/key.properties.example` to `android/key.properties` (that file is gitignored).
3. Point `storeFile` at the keystore. Use an absolute path.
4. Build the bundle: `flutter build appbundle --release`.
5. Upload the `.aab` from `build/app/outputs/bundle/release/`.

`flutter run` (debug) still works without `key.properties`. A release build fails until the upload key is configured.

This Play Console account is a personal account. Before production, run a closed test with at least 12 testers opted in for 14 consecutive days, then apply for production access. Internal testing can start before that.

The release API URL must be `https://`. Debug builds may still use `http://10.0.2.2:5080` or another local address.

## Folder map

```
lib/
  core/         config, theme, router, Dio client, OCR, errors
  features/     authentication, dashboard, transactions, quick_add, …
  shared/       models, widgets, components
```
