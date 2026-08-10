# JobSlip

An offline-first Flutter app for tradespeople and small businesses to produce
professional quotations and receipts on a phone, and share them as PDFs.

There are no network calls anywhere in the app. Everything — clients, documents,
settings, logo — lives in a single JSON file in the app's private storage, so it
works with no signal and no account.

## Features

- **Quotations and receipts** with sequential numbering, `draft` / `sent` / `paid`
  status, and optional VAT at a configurable rate.
- **Line-item editor** with per-item quantity, rate, and running totals.
- **Client book** — reusable clients with phone and location, carried onto every
  document.
- **Branded PDFs** built on-device, previewed in-app, then shared or printed via
  the system share sheet.
- **Your branding** — business name, tagline, contact details, logo, and one of
  five brand colours that themes both the app and the documents it produces.
- **Backup and restore** to a single self-contained JSON file, with the logo
  embedded as base64 so a restore on a new device is complete.
- **Configurable currency** and default terms text.

## Getting started

Requires the Flutter SDK (Dart `^3.12.2`).

```bash
flutter pub get
flutter run
```

## Project layout

```
lib/
  models/      Client, DocumentModel, LineItem, BusinessSettings
  data/        Repository (JSON persistence), BackupService, seed data
  state/       AppState — the single ChangeNotifier the UI listens to
  pdf/         pdf_builder.dart — document rendering
  screens/     Onboarding, dashboard, clients, document detail, PDF preview
  widgets/     Shared UI pieces
  theme/       Brand-colour-driven ThemeData
  utils/       Currency and date formatting
```

## Building a release

Release builds are signed with a keystore that is **not** in this repository.
Create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`,
and `keyPassword`, pointing at your own keystore:

```bash
flutter build apk --release
```

The build fails loudly rather than falling back to the debug key, since a
debug-signed release cannot update an existing install.

## Platforms

Android is the primary and tested target. The project also carries the
Flutter-generated iOS, web, Linux, macOS, and Windows scaffolding, which is
unmaintained.

## License

MIT — see [LICENSE](LICENSE).
