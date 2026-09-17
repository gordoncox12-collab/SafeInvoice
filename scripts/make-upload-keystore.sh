#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
keytool -genkeypair -v \
  -keystore android/app/play-upload.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "${STORE_PASSWORD:?}" \
  -keypass "${KEY_PASSWORD:?}" \
  -dname "CN=SafeInvoice, OU=Gordon Cox, O=SafeInvoice, L=Johannesburg, ST=Gauteng, C=ZA"
echo "Wrote android/app/play-upload.jks"
