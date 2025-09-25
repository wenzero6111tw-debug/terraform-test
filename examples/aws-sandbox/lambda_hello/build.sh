#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$(dirname "$0")/dist"
zip -j "$(dirname "$0")/dist/function.zip" "$(dirname "$0")/handler.py" >/dev/null
