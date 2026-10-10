# Pixel Paint

A color-by-number game for pixel art. Every cell of a black-and-white pixel picture
shows a number; the color guide below says which color each number is
(`1 → Black`, `2 → Brown`, …). Paint every cell with its color to reveal the picture.

Puzzles range from **Easy** (≤5 colors, for kids) to **Expert** (15+ colors with many
similar shades, for adults).

## Run

The paid art is in git only encrypted (see Asset license), so a fresh clone first
unpacks it, with the password in `ASSETS_PASSWORD`:

```sh
tool/private_assets.sh unpack          # once after cloning: assets/ui, sprites, puzzles, sfx
tool/private_assets.sh install-hooks   # and the hooks that re-encrypt them on commit
./run.sh                 # Chrome (default)
./run.sh macos           # macOS desktop app
./run.sh ios             # iOS Simulator (started if it isn't running)
./run.sh android         # connected Android device / emulator
./run.sh macos --release # extra args go to `flutter run`
flutter test
```

While it runs: `r` hot reload, `R` restart, `q` quit.

## How to play

The whole game is pixel art, drawn with [Flame](https://flame-engine.org): a storybook
of pictures under a pastel sky, with a slime friend.

- **The book**: the bookmarks on its edge pick the difficulty (green Easy, blue Medium,
  orange Hard, red Expert); tap a picture to paint it. Arrows or a swipe turn the pages
  when a difficulty has more pictures than fit. Each page is a list: a row per picture
  with its name, its **best score**, and a progress bar (or Done once finished).
- Pick a color in the guide at the bottom, then paint with one of two tools:
  - **Pencil** — tap or drag across cells, one cell at a time.
  - **Fill** (paint bucket) — tap a cell to paint it *and every touching cell with the
    same number*. With a wrong color only the tapped cell is marked, so one slip can't
    flood an area.
- Cells with the selected number glow yellow. A wrong color stays as a translucent
  mistake (red frame) until you repaint it; correct cells lock. When a color is finished
  the guide jumps to the next one.
- **Score**: every correct cell scores 10 points with the Pencil, 3 a cell with Fill.
  Correct paints in quick succession build a **combo**: every 4 in a row raise the
  multiplier, up to **20x**. The meter drains while you pause (3 s at 1x, 2 s at 20x);
  each time it runs out the multiplier drops one level and the meter refills, down to 1x.
  A wrong color ends the combo at once (points are kept). Points pop up where you paint,
  Fill throws pixels, and the slime cheers every fifth multiplier with a "wow!" (and
  flinches at a wrong color).
- The top row holds the **pause** button, the combo meter and the score (on a small
  phone a long score shortens to 12K / 1.2M). Pause opens a menu with the music and sound
  switches, the leaderboard, Reset and Home; the combo waits while it is open, and leaving
  the app pauses too. Below the picture: Pencil and Fill, then the color guide (it
  scrolls, the tools stay put).
- The **slime** sits on the picture and hops out of the way ("Sorry!") of cells still
  waiting for the selected color.
- Finishing a picture with Google Play Games signed in (Android) sends the score to that
  picture's **leaderboard** (the trophy in the pause menu, and Ranks when you finish).
- **Pinch** with two fingers to zoom and move. On desktop/web: **scroll** to zoom,
  **right-drag** to move. The buttons on the page: find a cell (crosshair), zoom in (+),
  whole picture (−).
- While zoomed in, the **mini map** (top-left) shows the whole picture with a frame
  around the part on screen; tap or drag on it to jump there.
- **Music** ("Paint Party") and **sounds** have their own switches (note and speaker, on
  the book and in the pause menu), both remembered. Music pauses in the background, follows the iOS silent switch and
  doesn't stop music from other apps; on the web it starts after the first tap.
- The Android back button closes a dialog (the pause menu too), then the picture, then
  the app.
- Progress is saved on the device automatically.

## Adding puzzles

Drop a PNG into `assets/puzzles/`. That's it:

- 1 pixel = 1 cell. Transparent pixels are empty cells; transparent borders are trimmed.
- Every distinct color becomes one palette number (up to 255). Similar shades get
  neighbouring numbers, and each gets an automatic English name.
- The file name becomes the title (`blue_gems.png` → "Blue Gems").
- Difficulty is computed from the number of colors and the picture size
  (see `lib/src/models/difficulty.dart`).

Use the *original* pixel size of the art (e.g. 16×16), not an upscaled copy — a 2×
upscale has 4 cells per pixel and no extra detail.

### Converting big "pixel art" images

AI-generated or upscaled pixel art (e.g. a 2752×1536 JPEG) isn't on a clean grid and
has hundreds of thousands of colors. `tool/pixelate.py` shrinks it to a grid, reduces it
to a palette, keeps dark outlines, and removes single-cell specks:

```sh
python3 -m venv .venv && .venv/bin/pip install pillow numpy   # once
.venv/bin/python tool/pixelate.py photo.jpg -o assets/puzzles/my_picture.png \
    --width 64 --colors 16 --preview /tmp/preview.png
```

| Option | Meaning |
| --- | --- |
| `--width` | Grid width in cells; height follows the aspect ratio |
| `--colors` | Palette size before similar shades are merged |
| `--crop l,t,r,b` | Crop the source first (pixels) to give the subject more cells |
| `--outline-boost` | How strongly very dark outlines win a cell (default 2.0; lower for busy scenes) |
| `--min-cells` / `--min-delta` | Merge colors used by fewer cells / closer than this ΔE |

Rough guide: ~50 wide and ≤9 colors for kids, ~60 wide and 10–14 colors for Hard,
128–160 wide and 30–40 colors for Expert.

The bundled scenes were made with:

```sh
D=~/Downloads
px() { .venv/bin/python tool/pixelate.py "$@"; }
px $D/Gemini_Generated_Image_ldllygldllygldll.jpeg -o assets/puzzles/sleepy_cat.png    --width 52  --colors 10 --crop 380,200,2420,1536
px $D/Gemini_Generated_Image_etj3xqetj3xqetj3.jpeg -o assets/puzzles/shiba_meadow.png  --width 56  --colors 14 --crop 830,120,2230,1480
px $D/Gemini_Generated_Image_e2tifde2tifde2ti.jpeg -o assets/puzzles/moon_witch.png    --width 160 --colors 36
px $D/Gemini_Generated_Image_uk871uk871uk871u.jpeg -o assets/puzzles/mermaid_reef.png  --width 160 --colors 40 --outline-boost 1.4
px $D/Gemini_Generated_Image_ouw1qyouw1qyouw1.jpeg -o assets/puzzles/treehouse_tea.png --width 160 --colors 40 --outline-boost 1.4
```

## Music

`assets/music/paint_party.mp3` is generated by `tool/compose_music.py` (F major, 104 BPM,
kalimba melody, electric piano, bouncy bass and soft swung drums, ~1:40 seamless loop):

```sh
.venv/bin/python tool/compose_music.py -o assets/music/paint_party.mp3            # needs lame or ffmpeg
.venv/bin/python tool/compose_music.py -o assets/music/paint_party.mp3 --bpm 112  # more energy
```

To use another track instead, drop an MP3 in `assets/music/` and change the file name in
`loadGameData()` (`lib/src/app.dart`).

## App icon

The icon is the cherries puzzle, half painted and half still gray with its numbers —
the game in one picture — on a pastel squircle (superellipse). `tool/update_icons.sh`
redraws it for every platform: squircle icons for web, older Android, macOS (with
margin and shadow) and the favicon (sprite drawn pixel-exact). iOS gets a full square
because Apple requires it and cuts the squircle itself; Android 8+ adaptive icons get
their shape from the launcher (a squircle on Xiaomi/HyperOS).

```sh
tool/update_icons.sh                           # cherries
tool/update_icons.sh assets/puzzles/lemon.png  # any other sprite
```

It uses `.venv/bin/python` (Pillow) when present, then runs `flutter_launcher_icons`.
Source images land in `assets/icon/`.

## Store pages

| Store | Guide | Listing files |
| --- | --- | --- |
| Google Play | `store/play-console.md` | `android/fastlane/metadata/android/en-US/` (texts, icon, feature graphic, screenshots) |
| itch.io | `store/itch/page.md` | `store/itch/` (cover, banner, screenshots, description) |

Both need the privacy policy `store/privacy-policy.html` hosted somewhere public
(fill in its two placeholders first).

```sh
tool/update_store_art.sh   # renders the app mid-game, then draws every store graphic
tool/release.sh            # Google Play: the signed bundle (see Releasing)
tool/build_itch.sh         # itch.io: web zip + APKs in build/itch/
cd android && fastlane listing   # optional: upload the Play listing
```

The screenshots come from the real app (`tool/store_screenshots_test.dart` stages each
one: which picture, how far painted, zoom), and `tool/make_store_art.py` adds the
captions. Captions count the puzzles themselves; the store descriptions mention
"29 pictures" and "5 to 40 colors", so update those when puzzles are added.

## Releasing

Releases are numbered and published by CI (`.github/workflows/`), the same way as
sshbox:

| Workflow | When | What |
| --- | --- | --- |
| `ci.yml` | every pull request and push to `main` | `flutter analyze`, `flutter test --coverage` |
| `tag.yml` | a push to `main` that changes the app, or by hand | once 10 app commits gather since the last release, or one carries a `Release: feature` trailer: runs `ci.yml`, then tags `vX.Y.Z` ("Pixel Paint X.Y.Z, build N") and calls `release.yml` |
| `release.yml` | from `tag.yml`, or by hand (a dry run unless told) | `tool/release.sh --publish`: the bundle, signed with the upload key, on Play's closed testing track (`alpha`); with `ITCH_TARGET` set, the itch.io page too |

`pubspec.yaml`'s version line only sets `X.Y`: bump it by hand for a new minor version
and the next release is `X.Y.0`. Production is always rolled out from the Play
Console, after a look.

**The first release is by hand**, since Play takes nothing over its API before the
app's first bundle:

1. Build it signed with the upload key: `tool/release.sh` (needs a clean git tree;
   `flutter build appbundle --release` works too) and upload
   `build/app/outputs/bundle/release/app-release.aab` in Play Console › Test and
   release (internal or closed testing first).
2. Tag the commit it was built from, so CI counts on from it:
   `git tag -a v1.0.0 -m "Pixel Paint 1.0.0, build 1" && git push origin v1.0.0`.

**The upload key** is `android/key.properties` (git-ignored; see
`android/key.properties.example`): a keystore and its passwords, or files holding them.
The owner keeps it in `~/dev/keys` (`pixel-paint-upload.jks`, its password in `pixel-paint.md`).
Back the keystore and its password up in two places: Play can reset a lost upload
key, but itch.io APKs signed with another key can't be installed over the old ones.

**CI's secrets**, in the repository's `release` environment (only `main` can deploy to
it), except `ASSETS_PASSWORD`:

| Secret | Value |
| --- | --- |
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | `base64 -i pixel-paint-upload.jks` |
| `ANDROID_UPLOAD_STORE_PASSWORD`, `ANDROID_UPLOAD_KEY_PASSWORD` | the keystore's password (the same for both) |
| `ANDROID_UPLOAD_KEY_ALIAS` | `upload` |
| `PLAY_SERVICE_ACCOUNT_JSON` | a Google Cloud service account's JSON key, invited in Play Console › Users and permissions with *Release apps to testing tracks* for Pixel Paint |
| `ASSETS_PASSWORD` (a repository secret, for every workflow) | the encrypted assets' password (Asset license) |
| `BUTLER_API_KEY` (optional) | an itch.io API key, with the repository variable `ITCH_TARGET` = `user/pixel-paint` |

`tool/play_publish.py` speaks the Play Developer API with the standard library and
openssl, no pip packages; by hand it reads the service account key from
`$PLAY_SERVICE_ACCOUNT_JSON` or `~/dev/keys/jeansh-play-service-account.json` (the service
account Jeansh releases with, given Pixel Paint in Play Console › Users and permissions).

The repository is public; the paid asset packs are in it only encrypted (see Asset
license).

## Scores and leaderboards

`lib/src/game/score_keeper.dart` holds the rules (points, combo steps, window); the
score is saved with each picture's progress, the best score per picture separately.

Online leaderboards use Google Play Games (Android only; the web build keeps best scores
in the browser). They stay hidden until set up: create one leaderboard per picture in
Play Console, named like the picture, then import the IDs:

```sh
python3 tool/import_games_ids.py --names                 # the names to create
python3 tool/import_games_ids.py ~/Downloads/games-ids.xml
```

Step-by-step, and what it means for the Play Data safety form and a young audience:
`store/play-console.md`.

## Code map

| Path | What |
| --- | --- |
| `lib/src/app.dart` | Loads everything, hosts the Flame game, lifecycle and back button |
| `lib/src/models/puzzle.dart` | PNG pixels → numbered grid + palette |
| `lib/src/models/color_names.dart` | Automatic color names |
| `lib/src/game/puzzle_progress.dart` | Paint rules: lock correct cells, track mistakes, completion |
| `lib/src/game/progress_store.dart` | Saving progress and best scores (`shared_preferences`) |
| `lib/src/game/score_keeper.dart` | Points and the combo multiplier |
| `lib/src/game/leaderboard.dart`, `play_games_leaderboard.dart` | Online leaderboards (Google Play Games) |
| `lib/src/audio/` | Background music and sound effects, each with its saved switch |
| `lib/src/ui/` | The pixel UI kit: pixel scale, sheets and sprite rects, 9-slices, pixel text, buttons |
| `lib/src/scenes/paint_book_game.dart` | The Flame game: screens, dialogs, pointer routing |
| `lib/src/scenes/book_screen.dart` | The book of pictures (home) |
| `lib/src/scenes/paint_screen.dart` | The coloring page: layout, scoring, effects, dialogs |
| `lib/src/scenes/paint_grid.dart` | The paint / pinch-zoom grid, Pencil & Fill |
| `lib/src/scenes/paint_hud.dart`, `paint_effects.dart`, `palette_strip.dart` | Score, combo meter, mini map; popups, bursts, sparkles; the color guide |
| `lib/src/scenes/mascot.dart`, `sky.dart`, `dialogs.dart`, `thumbnails.dart` | The slime, the backdrop, the panels, pixel-perfect picture thumbnails |
| `tool/import_ui_assets.py` | Copies the UI art from Path of Hero, gives the slime its face |
| `tool/pixelate.py` | Turns big pixel-art style images into puzzle PNGs |
| `tool/compose_music.py` | Generates the background music |
| `tool/make_wow_sfx.py` | Synthesizes the slime's "wow!" for a high combo (`assets/sfx/wow.wav`) |
| `tool/make_icon.py`, `tool/update_icons.sh` | Draw the app icon and install it for every platform |
| `tool/release.sh`, `tool/play_publish.py`, `.github/` | The signed Play bundle, publishing it to a testing track, CI (see Releasing) |
| `tool/store_screenshots_test.dart`, `tool/make_store_art.py`, `tool/update_store_art.sh` | Store screenshots and graphics |
| `tool/build_itch.sh` | itch.io builds |
| `tool/import_games_ids.py` | Play Games leaderboard IDs from the Play Console export |
| `store/` | Store page guides, privacy policy, itch.io graphics |
| `run.sh` | Opens the game on Chrome / macOS / iOS / Android |

## Asset license

The bundled 16×16 icon puzzles come from the **Cute Fantasy Icons (Premium)** pack by
Kenmi (<https://kenmi-art.itch.io/cute-fantasy-icons>). The license allows using and
modifying them in commercial or non-commercial projects, but **not redistributing**
them. Shipping them inside the app is fine; publishing the files is not.

**This repository is public, so the paid art never goes in it as files.**
`assets/ui/`, `assets/sprites/`, `assets/puzzles/` and `assets/sfx/` are git-ignored
and travel only as `private_assets.tar.gz.enc` (AES-256, OpenSSL with PBKDF2).
`private_assets.tree` is their tree in one file, a line per file with its mode, size
and content hash; its hash is the assets' fingerprint, so a change to any file (added,
removed, edited, its mode) changes it. Modification times are left out on purpose: a
checkout or a `touch` changes them without changing the art.

Git hooks keep the archive and the folders in step (`tool/private_assets.sh
install-hooks` once per clone):

- **pre-commit**: the fingerprint differs from the committed tree, so the assets are
  re-encrypted and the archive and the tree go into the commit. It refuses when the
  archive in git changed since the assets were last unpacked (a pull from another
  machine), rather than encrypt the older art over it.
- **post-checkout / post-merge**: a new archive came in and the assets have no edits of
  their own, so it is unpacked.

The folders being git-ignored, a change to the assets alone leaves nothing staged, and
git stops at "nothing to commit" before the hook runs: commit those with
`tool/private_assets.sh commit -m "..."`.

```sh
tool/private_assets.sh unpack          # the folders from the archive (CI does this with its ASSETS_PASSWORD secret)
tool/private_assets.sh install-hooks   # once per clone: git config core.hooksPath .githooks
tool/private_assets.sh commit -m "New puzzles"   # a change to the assets alone
tool/private_assets.sh check           # do the folders still match the archive?
```

The password is the repository secret `ASSETS_PASSWORD`; the owner keeps it in
`~/dev/keys/pixel-paint.md`, which the script reads when the variable is unset. Never
`git add -f` those folders.

The five scene puzzles (`sleepy_cat`, `shiba_meadow`, `moon_witch`, `mermaid_reef`,
`treehouse_tea`) were converted from Gemini-generated images supplied by the project
owner.

The store graphics use Pixelify Sans and Nunito (`tool/fonts/`, SIL Open Font License).

The game's UI art comes from the owner's game *Path of Hero* (`tool/import_ui_assets.py`
copies it into `assets/ui/`, `assets/sprites/`, `assets/sfx/` and `assets/fonts/`), all
licensed to the owner for their own games and **not for redistribution**, so these
folders are in the encrypted archive too:

| Art | Pack | Notes |
| --- | --- | --- |
| Book, bookmarks, buttons, ribbons, frames, bars, icons, selectors, sparkles | [Cute Fantasy UI](https://kenmi-art.itch.io/cute-fantasy-ui) by Kenmi | |
| Pencil and paint bucket | Cute Fantasy Icons (Premium) by Kenmi | |
| The slime | [Tiny RPG Character Pack](https://zerie.itch.io/tiny-rpg-character-asset-pack) by Zerie | eyes and blush added |
| Clouds, sun, birds, hot air balloon | GandalfHardcore Platformer pack | |
| Font: Poh Sans | Pixelify Sans, redrawn for Path of Hero | SIL OFL (`assets/fonts/OFL-PohSans.txt`) |
| Sound effects | made by the owner for Path of Hero | |
| The slime's "wow!" | synthesized by `tool/make_wow_sfx.py` | |
