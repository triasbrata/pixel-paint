# Google Play

The store listing is set up as fastlane metadata in
`android/fastlane/metadata/android/en-US/`:

| Play Console field | File | Limit |
| --- | --- | --- |
| App name | `title.txt`: *Pixel Paint: Color by Number* | 30 |
| Short description | `short_description.txt` | 80 |
| Full description | `full_description.txt` | 4000 |
| App icon | `images/icon.png` (512 × 512) | |
| Feature graphic | `images/featureGraphic.png` (1024 × 500) | |
| Phone screenshots | `images/phoneScreenshots/` (7 × 1080 × 1920) | 2–8 |
| 7-inch tablet screenshots | `images/sevenInchScreenshots/` (7 × 1920 × 1080) | up to 8 |
| 10-inch tablet screenshots | `images/tenInchScreenshots/` (7 × 2560 × 1440) | up to 8 |
| Release notes | `changelogs/<versionCode>.txt` | 500 |

The graphics come from the real app: `tool/update_store_art.sh` renders it mid-game and
adds the captions. The texts mention 29 pictures and 5–40 colors; update them (and run
the script again; captions count by themselves) when puzzles are added.

Everything else Play Console asks for is below.

## Decide before the first upload

- **Package name** `com.triasbrata.color_by_number` (in `android/app/build.gradle.kts`)
  can never change once the app is on Play.
- **Upload key.** Create it once and keep the file and passwords safe:
  ```sh
  keytool -genkeypair -v -keystore ~/keys/pixel-paint-upload.jks -alias upload \
      -keyalg RSA -keysize 2048 -validity 10000
  cp android/key.properties.example android/key.properties   # then fill it in
  ```
  Play App Signing keeps the real signing key; a lost upload key can be reset
  through Play support, but it takes days.
- **Version.** `version: 1.0.0+1` in `pubspec.yaml`. The number after `+` is the
  version code: raise it for every upload, and name the release notes after it.

## Build

```sh
flutter build appbundle        # → build/app/outputs/bundle/release/app-release.aab
```

The app targets API 36 and asks for no permissions (not even internet: Play Games talks to
its servers through Google Play services).

## Create the app

Play Console → **Create app**: name *Pixel Paint: Color by Number*, default language
**English (United States) – en-US**, **Game**, **Free**. A free app can't become
paid later.

## App content (Policy → App content)

| Section | Answer |
| --- | --- |
| Privacy policy | URL of the hosted `store/privacy-policy.html` (fill in its two placeholders first). Any public page works: GitHub Pages, Google Sites, Netlify. |
| Ads | **No**, the app has no ads |
| App access | **All functionality is available without any access restrictions** |
| Content rating | Questionnaire, category **Game**. Every question is *No*: no violence (the sword and skull are still item pictures), no fear, sex, language, drugs, gambling, no user interaction, no sharing of location, no purchases, no web browsing. Expected result: Everyone / PEGI 3 / IARC 3+. |
| Target audience | See below |
| News app | No |
| Data safety | See [Data safety](#data-safety): the game collects nothing itself, but the Play Games SDK does. |
| Advertising ID | **No** |
| Government app | No |
| Financial features | None |
| Health | None |

### Target audience

**Decide this before the first release; it decides whether Play Games leaderboards may
stay.** Google's rules for Play Games and children:

> "If your application is directed primarily at children, it should not use Google
> Sign-In or any other Google API Service that accesses data associated with a Google
> Account. This restriction includes Google Play Games Services… Mixed audience apps:
> …can offer… Google Play Games Services as an optional feature… users must be able to
> access the application in its entirety without signing into a Google Account."
> ([API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy))

and the [Families policy](https://support.google.com/googleplay/android-developer/answer/9893335)
asks mixed-audience apps to put SDKs that aren't approved for children "behind a neutral
age screen" or to use them in a way that collects no data from children.

The game already treats Play Games as optional: nothing needs a sign-in, and the game
never asks for one by itself (only the Leaderboard button does). What it can't promise:
Play Games v2 signs returning players in automatically when the game starts, before any
age question the game could ask. The options:

| Target age groups | Leaderboards | Notes |
| --- | --- | --- |
| **13–15, 16–17, 18+** (recommended with leaderboards) | Play Games, as built | Kids can still install it (rated Everyone); the listing just isn't aimed at them. Avoid "for kids" wording (the current texts already do). |
| Include 6–12 (mixed audience) | Play Games, optional | Allowed only as an optional feature. Expect closer review; add a neutral age screen if review asks for one. |
| Mainly children | Not Play Games | Leaderboards would have to be local (on the device). |

Whatever you pick, content rating stays Everyone / PEGI 3.

### Data safety

The game itself collects and shares nothing (progress and scores stay on the device). The
Play Games SDK does, and Google leaves the answers to you; see its
[data collection guidance](https://developer.android.com/games/pgs/data-collection):
"Games account data… Gamer Identity (Gamertag, avatar)", "analytics data", "diagnostics
data", and, because the game uses leaderboards, "Games scores". All of it is "encrypted
in transit using HTTPS". Declare those types as collected (by the Play Games SDK), not
shared, encrypted in transit; there are no accounts of the game's own to delete. Re-read
Google's page when you fill in the form: it is the source of truth.

## Store settings (Grow → Store presence → Store settings)

| Field | Value |
| --- | --- |
| App category | Game → **Puzzle** (Casual also fits) |
| Tags | Up to 5 from the Console's list. Good matches if offered: coloring, pixel art, relaxing, casual, offline. |
| Email | Required, shown publicly: a support address |
| Website | Optional: the itch.io page |

## Main store listing

Upload the texts and graphics by hand from the files above, or with fastlane (next
section). The listing's language is en-US; add translations later under
*Store presence → Main store listing → Manage translations*.

## Release

1. **Closed testing first.** New personal developer accounts must run a closed test
   before they can publish (currently at least 12 testers opted in for 14 days in a
   row; Play Console shows your exact requirement). Create a closed track, add the
   testers' Google accounts or a Google Group, upload the bundle, and send them the
   opt-in link.
2. After the test period, **apply for production access** on the Dashboard.
3. **Production** → create a release with the same bundle, roll out.

Each later update: raise the version in `pubspec.yaml`, add
`changelogs/<versionCode>.txt`, build the bundle, upload.

## Play Games Services (leaderboards)

One leaderboard per picture. Until it's set up, the game simply shows no Leaderboard
button (and still keeps each picture's best score on the device).

1. Play Console → *Grow users → Play Games Services → Setup and management →
   Configuration*: create a Play Games project for this app.
2. *Credentials*: add an Android credential for package `com.triasbrata.color_by_number`
   with the **SHA-1 of the app signing key** (Play Console → *Test and release →
   App integrity*) and another with the SHA-1 of your **upload key**
   (`keytool -list -v -keystore ~/keys/pixel-paint-upload.jks`), so both store and
   sideloaded builds can sign in.
3. *Leaderboards → Create leaderboard*, once per picture, **named exactly like the
   picture** (list them with `python3 tool/import_games_ids.py --names`). Format:
   Numeric, no decimals, larger is better. Up to 70 leaderboards per game.
4. Add your Google account (and testers') under *Testers*, until the Play Games
   configuration is published.
5. *Leaderboards → Get resources* → save the XML, then:
   ```sh
   python3 tool/import_games_ids.py ~/Downloads/games-ids.xml
   ```
   It writes the app ID and every board ID into the app, and lists pictures that still
   have no leaderboard.
6. Build, test the Leaderboard button on a device, then *Publish* the Play Games
   configuration (Play Games Services → Publishing).

New pictures need a new leaderboard (same name as the picture) and another import.

## fastlane (optional)

fastlane uploads the listing and builds, so the files in `android/fastlane/metadata`
stay the single source of truth.

1. Google Cloud console: create a service account and a JSON key for it, and enable
   the *Google Play Android Developer API*.
2. Play Console → *Users and permissions* → invite the service account's email, with
   access to this app (release and store listing permissions).
3. Save the key as `android/fastlane/play-service-account.json` (git-ignored), or point
   `PLAY_JSON_KEY` at it.

```sh
cd android
fastlane listing     # texts + graphics
fastlane internal    # the bundle → internal testing, as a draft
```

The first bundle of a new app has to be uploaded in Play Console by hand; after
that, fastlane can upload every one.
