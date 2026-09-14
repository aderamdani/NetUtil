#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --package-path CLI --configuration release
echo "Built: CLI/.build/release/netutil"
