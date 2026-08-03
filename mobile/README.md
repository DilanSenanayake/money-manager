# Ledgerly Mobile

Native Flutter (Android / iOS) client for [Ledgerly](../README.md). Talks directly to the same Supabase project as the web app (Auth + Postgres RLS). The Next.js app is unchanged.

## Architecture

- **Clean / feature-based** folders under `lib/`
- **Riverpod** for state
- **go_router** for navigation + auth redirects
- **supabase_flutter** for auth and CRUD (no REST wrapper)
- Material 3 light/dark theme (Plus Jakarta Sans, teal brand)

AI receipt/SMS parsing is intentionally deferred (Phase 2+) to a Supabase Edge Function so the Gemini API key never ships in the app. Quick Add v1 supports full manual entry.

## Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (stable).
2. From this directory:

```bash
cp .env.example .env
# Set SUPABASE_URL and SUPABASE_ANON_KEY (same public values as the web app)
flutter pub get
flutter run
```

Android SDK / Xcode required for device builds. Web/Chrome can be used for UI smoke tests (`flutter run -d chrome`).

## Scripts

```bash
flutter analyze
flutter test
flutter build apk
flutter build ios
dart run flutter_launcher_icons
```

## Deep link (stub)

`ledgerly://add` is registered on Android/iOS for future Quick Add entry.

## Release checklist

- [ ] Replace signing keys / bundle IDs for store builds
- [ ] Confirm Supabase Auth email settings for mobile redirect URLs if using magic links later
- [ ] Generate launcher icons: `dart run flutter_launcher_icons`
- [ ] Run `flutter test` and device QA on Android + iOS
- [ ] Store screenshots / privacy policy / data safety forms

## Folder map

```
lib/
  core/         theme, router, network, utils, errors
  features/     authentication, dashboard, transactions, …
  shared/       models, widgets, components
```
