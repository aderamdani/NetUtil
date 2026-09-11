#!/usr/bin/env bash
# NetUtil HIG anti-slop lint. Exit 1 on violations.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/NetUtil"
fail=0

# H2 — fonts below 10pt. A single digit after `size:` means value < 10.
hits=$(rg -n --glob '*.swift' '\.system\(size:\s*[0-9]\s*[,)]' "$SRC" || true)
if [ -n "$hits" ]; then
  echo "H2 FAIL — sub-10pt font(s):"; echo "$hits"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "HIG lint: clean."
fi
exit "$fail"
