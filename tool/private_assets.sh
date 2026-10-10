#!/usr/bin/env bash
# The paid asset packs, kept in git only encrypted. Their licenses allow them
# in the app but not handed out, and this repository is public, so the
# folders below are git-ignored and travel as private_assets.tar.gz.enc:
# AES-256 (OpenSSL, PBKDF2) over a tar.gz. private_assets.sha256 lists every
# file's hash, so whether the archive is current can be told without the key.
#
#   tool/private_assets.sh unpack   # after a fresh clone, and in CI: the folders back
#   tool/private_assets.sh pack     # after changing any of them: a new archive, commit both files
#   tool/private_assets.sh check    # are the folders and the archive the same?
#
# The password comes from $ASSETS_PASSWORD (CI's secret of that name), or, on
# the owner's machine, from ~/dev/keys/pixel-paint.md: the fenced block under
# "Assets archive password".
set -euo pipefail
cd "$(dirname "$0")/.."

folders=(assets/ui assets/sprites assets/puzzles assets/sfx)
archive=private_assets.tar.gz.enc
manifest=private_assets.sha256
notes=${ASSETS_PASSWORD_MD:-$HOME/dev/keys/pixel-paint.md}
cipher=(-aes-256-cbc -pbkdf2 -iter 200000 -md sha256)

die() { echo "private_assets: $*" >&2; exit 1; }

password() {
  if [[ -z "${ASSETS_PASSWORD:-}" && -f "$notes" ]]; then
    ASSETS_PASSWORD=$(awk '/Assets archive password/ { want = 1; next }
      want && /^```/ { if (open) exit; open = 1; next }
      want && open { print; exit }' "$notes")
  fi
  [[ -n "${ASSETS_PASSWORD:-}" ]] ||
    die "no password: set ASSETS_PASSWORD (in CI, the repository secret; a pull request from a fork gets none)"
  export ASSETS_PASSWORD
}

# Every file's hash, in a stable order, paths relative to the repository.
hashes() {
  find "${folders[@]}" -type f ! -name .DS_Store -print0 | LC_ALL=C sort -z |
    xargs -0 shasum -a 256
}

case ${1:-} in
  pack)
    for f in "${folders[@]}"; do [[ -d $f ]] || die "$f is missing: unpack first"; done
    if [[ -f $archive && -f $manifest ]] && diff -q <(hashes) "$manifest" > /dev/null; then
      echo "private_assets: the archive is current"
      exit 0
    fi
    password
    # COPYFILE_DISABLE: no macOS ._ files in the archive.
    COPYFILE_DISABLE=1 tar -czf - --exclude .DS_Store "${folders[@]}" |
      openssl enc -e "${cipher[@]}" -salt -pass env:ASSETS_PASSWORD -out "$archive"
    hashes > "$manifest"
    echo "private_assets: packed $(wc -l < "$manifest" | tr -d ' ') files into $archive; commit it and $manifest"
    ;;
  unpack)
    [[ -f $archive ]] || die "no $archive"
    password
    openssl enc -d "${cipher[@]}" -pass env:ASSETS_PASSWORD -in "$archive" | tar -xzf - ||
      die "could not decrypt $archive: wrong password?"
    shasum -a 256 -c --quiet "$manifest" || die "the unpacked files do not match $manifest"
    echo "private_assets: unpacked $(wc -l < "$manifest" | tr -d ' ') files"
    ;;
  check)
    diff -q <(hashes) "$manifest" > /dev/null ||
      die "the asset folders differ from $manifest: run tool/private_assets.sh pack and commit"
    echo "private_assets: the archive is current"
    ;;
  *)
    die "usage: tool/private_assets.sh pack|unpack|check"
    ;;
esac
