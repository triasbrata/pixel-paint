#!/usr/bin/env bash
# Redraws every store graphic: renders the app screenshots, then adds captions
# and makes the Google Play and itch.io images (see tool/make_store_art.py).
set -euo pipefail
cd "$(dirname "$0")/.."

flutter test tool/store_screenshots_test.dart
python=python3
[[ -x .venv/bin/python ]] && python=.venv/bin/python
"$python" tool/make_store_art.py
