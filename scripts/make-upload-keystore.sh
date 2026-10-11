#!/usr/bin/env bash
# Generate a Play upload keystore locally. Never commit the .jks.
set -euo pipefail
OUT="${1:-$HOME/safeinvoice-play-upload.jks}"
keytool -genkeypair -storetype JKS \
  -keystore "$OUT" \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "${STORE_PASSWORD:?}" \
  -keypass "${KEY_PASSWORD:?}" \
  -dname "CN=Gordon Cox, OU=SafeInvoice, O=Gordon Cox, L=South Africa, ST=Gauteng, C=ZA"
echo "Wrote $OUT (keep this file private)"
