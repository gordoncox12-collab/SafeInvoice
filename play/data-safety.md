# Play Console — Data safety answers

SafeInvoice is offline-first. Declare **no data collected** and **no data shared**.

## Overview

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not applicable (nothing is sent to us) |
| Do you provide a way for users to request that their data is deleted? | Users delete data in the app or by uninstalling. We hold no copy. |

## Data collected

None. Do not tick any data-type families (location, personal info, financial, photos, files, contacts, app activity, device IDs, etc.).

Invoice, customer and payment records stay in the on-device SQLite database. That is **not** “data collected” by the developer.

## Data shared

None. Do not declare sharing with third parties.

User-initiated, one-off PDF send via Email or WhatsApp is **not** declared as sharing (Play: user-initiated, not ongoing, not to you).

## Security practices

| Practice | Answer |
| --- | --- |
| Data encrypted in transit | N/A — release build has no INTERNET permission |
| Users can request deletion | Yes, in-app delete / uninstall |
| Independent security review | No |
| Committed to Play Families policy | No (not a children’s app) |

## Account / sign-in

The app does **not** allow users to create an account.

## Android Auto Backup

`android:allowBackup="false"`. Books are not uploaded to Google Drive by the app.

## Privacy policy URL (required)

https://raw.githubusercontent.com/gordoncox12-collab/SafeInvoice/cursor/safeinvoice-play-261-597d/docs/privacy-policy.md

HTML copy (enable GitHub Pages on `docs/` to publish): https://gordoncox12-collab.github.io/SafeInvoice/privacy-policy.html
