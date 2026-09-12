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

hits=$(rg -n --glob '*.swift' 'cornerRadius: (8|10|12)\b' "$SRC" || true)
if [ -n "$hits" ]; then echo "H5 FAIL — literal corner radius (use Metrics.cornerRadius*):"; echo "$hits"; fail=1; fi
hits=$(rg -n --glob '*.swift' 'spacing: (4|8|12|16|24|32)\b' "$SRC" || true)
if [ -n "$hits" ]; then echo "H6 FAIL — literal stack spacing (use Metrics.spacing*):"; echo "$hits"; fail=1; fi
hits=$(rg -n --glob '*.swift' '\.padding\((\.(horizontal|vertical|top|bottom|leading|trailing), )?(4|8|12|16|24|32)\)' "$SRC" || true)
if [ -n "$hits" ]; then echo "H7 FAIL — literal grid padding (use Metrics.spacing*):"; echo "$hits"; fail=1; fi

if [ "$fail" -eq 0 ]; then
  echo "HIG lint: clean."
fi
exit "$fail"
