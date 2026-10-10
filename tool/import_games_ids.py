"""Sets up the Google Play Games leaderboards from the Play Console export.

    python3 tool/import_games_ids.py --names            # names to create in Play Console
    python3 tool/import_games_ids.py games-ids.xml      # after "Get resources"

Create one leaderboard per picture in Play Console, named exactly like the
picture's title ("Sleepy Cat"), so the export calls it leaderboard_sleepy_cat
and this script can match it to assets/puzzles/sleepy_cat.png. Then download
the resources XML and run the script on it. It writes

  android/app/src/main/res/values/games-ids.xml   the export itself (app ID for the manifest)
  assets/config/leaderboards.json                  picture id → leaderboard id, for the game

and lists pictures that still have no leaderboard (they just show no online
board). Standard library only.
"""
import argparse
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUZZLES = os.path.join(ROOT, "assets", "puzzles")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res", "values", "games-ids.xml")
CONFIG = os.path.join(ROOT, "assets", "config", "leaderboards.json")


def puzzle_ids():
    return sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(PUZZLES, "*.png")))


def title(puzzle_id):
    """blue_gems → Blue Gems, as the game titles pictures."""
    return " ".join(w[:1].upper() + w[1:] for w in puzzle_id.split("_") if w)


def squash(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("export", nargs="?", help="games-ids.xml from Play Console")
    ap.add_argument("--names", action="store_true", help="print the leaderboard names to create")
    args = ap.parse_args()

    ids = puzzle_ids()
    if args.names or not args.export:
        print(f"{len(ids)} leaderboards (Play Games allows 70), named like the pictures:")
        for puzzle_id in ids:
            print(f"  {title(puzzle_id)}")
        return

    with open(args.export, encoding="utf-8") as f:
        xml = f.read()
    strings = {e.get("name"): (e.text or "").strip() for e in ET.fromstring(xml).iter("string")}
    app_id = strings.get("app_id", "")
    if not app_id.isdigit():
        sys.exit(f"{args.export}: app_id {app_id!r} should be the numeric Play Games project ID")

    by_squashed = {squash(p): p for p in ids}
    boards, unmatched = {}, []
    for name, value in strings.items():
        if not name.startswith("leaderboard_"):
            continue
        puzzle_id = by_squashed.get(squash(name[len("leaderboard_"):]))
        if puzzle_id:
            boards[puzzle_id] = value
        else:
            unmatched.append(name)

    with open(RES, "w", encoding="utf-8") as f:
        f.write(xml)
    with open(CONFIG, "w", encoding="utf-8") as f:
        json.dump({
            "_about": "Google Play Games leaderboard IDs per picture. Made by tool/import_games_ids.py "
                      "from the Play Console export; don't edit by hand.",
            "app_id": app_id,
            "leaderboards": dict(sorted(boards.items())),
        }, f, indent=2)
        f.write("\n")

    print(f"app ID {app_id}; {len(boards)} of {len(ids)} pictures have a leaderboard")
    for name in unmatched:
        print(f"  no picture for {name}: name it exactly like a picture title")
    for puzzle_id in ids:
        if puzzle_id not in boards:
            print(f"  no leaderboard yet for {title(puzzle_id)}")
    print(f"wrote {os.path.relpath(RES, ROOT)} and {os.path.relpath(CONFIG, ROOT)}")


if __name__ == "__main__":
    main()
