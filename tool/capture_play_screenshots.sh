#!/usr/bin/env bash
# Capture Play phone screenshots from a running emulator.
# Sample data is seeded by tool/play_screenshot_main.dart and is not in the store AAB.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/play/store/phone"
ART="/opt/cursor/artifacts/play"
mkdir -p "$OUT" "$ART"
DEVICE="${1:-emulator-5554}"

shots=(
  "home:01_home_outstanding"
  "editor:02_editor_auto_outstanding"
  "unpaid:03_unpaid_orders"
  "pay:04_pay_outstanding"
  "pdf:05_pdf_preview"
  "customer:06_customer_outstanding"
  "invoices:07_invoice_list"
  "settings:08_settings_privacy"
)

wait_for_activity() {
  local i
  for i in $(seq 1 90); do
    if adb -s "$DEVICE" shell dumpsys activity activities 2>/dev/null | grep -q 'app.safeinvoice'; then
      return 0
    fi
    sleep 2
  done
  return 1
}

strip_alpha() {
  python3 - "$1" <<'PY'
from pathlib import Path
import sys
from PIL import Image
p = Path(sys.argv[1])
im = Image.open(p).convert("RGB")
im.save(p, "PNG")
print(f"{p.name} {im.size[0]}x{im.size[1]}")
PY
}

for pair in "${shots[@]}"; do
  shot="${pair%%:*}"
  name="${pair##*:}"
  echo "=== $name ($shot) ==="
  adb -s "$DEVICE" shell am force-stop app.safeinvoice || true
  flutter run -t tool/play_screenshot_main.dart \
    --release \
    --dart-define="PLAY_SHOT=$shot" \
    -d "$DEVICE" \
    --no-pub \
    &
  run_pid=$!
  wait_for_activity
  sleep 8
  adb -s "$DEVICE" exec-out screencap -p > "$OUT/$name.png"
  strip_alpha "$OUT/$name.png"
  cp "$OUT/$name.png" "$ART/$name.png"
  kill "$run_pid" 2>/dev/null || true
  wait "$run_pid" 2>/dev/null || true
  adb -s "$DEVICE" shell am force-stop app.safeinvoice || true
done

echo "Wrote screenshots to $OUT"
