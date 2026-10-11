# SafeInvoice — Google Play submission

Gordon uploads the AAB in [Play Console](https://play.google.com/console) himself.

## What to upload

- **AAB:** [SafeInvoice-2.6.1.aab](https://github.com/gordoncox12-collab/SafeInvoice/releases/download/v2.6.1/SafeInvoice-2.6.1.aab)
- **Application ID:** `app.safeinvoice` (must match the first upload forever)
- **versionName:** 2.6.1
- **versionCode:** 10 (Play requires each new upload to increase this)
- **targetSdk:** 36 (required for new apps / updates from 31 August 2026)

Sideload APKs stay on the same release as `SafeInvoice-2.6.1.apk`.

## Listing and policy files

| Play Console field | File |
| --- | --- |
| Store listing (en-ZA) | [listing-en-ZA.md](listing-en-ZA.md) |
| Data safety | [data-safety.md](data-safety.md) |
| Content rating notes | [content-rating.md](content-rating.md) |
| Privacy policy | https://gordoncox12-collab.github.io/SafeInvoice/privacy-policy.html |
| Icon / feature / screenshots | [store/](store/) |

Paste the privacy policy URL into Play Console → App content → Privacy policy, and into the store listing contacts if asked.

## Upload key / keystore (keep a private backup)

| Item | Location |
| --- | --- |
| Upload keystore | `android/app/play-upload.jks` (committed so this project can sign) |
| Local passwords file | `android/keystore.properties` (gitignored) |
| Example passwords file | `keystore.properties.example` |
| Key alias | `upload` |
| Certificate CN | Gordon Cox, SafeInvoice, South Africa |

**Back up `play-upload.jks` and the passwords offline.** If the upload key is lost and Play App Signing is already on, you can request an upload-key reset. If you lose the key *before* the first AAB is accepted, you cannot update the listing with a new key.

Never email the keystore. Do not check `keystore.properties` into git.

## Play App Signing (do this on first upload)

1. Open Play Console → SafeInvoice → **Release → Setup → App signing**.
2. Choose **Let Google manage and protect your app signing key** (recommended).
3. Upload `SafeInvoice-2.6.1.aab`. Play extracts the **upload certificate** from that AAB (the `upload` key in `play-upload.jks`).
4. Google generates (or you export) the **app signing key** that users’ devices see. You keep only the upload key for future AABs.
5. Future releases: sign the AAB with the **same** `play-upload.jks` / `upload` alias, bump `versionCode`, upload.

If Play asks to export an encrypted Play App Signing key, use Play’s PEPK tool with this same keystore only if you are *creating* the app signing key yourself. For the first SafeInvoice listing, prefer “Google generate the app signing key”.

## Release track

Use **Internal testing** first, then **Closed**, then **Production**. Countries: start with South Africa.

## What Gordon still has to do

- A Google Play Console developer account (one-time registration fee, currently US$25)
- Create the app `SafeInvoice` / `app.safeinvoice` if it does not exist
- Paste listing copy, Data safety, content rating, privacy URL
- Upload the AAB and complete the declarations (ads: no; news: no; COVID: no; Data safety: no collection)
- Keep a private backup of `play-upload.jks`
