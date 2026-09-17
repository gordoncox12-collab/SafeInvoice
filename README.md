# SafeInvoice

Offline-first Android invoicing for **Gordon Cox** (South Africa, `en-ZA`).

Every business, customer, invoice, signature, spreadsheet and receipt lives on the phone. There is **no server** and **no demo data**.

- **App name:** SafeInvoice
- **Application ID:** `app.safeinvoice`
- **Version:** 1.0.0 (versionCode 1)
- **Min SDK:** 26 (Android 8.0)
- **Target / compile SDK:** 35
- **UI:** Kotlin, Jetpack Compose, Material 3
- **Database:** Room (source of truth)
- **PDF:** on-device `PdfDocument`
- **Spreadsheets:** Apache POI (`.xlsx` / `.xls`) plus CSV

## Private repo and sideload downloads

This GitHub repository is **private**. A GitHub Release can still hold APK/AAB artefacts, but **a phone with no GitHub login cannot download them** until you either:

1. Set this repository to **public**, or
2. Host a public release mirror (another public repo, Drive, or a simple download page).

After a `v1.0.0` release exists, the intended URLs are:

- Sideload APK: `https://github.com/gordoncox12-collab/SafeInvoice/releases/download/v1.0.0/SafeInvoice-release.apk`
- Play AAB: `https://github.com/gordoncox12-collab/SafeInvoice/releases/download/v1.0.0/SafeInvoice.aab`

Debug APK (sideloadable, debug-signed): `SafeInvoice-debug.apk` on the same release.

## First launch (no seed data)

The first screen asks you to **create your business profile**. After that, add customers and invoices. Books start empty — there are no Cape Town sample businesses, fake customers or sample invoices.

A default “Standard” invoice template (ZAR, 15% VAT, classic layout) is created with the business so you can invoice immediately.

## Open, build and run (Android Studio)

1. Install [Android Studio](https://developer.android.com/studio) (Koala / Ladybug or newer is fine).
2. **File → Open** and choose this repository **root** (the folder that contains `settings.gradle.kts`).
3. Wait for Gradle sync. Accept any SDK licence prompts (Platform 35 and Build-Tools 35.0.0).
4. Plug in a phone with **USB debugging**, or start an emulator (API 26+).
5. Click **Run** on the `app` configuration.

### Command line

```bash
export ANDROID_HOME="$HOME/Android/Sdk"   # or your SDK path
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

## Play upload (AAB)

1. Copy `keystore.properties.example` to `keystore.properties` (gitignored).
2. Point `storeFile` at `app/play-upload.jks` (the Play **upload** keystore).
3. Fill `storePassword`, `keyAlias` (`upload`) and `keyPassword`.
4. Build the App Bundle:

```bash
./gradlew :app:bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`

Sideload APK (same signing):

```bash
./gradlew :app:assembleRelease
```

Output: `app/build/outputs/apk/release/app-release.apk`

5. In [Google Play Console](https://play.google.com/console) create the app **SafeInvoice**, then **Create release → Upload** the `.aab`.
6. Turn on **Play App Signing**. Keep `app/play-upload.jks` forever — every update must be signed with this upload key.

### Upload keystore (Gordon — change these if you generate a new key)

`keystore.properties` is **gitignored** so passwords are not committed as a properties file. The first Play upload key for this project is:

| Field | Value |
| --- | --- |
| File | `app/play-upload.jks` |
| Alias | `upload` |
| storePassword | `Si-Play-Upload-2026-GC!` |
| keyPassword | `Si-Play-Upload-2026-GC!` |

Treat these as the **first upload key**. Generate a replacement with `scripts/make-upload-keystore.sh` **before** the first Play upload, or reset the upload key later in Play Console. Do not commit a filled-in `keystore.properties`.

## What you can do offline

1. **Business profiles** and **customers** (multiple books).
2. **Per-customer folders** on disk: invoices, receipts, Excel, images, notes — under `files/businesses/{businessId}/customers/{customerId}/…`.
3. **Room** stores every invoice, line item, payment, note and file index.
4. **Invoices:** line items, 15% VAT default, discounts, ZAR default, `PREFIX-YEAR-0001` numbering, draft / sent / paid / overdue.
5. **Handwritten signature** stamped onto the PDF.
6. Complete **local partition** per business and customer.
7. **Excel / CSV** import with column mapping, export, and in-app sheet capture into the customer folder (`.xlsx` / `.xls` / `.csv`).
8. **Share PDF and receipts** via Email and WhatsApp (Android `ACTION_SEND` + `FileProvider` attachment).
9. **Theme:** light / dark / system plus eight accent palettes (Settings).
10. **Invoice templates:** classic / modern / compact / letterhead / minimal, plus margins, logo position, picture placement, colours, logo, header/extra pictures, clipboard paste.

## Privacy

Local-only. No `INTERNET` permission. Email and WhatsApp use apps already on the phone.

## Project layout

```
settings.gradle.kts          Gradle root
app/src/main/java/app/safeinvoice/
  data/                      Room, files, PDF, Excel, share
  ui/                        Compose screens
```

## Tests

```bash
./gradlew :app:testDebugUnitTest
```
