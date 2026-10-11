# SafeInvoice — Google Play submission

Gordon uploads the AAB in [Play Console](https://play.google.com/console) himself.

## What to upload

- **AAB:** [SafeInvoice-2.6.1.aab](https://github.com/gordoncox12-collab/SafeInvoice/releases/download/v2.6.1/SafeInvoice-2.6.1.aab)
- **Application ID:** `app.safeinvoice` (must match the first upload forever)
- **versionName:** 2.6.1
- **versionCode:** 10 (Play requires each new upload to increase this)
- **targetSdk:** 36 (required for new apps / updates from 31 August 2026)

Sideload APKs stay on the same release as `SafeInvoice-2.6.1.apk`. Upload **`SafeInvoice-2.6.1.aab`** (the Play pack), not the older `SafeInvoice-flutter-release.aab`.

Phone screenshots in `play/store/phone/` were captured on an Android emulator (1080×1920) from a **screenshot-only** entrypoint (`tool/play_screenshot_main.dart`). That seed is not compiled into the store AAB. A fresh install of the AAB opens **Create your business** with no demo data.

## Listing and policy files

| Play Console field | File |
| --- | --- |
| Store listing (en-ZA) | [listing-en-ZA.md](listing-en-ZA.md) |
| Data safety | [data-safety.md](data-safety.md) |
| Content rating notes | [content-rating.md](content-rating.md) |
| Privacy policy (public raw markdown) | https://raw.githubusercontent.com/gordoncox12-collab/SafeInvoice/main/docs/privacy-policy.md |
| Privacy policy (HTML, after Pages) | https://gordoncox12-collab.github.io/SafeInvoice/privacy-policy.html |
| Icon / feature / screenshots | [store/](store/) |

Paste the privacy URL into Play Console → App content → Privacy policy, and into the store listing contacts if asked.

## Upload key / keystore (private — not in git)

The previous `android/app/play-upload.jks` was committed to this **public** repo and is **compromised**. A new upload key was generated before the first Play upload.

| Item | Location |
| --- | --- |
| Upload keystore | **Private only** — not in git. Agent Store: `/cursor/stores/self/play-keys/play-upload.jks` |
| Passwords | **Private only.** Agent Store: `/cursor/stores/self/play-keys/passwords.txt` |
| Local passwords file | `keystore.properties` (gitignored) |
| Example (placeholders) | `keystore.properties.example` |
| Key alias | `upload` |
| Certificate CN | Gordon Cox, SafeInvoice, South Africa |

**Back up the private `.jks` and the password file offline.** If the upload key is lost and Play App Signing is already on, you can request an upload-key reset. If you lose the key *before* the first AAB is accepted, you cannot update the listing with a new key.

Never email the keystore. Do not check `*.jks`, `*.keystore`, `key.properties`, or `keystore.properties` into git.

## Play App Signing (do this on first upload)

1. Open Play Console → SafeInvoice → **Release → Setup → App signing**.
2. Choose **Let Google manage and protect your app signing key** (recommended).
3. Upload `SafeInvoice-2.6.1.aab`. Play extracts the **upload certificate** from that AAB.
4. Google generates (or you export) the **app signing key** that users’ devices see. You keep only the upload key for future AABs.
5. Future releases: sign the AAB with the **same** private upload keystore / `upload` alias, bump `versionCode`, upload.

If Play asks to export an encrypted Play App Signing key, use Play’s PEPK tool with this same keystore only if you are *creating* the app signing key yourself. For the first SafeInvoice listing, prefer “Google generate the app signing key”.

## Release track

Use **Internal testing** first, then **Closed**, then **Production**. Countries: start with South Africa.

## What Gordon still has to do

- A Google Play Console developer account (one-time registration fee, currently US$25)
- Create the app `SafeInvoice` / `app.safeinvoice` if it does not exist
- Paste listing copy, Data safety, content rating, privacy URL
- Optional: enable GitHub Pages (Settings → Pages → Deploy from branch `main`, folder `/docs`)
- Upload the AAB and complete the declarations (ads: no; news: no; COVID: no; Data safety: no collection)
- Keep a private backup of the new upload keystore and passwords — never email the keystore
