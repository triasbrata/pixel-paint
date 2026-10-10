#!/usr/bin/env bash
# Rebuilds the app icon for every platform from one pixel sprite.
#
#   tool/update_icons.sh                          # cherries (default)
#   tool/update_icons.sh assets/puzzles/lemon.png
#
# Uses .venv/bin/python if present (needs Pillow), else python3.
set -euo pipefail
cd "$(dirname "$0")/.."
sprite="${1:-assets/puzzles/cherries.png}"
py=python3
[[ -x .venv/bin/python ]] && py=.venv/bin/python

"$py" tool/make_icon.py "$sprite" \
  -o assets/icon/icon.png \
  --ios assets/icon/icon_ios.png \
  --foreground assets/icon/icon_foreground.png \
  --background assets/icon/icon_background.png \
  --macos assets/icon/icon_macos.png
dart run flutter_launcher_icons
# flutter_launcher_icons writes a blurry 16px favicon; replace it with a crisp squircle one.
"$py" tool/make_icon.py "$sprite" --favicon web/favicon.png
