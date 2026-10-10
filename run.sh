#!/usr/bin/env bash
# Opens Pixel Paint.
#
#   ./run.sh                Chrome (default)
#   ./run.sh macos          macOS desktop app
#   ./run.sh ios            iOS Simulator (started if it isn't running)
#   ./run.sh android        first connected Android device / emulator
#   ./run.sh <device-id>    any device listed by `flutter devices`
#
# Extra arguments go to `flutter run`, e.g. `./run.sh macos --release`.
# While it runs: r = hot reload, R = restart, q = quit.
set -euo pipefail
cd "$(dirname "$0")"

# Prints the id of the first device whose target platform starts with $1.
device_for() {
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
for d in json.load(sys.stdin):
    if d["targetPlatform"].startswith(sys.argv[1]):
        print(d["id"])
        break
' "$1"
}

target="${1:-chrome}"
shift || true

case "$target" in
  chrome | web) device=chrome ;;
  macos | mac) device=macos ;;
  ios)
    device="$(device_for ios)"
    if [[ -z "$device" ]]; then
      echo "Starting iOS Simulator..."
      flutter emulators --launch apple_ios_simulator >/dev/null
      for _ in $(seq 60); do
        device="$(device_for ios)"
        [[ -n "$device" ]] && break
        sleep 2
      done
    fi
    ;;
  android) device="$(device_for android)" ;;
  *) device="$target" ;;
esac

if [[ -z "${device:-}" ]]; then
  echo "No '$target' device found. Check \`flutter devices\`." >&2
  exit 1
fi

flutter pub get >/dev/null
exec flutter run -d "$device" "$@"
