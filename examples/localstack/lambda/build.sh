#!/usr/bin/env bash
set -euo pipefail
mkdir -p lambda/dist
zip -j lambda/dist/function.zip lambda/handler.py >/dev/null
