# SafeInvoice

Offline-first **Flutter** invoicing for **Gordon Cox** (South Africa, `en-ZA`).

Every business, customer, invoice, signature, spreadsheet and receipt lives on the phone. There is **no server** and **no demo data**.

- **App name:** SafeInvoice
- **Application ID:** `app.safeinvoice`
- **Version:** 2.4.0 (versionCode 7)
- **Flutter SDK:** 3.47.1 (Dart 3.13.1)
- **Min SDK:** Flutter default (sideload APK is re-signed v1+v2 for OEM installers)
- **UI:** Flutter, Material 3
- **Database:** sqflite (source of truth)
- **PDF:** on-device `pdf` package
- **Spreadsheets:** `.xlsx` / `.xls` import, `.xlsx` / CSV export, plus in-app capture

This Flutter rebuild replaces the previous Kotlin/Compose Android project. Do not mix the two stacks.

## Sideload / GitHub Release

The repository is public. Download the Flutter release artefacts without a GitHub login:

- Sideload APK: https://github.com/gordoncox12-collab/SafeInvoice/releases/download/v2.4.0/SafeInvoice-flutter-release.apk
- Play AAB: https://github.com/gordoncox12-collab/SafeInvoice/releases/download/v2.4.0/SafeInvoice-flutter-release.aab

`SafeInvoice-flutter-release.apk` is signed with **APK Signature Scheme v1 + v2** so OEM “APK Installer” apps can open it. Verify with `apksigner verify -v` (Verified using v1 scheme / v2 scheme both true).

## First launch (no seed data)

The first screen asks you to **create your business profile**. Books start empty — there are no Cape Town sample businesses, fake customers or sample invoices.

Home then shows a short checklist: **business → products → customer → invoice**.

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

### Checks (hard gate before any APK)

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

`assembleRelease` post-processes the sideload APK (`scripts/sign_sideload_apk.py`) so v1 + v2 signatures are present and the file is zipaligned.

Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

## Play upload

1. Copy `keystore.properties.example` to `keystore.properties` (gitignored).
2. Point `storeFile` at `android/app/play-upload.jks`.
3. Fill `storePassword`, `keyAlias` (`upload`) and `keyPassword`.
4. Upload the `.aab` in [Google Play Console](https://play.console.google.com).
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
2. **Products catalog** (name, unit price, optional VAT / description) — pick them from invoice line dropdowns.
3. **Searchable dropdowns** for customers, invoices and products.
4. **Per-customer folders** on disk: invoices, receipts, Excel, images, notes — under app support files `businesses/{businessId}/customers/{customerId}/…`.
5. **sqflite** stores every invoice, line item, payment, note, product and file index. Invoice number bumps use `UPDATE`, not `INSERT OR REPLACE`, so child rows are not cascade-deleted.
6. **Invoices:** line items, 15% VAT default, discounts, ZAR default, `PREFIX-YEAR-0001` numbering, draft / sent / paid / overdue. Save validates the selected customer and shows an error instead of crashing.
7. **Handwritten authorised signature** and **customer delivery (POD) signature** stamped onto the PDF.
7a. **Payment options** on the invoice: Cash, EFT, consignment stock, swapped stock.
7b. **Draft / save for later** invoices, listed on Home and under Invoices → Saved for later.
7c. **WhatsApp chat** (`wa.me`) plus PDF share; **Save PDF to device storage** (and Files/SAF picker).
7d. **Issue date and time** (Africa/Johannesburg / SAST) plus generated timestamp on preview and PDF.
8. Complete **local partition** per business and customer.
9. **Excel / CSV** import with column mapping, export, and in-app sheet capture into the customer folder (`.xlsx` / `.xls` / `.csv`).
10. **Share PDF and receipts** via Email and WhatsApp (Android `ACTION_SEND` + `FileProvider` attachment).
11. **Theme:** light / dark / system plus 18 vibrant accent palettes with a live preview in Settings.
12. **Invoice templates:** classic / modern / compact / letterhead / minimal, plus margins, logo position, picture placement, colours, logo, header/extra pictures, clipboard paste.

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
scripts/           sideload v1+v2 signer, keystore helper
test/              VAT, invoice create, products, themes, widget flow
```

## Tests

```bash
flutter test
```
