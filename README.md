# JobSlip

An offline-first Flutter app for tradespeople and small businesses to produce
professional quotations, invoices and receipts on a phone, and share them as
PDFs.

There are no network calls anywhere in the app. Everything — clients, documents,
settings, logo — lives in a single JSON file in the app's private storage, so it
works with no signal and no account.

## Features

- **Three document types**, each with its own number sequence and colour:
  quotations (`-Q-`), invoices (`-INV-`) and receipts (`-R-`).
- **The money, up front** — the home screen leads with what you are owed,
  what is overdue, and what you collected this month, then lists whoever
  needs a nudge.
- **The quote-to-cash path** — an accepted quote converts into an invoice
  (pay later) or straight into a receipt (paid on the spot), and recording a
  payment on an invoice issues the matching receipt in the same step. Related
  documents link to each other both ways.
- **Due dates that look after themselves** — an invoice carries a credit
  period (on receipt, 7, 14 or 30 days) and goes *overdue* on its own, with
  nothing stored and nothing to re-save. The Invoices tab carries a badge, and
  the list puts the most overdue first.
- **Line-item editor** with per-item quantity, rate, running totals, optional
  VAT at a configurable rate, and job notes that print on the PDF.
- **Client book** — reusable clients showing what each one still owes, and
  whether any of it is late. New clients are added while writing a document.
- **One printed letterhead** shared by all three types, so a client who has
  seen one recognises the next: your logo and trading name across the top,
  the work itemised with units and rates, the total spelled out in words,
  and the mobile-money codes to pay into. Only the wording and the reference
  rows differ between a quotation, an invoice and a receipt.
- **Look before you commit** — "Preview" renders the real PDF from the
  unsaved draft, marked NOT SAVED YET, with Keep editing / Save / Save &
  send. No number is spent and no client is added to the book until you
  save.
- **Built on-device and shared** with a pre-written covering message, or
  printed, via the system share sheet. Settled documents carry a dated PAID
  stamp; unpaid ones carry the MoMo and Airtel tiles and a payment
  reference.
- **Your branding** — business name, tagline, contact details, logo, and one of
  five brand colours that themes both the app and the documents it produces.
- **Backup and restore** to a single self-contained JSON file, with the logo
  embedded as base64 so a restore on a new device is complete.
- **Configurable currency**, default terms, and the details that print on
  every document: email, TIN, who prepared it and their phone, plus the two
  mobile-money merchant codes.

## Not losing anyone's work

This ships as an update to phones that already hold a business's only copy of
its records, so the store is treated accordingly:

- Every field added in a new version is read defensively, with a default, so
  a store or backup written by an older version loads unchanged.
- Saves are **atomic** — written to a temporary file and renamed — so a crash
  or a flat battery mid-write leaves the previous store intact.
- An unreadable store is **never mistaken for a fresh install**. It is copied
  aside, all writing stops, and the home screen explains how to restore from
  a backup. Nothing overwrites what could not be read.
- A single corrupt document costs that one document, not the whole book.

`test/store_safety_test.dart` holds these guarantees, including a full
write-then-reopen round-trip.

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
  pdf/         pdf_builder.dart (the letterhead), pdf_share.dart (share/print)
  screens/     Onboarding, home, the three lists, editor, detail, PDF, setup
  widgets/     Shared UI pieces, including the action sheets
  theme/       Brand colours, per-type colours, status pills, ThemeData
  utils/       Currency, dates, and the wording a document uses about itself
```

`AppTheme.statusStyle` is the single place that turns a document's type,
status and due date into the word shown to the user, and `DocSummary.of` the
single place that turns them into the sentence underneath it. Changing how a
status reads means changing one of those two.

The printed wording lives alongside them in `lib/utils/doc_summary.dart` —
`recipientLabel`, `pdfMetaRows`, `pdfTotalWord`, `payBoxFor` and `unitOf` are
what make one layout serve all three document types.

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
