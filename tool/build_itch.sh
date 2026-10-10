#!/usr/bin/env bash
# Builds the itch.io uploads (see store/itch/page.md):
#
#   build/itch/pixel-paint-web.zip                HTML5 build, index.html at the zip root
#   build/itch/pixel-paint-<version>-arm64.apk    Android, nearly every phone and tablet
#   build/itch/pixel-paint-<version>-armv7.apk    Android, older 32-bit devices
#
#   tool/build_itch.sh                            # build only
#   ITCH_TARGET=<user>/pixel-paint tool/build_itch.sh   # build and push with butler
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)
out=build/itch
rm -rf "$out"
mkdir -p "$out"

# Web: CanvasKit bundled instead of loaded from Google's CDN, and every URL
# relative, because itch.io serves the game from a subfolder of its own domain.
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
sed -i.bak 's#<base href="/">#<base href="./">#' build/web/index.html
rm build/web/index.html.bak
grep -q '<base href="./">' build/web/index.html || { echo "base href not rewritten" >&2; exit 1; }
(cd build/web && zip -qr -X "../../$out/pixel-paint-web.zip" .)

# Android: sign it with the upload key, so players can install later versions
# over it (a different key means uninstalling first, and losing progress).
if [[ ! -f android/key.properties ]]; then
  echo "warning: android/key.properties is missing, the APK is signed with the debug key" >&2
fi
# One APK per CPU type: a universal one is ~50 MB, since native libraries are
# stored uncompressed. (Google Play gets the app bundle and does this itself.)
flutter build apk --release --split-per-abi --target-platform android-arm64,android-arm
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$out/pixel-paint-$version-arm64.apk"
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$out/pixel-paint-$version-armv7.apk"

ls -lh "$out"
if [[ -n "${ITCH_TARGET:-}" ]]; then
  butler push build/web "$ITCH_TARGET:html5" --userversion "$version"
  butler push "$out/pixel-paint-$version-arm64.apk" "$ITCH_TARGET:android-arm64" --userversion "$version"
  butler push "$out/pixel-paint-$version-armv7.apk" "$ITCH_TARGET:android-armv7" --userversion "$version"
fi
