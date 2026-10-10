# itch.io page

Everything to fill in at <https://itch.io/game/new>, in the order the form asks for it.
Keep the project as a **Draft** until the page looks right, then make it Public.

Files in this folder: `cover.png`, `banner.png`, `screenshots/`, `description.html`.
Builds: `tool/build_itch.sh` → `build/itch/`. All graphics are redrawn by
`tool/update_store_art.sh`.

## Basics

| Field | Value |
| --- | --- |
| Title | `Pixel Paint` |
| Project URL | `https://<your-username>.itch.io/pixel-paint` |
| Short description or tagline | `Color pixel art by number. Combo up to 20x and beat your best score.` |
| Classification | Games |
| Kind of project | **HTML** (the game plays in the browser; the APK is an extra download) |
| Release status | Released |
| Pricing | Your choice. Free with optional donations ("No payments" or "$0 or donate") suits a first release. |

## Uploads

| File (from `build/itch/`) | Settings |
| --- | --- |
| `pixel-paint-web.zip` | ✓ *This file will be played in the browser* |
| `pixel-paint-<version>-arm64.apk` | Platform: ✓ Android. Display name: *Android (most devices)* |
| `pixel-paint-<version>-armv7.apk` | Platform: ✓ Android. Display name: *Android (older 32-bit devices)* |

Sign the APKs with the upload key (`android/key.properties`) **before the first
public upload**: Android only installs an update over an app signed with the same
key, so switching keys later means players uninstall first and lose their progress.

With [butler](https://itch.io/docs/butler/) installed and logged in, the script uploads
both for you, and later versions update in place:

```sh
ITCH_TARGET=<your-username>/pixel-paint tool/build_itch.sh
```

## Embed options

| Option | Value |
| --- | --- |
| Embed in page | ✓, manually set size **960 × 640** |
| Mobile friendly | ✓ (orientation: Default) |
| Automatically start on page load | off (one click starts the game and its music) |
| Fullscreen button | ✓ |
| Enable scrollbars | off |
| SharedArrayBuffer support | off (not needed) |

## Details

**Description**: open `description.html` in a browser, select all, copy, and paste
into the Description field. Headings, lists and links come along.

| Field | Value |
| --- | --- |
| Genre | Puzzle |
| Tags (up to 10) | `pixel-art`, `coloring`, `cozy`, `relaxing`, `casual`, `cute`, `family-friendly`, `colorful`, `touch-friendly`, `singleplayer` |
| AI generation disclosure | **Yes**, see below |
| App store links | Add the Google Play link once the app is live there |
| Community | Comments |
| Visibility & access | Draft → Public when ready |

**AI disclosure.** itch.io requires it, and listings found without it can be
taken down. Tick:

- **Graphics**: the five scene pictures (Sleepy Cat, Shiba Meadow, Moon Witch, Mermaid
  Reef, Treehouse Tea) started as Gemini images.
- **Sound, Text, Code**: the music script, the code and these texts were written with an
  AI assistant. Tick these to be fully transparent; leave them off only if you reworked
  that part yourself.

The 16×16 item pictures are hand-made pixel art by Kenmi, not AI. The description's
Credits section says the same in plain words.

## Media

| Field | File |
| --- | --- |
| Cover image | `cover.png` (630 × 500, shown at 315 × 250 in listings) |
| Screenshots | `screenshots/1_zoom.png` … `6_admire.png`, in that order |
| Gameplay video / trailer | none for now |

## Edit theme (on the project page, after saving)

| Setting | Value |
| --- | --- |
| Banner | `banner.png` |
| Layout | Simple, game embed at the top |
| Background color | `#EFE7FF` |
| Inner background | `#FFFFFF` |
| Text | `#2E1F5E` |
| Links | `#7C4DFF` |
| Buttons | `#7C4DFF`, button text `#FFFFFF` |
| Font | a rounded sans such as Nunito if the list has it, otherwise the default |

## Before going public

- [ ] Play the browser build on the draft page (desktop and a phone): pictures load,
      painting works, music starts after the first click, fullscreen works.
- [ ] Install the APK from the page on an Android device.
- [ ] The privacy policy (`store/privacy-policy.html`) is hosted, and its link is added
      under the description if you like.
