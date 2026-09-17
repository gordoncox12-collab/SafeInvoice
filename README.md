# SafeInvoice

Offline-first **Flutter** invoicing for **Gordon Cox** (South Africa, `en-ZA`).

Every business, customer, invoice, signature, spreadsheet and receipt lives on the phone. There is **no server** and **no demo data**.

- **App name:** SafeInvoice
- **Application ID:** `app.safeinvoice`
- **Version:** 2.0.0 (versionCode 2)
- **Flutter SDK:** 3.47.1 (Dart 3.13.1)
- **Min SDK:** 26 (Android 8.0)
- **UI:** Flutter, Material 3
- **Database:** sqflite (source of truth)
- **PDF:** on-device `pdf` package
- **Spreadsheets:** `.xlsx` / `.xls` import, `.xlsx` / CSV export, plus in-app capture

This Flutter rebuild replaces the previous Kotlin/Compose Android project. Do not mix the two stacks.

## Sideload / GitHub Release

The repository is public. Download the Flutter release artefacts without a GitHub login:

- Sideload APK: https://github.com/gordoncox12-collab/SafeInvoice/releases/download/v2.0.0/SafeInvoice-flutter-release.apk
- Play AAB: https://github.com/gordoncox12-collab/SafeInvoice/releases/download/v2.0.0/SafeInvoice-flutter-release.aab

## First launch (no seed data)

The first screen asks you to **create your business profile**. After that, add customers and invoices. Books start empty — there are no Cape Town sample businesses, fake customers or sample invoices.

A default “Standard” invoice template (ZAR, 15% VAT, classic layout) is created with the business so you can invoice immediately.

## Open, build and run

1. Install [Flutter 3.47.1](https://docs.flutter.dev/install) (stable) and an Android SDK (platform 36, build-tools, cmdline-tools).
2. Accept Android licences: `flutter doctor --android-licenses`
3. From this repository **root**:

```bash
flutter pub get
flutter run
```

Plug in a phone with USB debugging or start an emulator (API 26+).

### Checks

```bash
flutter analyze
flutter test
```

### Release APK and Play App Bundle

```bash
cp keystore.properties.example keystore.properties   # gitignored; fill if you rotate keys
flutter build apk --release
flutter build appbundle --release
```

Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

## Play upload

1. Copy `keystore.properties.example` to `keystore.properties` (gitignored).
2. Point `storeFile` at `android/app/play-upload.jks`.
3. Fill `storePassword`, `keyAlias` (`upload`) and `keyPassword`.
4. Upload the `.aab` in [Google Play Console](https://play.google.com/console).
5. Turn on **Play App Signing**. Keep `android/app/play-upload.jks` forever — every update must be signed with this upload key.

### Upload keystore (Gordon — change these if you generate a new key)

`keystore.properties` is **gitignored**. The first Play upload key for this project is:

| Field | Value |
| --- | --- |
| File | `android/app/play-upload.jks` |
| Alias | `upload` |
| storePassword | `Si-Play-Upload-2026-GC!` |
| keyPassword | `Si-Play-Upload-2026-GC!` |

Treat these as the **first upload key**. Generate a replacement with `scripts/make-upload-keystore.sh` **before** the first Play upload, or reset the upload key later in Play Console.

## What you can do offline

1. **Business profiles** and **customers** (multiple books).
2. **Per-customer folders** on disk: invoices, receipts, Excel, images, notes — under app support files `businesses/{businessId}/customers/{customerId}/…`.
3. **sqflite** stores every invoice, line item, payment, note and file index.
4. **Invoices:** line items, 15% VAT default, discounts, ZAR default, `PREFIX-YEAR-0001` numbering, draft / sent / paid / overdue.
5. **Handwritten signature** stamped onto the PDF.
6. Complete **local partition** per business and customer.
7. **Excel / CSV** import with column mapping, export, and in-app sheet capture into the customer folder (`.xlsx` / `.xls` / `.csv`).
8. **Share PDF and receipts** via Email and WhatsApp (Android `ACTION_SEND` + `FileProvider` attachment).
9. **Theme:** light / dark / system plus eight accent palettes (Settings).
10. **Invoice templates:** classic / modern / compact / letterhead / minimal, plus margins, logo position, picture placement, colours, logo, header/extra pictures, clipboard paste.

## Privacy

Local-only. The main manifest has no `INTERNET` permission. Email and WhatsApp use apps already on the phone. Debug/profile builds still add INTERNET so Flutter tooling can talk to the device.

## Project layout

```
lib/
  main.dart
  domain/          models, money, ZA helpers
  data/            sqflite, files, PDF, Excel, native share
  ui/              Material 3 screens, theme, controller
android/           Flutter Android host (applicationId app.safeinvoice)
test/              VAT, Excel mapping, widget smoke tests
```

## Tests

```bash
flutter test
```
