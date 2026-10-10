#!/usr/bin/env bash
# The paid asset packs, kept in git only encrypted. Their licenses allow them
# in the app but not handed out, and this repository is public, so the
# folders below are git-ignored and travel as private_assets.tar.gz.enc:
# AES-256 (OpenSSL, PBKDF2) over a tar.gz.
#
# private_assets.tree is their tree in one file: a line per file with its
# mode, size and content hash, then its path. Its hash is the assets'
# fingerprint: when it differs from the committed one, the assets changed.
# (No modification times: a checkout, an unpack or a touch changes those
# without changing the art, and would re-encrypt for nothing.)
#
#   tool/private_assets.sh unpack         # after a fresh clone, and in CI: the folders back
#   tool/private_assets.sh pack           # re-encrypt if they changed (the pre-commit hook does it)
#   tool/private_assets.sh commit -m ...  # commit a change to the assets alone (see below)
#   tool/private_assets.sh check          # do the folders match the committed tree?
#   tool/private_assets.sh tree           # print the folders' tree
#   tool/private_assets.sh install-hooks  # git config core.hooksPath .githooks
#
# The hooks (.githooks/) call `pre-commit` and `post-update`: a commit takes
# the re-encrypted archive along whenever the assets changed. The folders are
# git-ignored, so with nothing else staged git stops at "nothing to commit"
# before the hook can add the archive: `commit` is git commit --allow-empty,
# refused when the assets did not change. A checkout
# or pull that brings a new archive unpacks it when the assets have no edits
# of their own. The password comes from $ASSETS_PASSWORD (CI's secret of that
# name), or, on the owner's machine, from ~/dev/keys/pixel-paint.md: the
# fenced block under "Assets archive password".
set -euo pipefail
cd "$(dirname "$0")/.."

folders=(assets/ui assets/sprites assets/puzzles assets/sfx)
archive=private_assets.tar.gz.enc
treefile=private_assets.tree
notes=${ASSETS_PASSWORD_MD:-$HOME/dev/keys/pixel-paint.md}
cipher=(-aes-256-cbc -pbkdf2 -iter 200000 -md sha256)

die() { echo "private_assets: $*" >&2; exit 1; }
say() { echo "private_assets: $*" >&2; }

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

# Mode and size, from GNU or BSD stat.
if stat -c %a . > /dev/null 2>&1; then
  meta() { stat -c '%a %s' "$1"; }
else
  meta() { stat -f '%Lp %z' "$1"; }
fi

# The tree: "<mode> <size> <sha256>  <path>" for every file, in a stable order.
tree() {
  find "${folders[@]}" -type f ! -name .DS_Store -print0 2> /dev/null | LC_ALL=C sort -z |
    while IFS= read -r -d '' f; do
      printf '%s %s  %s\n' "$(meta "$f")" "$(shasum -a 256 < "$f" | cut -d ' ' -f 1)" "$f"
    done
}

fingerprint() { shasum -a 256 | cut -d ' ' -f 1; }
unpacked() { for f in "${folders[@]}"; do [[ -d $f ]] || return 1; done; }

# The fingerprint the folders were last unpacked from or packed into, kept in
# .git: what tells "the archive moved on" from "the assets were edited".
synced_file() { git rev-parse --git-path private_assets.synced 2> /dev/null; }
synced() { cat "$(synced_file)" 2> /dev/null || true; }
mark_synced() { [[ -z "$(synced_file)" ]] || echo "$1" > "$(synced_file)"; }

do_pack() {
  password
  # COPYFILE_DISABLE: no macOS ._ files in the archive.
  COPYFILE_DISABLE=1 tar -czf - --exclude .DS_Store "${folders[@]}" |
    openssl enc -e "${cipher[@]}" -salt -pass env:ASSETS_PASSWORD -out "$archive"
  tree > "$treefile"
  mark_synced "$(fingerprint < "$treefile")"
  say "packed $(wc -l < "$treefile" | tr -d ' ') files into $archive"
}

do_unpack() {
  [[ -f $archive ]] || die "no $archive"
  password
  # -p: the modes as packed, so the tree comes out the same on every machine.
  openssl enc -d "${cipher[@]}" -pass env:ASSETS_PASSWORD -in "$archive" | tar -xpzf - ||
    die "could not decrypt $archive: wrong password?"
  diff -q <(tree) "$treefile" > /dev/null || die "the unpacked files do not match $treefile"
  mark_synced "$(fingerprint < "$treefile")"
  say "unpacked $(wc -l < "$treefile" | tr -d ' ') files"
}

case ${1:-} in
  tree)
    tree
    ;;
  pack)
    unpacked || die "an asset folder is missing: unpack first"
    if [[ -f $archive && -f $treefile ]] && [[ "$(tree | fingerprint)" == "$(fingerprint < "$treefile")" ]]; then
      say "the archive is current"
    else
      do_pack
      say "commit $archive and $treefile"
    fi
    ;;
  unpack)
    do_unpack
    ;;
  check)
    [[ "$(tree | fingerprint)" == "$(fingerprint < "$treefile")" ]] ||
      die "the asset folders differ from $treefile: run tool/private_assets.sh pack and commit"
    say "the archive is current"
    ;;

  # The pre-commit hook: when the assets changed, the commit takes the
  # re-encrypted archive along. Refuses when the archive in git changed since
  # the assets were last synced (a pull from another machine), which packing
  # would quietly undo.
  pre-commit)
    unpacked || { say "assets not unpacked here, so nothing to encrypt (tool/private_assets.sh unpack)"; exit 0; }
    committed=$(git show ":$treefile" 2> /dev/null | fingerprint)
    current=$(tree | fingerprint)
    if [[ $current == "$committed" ]]; then
      mark_synced "$current"
      exit 0
    fi
    last=$(synced)
    if [[ -n $last && $last != "$committed" ]]; then
      die "the archive in git is newer than your assets (it changed since they were last unpacked):" \
        "copy your asset edits aside, run tool/private_assets.sh unpack, redo them, and commit again"
    fi
    say "the assets changed: re-encrypting"
    alone=; [[ -n "${PRIVATE_ASSETS_COMMIT:-}" ]] || ! git diff --cached --quiet || alone=1
    do_pack
    git add "$archive" "$treefile"
    [[ -z $alone ]] || say "if git says \"nothing to commit\", only the assets changed:" \
      "commit them with tool/private_assets.sh commit -m \"...\""
    ;;

  commit)
    shift
    [[ "$(tree | fingerprint)" != "$(git show "HEAD:$treefile" 2> /dev/null | fingerprint)" ]] ||
      die "the assets did not change: nothing for this to commit"
    PRIVATE_ASSETS_COMMIT=1 exec git commit --allow-empty "$@"
    ;;

  # post-checkout and post-merge: a new archive is unpacked when the assets
  # have no edits of their own. Never fails: these hooks cannot stop anything.
  post-update)
    [[ -f $treefile ]] || exit 0
    committed=$(fingerprint < "$treefile")
    if ! unpacked; then
      ( do_unpack ) || say "could not unpack the assets: run tool/private_assets.sh unpack"
      exit 0
    fi
    current=$(tree | fingerprint)
    if [[ $current == "$committed" ]]; then
      mark_synced "$current"
    elif [[ $current == "$(synced)" ]]; then
      say "a new asset archive came in: unpacking"
      ( do_unpack ) || say "could not unpack the assets: run tool/private_assets.sh unpack"
    else
      say "the asset archive changed, and so did your assets: not unpacking over your edits." \
        "Keep them (the next commit re-encrypts them) or run tool/private_assets.sh unpack."
    fi
    exit 0
    ;;

  install-hooks)
    git config core.hooksPath .githooks
    [[ "$(tree | fingerprint)" != "$(fingerprint < "$treefile")" ]] || mark_synced "$(fingerprint < "$treefile")"
    say "hooks on: .githooks (pre-commit re-encrypts changed assets, post-checkout/post-merge unpack new ones)"
    ;;
  *)
    die "usage: tool/private_assets.sh unpack|pack|commit|check|tree|install-hooks"
    ;;
esac
