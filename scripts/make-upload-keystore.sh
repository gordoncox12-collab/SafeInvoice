#!/usr/bin/env bash
# Generate a Play upload keystore for SafeInvoice. Run from the repo root.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-app/play-upload.jks}"
ALIAS="${2:-upload}"
if [[ -f "$OUT" ]]; then
  echo "Refusing to overwrite $OUT — delete it first if you really want a new key."
  exit 1
fi
read -r -s -p "storePassword: " STORE
echo
read -r -s -p "keyPassword: " KEY
echo
keytool -genkeypair -v \
  -keystore "$OUT" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias "$ALIAS" \
  -storepass "$STORE" \
  -keypass "$KEY" \
  -dname "CN=Gordon Cox, OU=SafeInvoice, O=Gordon Cox, L=South Africa, ST=Gauteng, C=ZA"
cat > keystore.properties <<EOF
storeFile=$OUT
storePassword=$STORE
keyAlias=$ALIAS
keyPassword=$KEY
EOF
echo "Wrote $OUT and keystore.properties (gitignored). Keep both — Play updates need the same upload key."
