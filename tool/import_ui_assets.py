"""Copies the pixel art the game's UI is built from out of the owner's Path of
Hero repo (and the Cute Fantasy Icons pack), and makes the derived sheets.

    python3 tool/import_ui_assets.py                       # ~/dev/tower-defense
    python3 tool/import_ui_assets.py --td PATH --icons PATH

Only reads from the sources. Writes assets/ui/, assets/sprites/, assets/sfx/ and
assets/fonts/. Every pack is licensed to the owner for use in their own games
but not for redistribution: never publish these folders (see README, "Asset
license"). Needs Pillow.

Derived art:
  sprites/slime.png  the Tiny RPG slime, cropped to 44x28 frames (rows: idle,
                     walk, attack, hurt) and given a face: eyes and blush.
  ui/tools.png       the pencil and the paint bucket from the Tools icons.
"""
import argparse
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.expanduser("~")

# (source relative to the tower-defense repo, destination relative to assets/)
COPIES = [
    ("raw_assets/Cute_Fantasy_UI/UI/UI_Buttons.png", "ui/buttons.png"),
    ("raw_assets/Cute_Fantasy_UI/UI/UI_Button_Icons.png", "ui/button_icons.png"),
    ("assets/images/ui_icons.png", "ui/icons.png"),
    ("assets/images/ui_book.png", "ui/book.png"),
    ("assets/images/ui_book_marks.png", "ui/book_marks.png"),
    ("assets/images/ui_ribbons.png", "ui/ribbons.png"),
    ("raw_assets/Cute_Fantasy_UI/UI/UI_Frames.png", "ui/frames.png"),
    ("assets/images/ui_bars.png", "ui/bars.png"),
    ("raw_assets/Cute_Fantasy_UI/UI/UI_Pop_Up.png", "ui/pop_up.png"),
    ("raw_assets/Cute_Fantasy_UI/UI/UI_Selectors.png", "ui/selectors.png"),
    ("raw_assets/Cute_Fantasy_UI/UI/UI_Crosshairs.png", "ui/crosshairs.png"),
    ("assets/images/ui_click.png", "ui/click.png"),
    ("assets/images/ui_loading.png", "ui/loading.png"),
    ("assets/fonts/PohSans.ttf", "fonts/PohSans.ttf"),
    ("assets/fonts/OFL-PohSans.txt", "fonts/OFL-PohSans.txt"),
] + [
    (f"raw_sprites/gandalfhardcore-platformer/{name}.png", f"sprites/{dest}.png")
    for name, dest in [
        ("cloud1", "cloud1"), ("cloud2", "cloud2"), ("cloud3", "cloud3"), ("cloud4", "cloud4"),
        ("cloud5", "cloud5"), ("cloud6", "cloud6"), ("sun", "sun"), ("birds1", "birds1"),
        ("birds2", "birds2"), ("hot air balloon", "balloon"),
    ]
] + [
    (f"assets/sfx/{name}.wav", f"sfx/{name}.wav")
    for name in ["click", "kill", "magic", "clear", "error", "place"]
]

SLIME_ROWS = ["idle", "walk", "attack", "hurt"]
SLIME_FRAME = (44, 28)
SLIME_CROP = (30, 34)  # top-left of the 44x28 window inside each 100x100 frame

EYE = (43, 29, 41, 255)
SHINE = (255, 255, 255, 255)
BLUSH = (255, 140, 160, 210)

# Tools_all_16x16.png cells: (column, row)
PENCIL = (3, 52)
BUCKET = (5, 49)


def face(frame):
    """Draws two big eyes with a shine and pink cheeks on the slime's front
    (it faces right), on the light top of its body."""
    px = frame.load()
    w, h = frame.size
    solid = [(x, y) for x in range(w) for y in range(h) if px[x, y][3]]
    if not solid:
        return frame
    left = min(x for x, _ in solid)
    right = max(x for x, _ in solid)
    front = left + round((right - left) * 0.62)
    top = min(y for x, y in solid if abs(x - front) <= 3)
    bottom = max(y for x, y in solid if x == front)
    eye_y = min(top + 4, bottom - 4)

    def put(x, y, color):
        if 0 <= x < w and 0 <= y < h and px[x, y][3]:
            px[x, y] = color

    for ex in (front - 3, front + 2):
        for dx in (0, 1):
            for dy in (0, 1):
                put(ex + dx, eye_y + dy, EYE)
        put(ex, eye_y, SHINE)
    for bx in (front - 5, front + 4):
        put(bx, eye_y + 2, BLUSH)
        put(bx + 1, eye_y + 2, BLUSH)
    return frame


def slime_sheet(td):
    fw, fh = SLIME_FRAME
    strips = [Image.open(os.path.join(td, f"assets/images/tiny_slime_{row}.png")).convert("RGBA")
              for row in SLIME_ROWS]
    cols = max(s.width // 100 for s in strips)
    sheet = Image.new("RGBA", (fw * cols, fh * len(strips)), (0, 0, 0, 0))
    cx, cy = SLIME_CROP
    for r, strip in enumerate(strips):
        for f in range(strip.width // 100):
            frame = strip.crop((f * 100 + cx, cy, f * 100 + cx + fw, cy + fh))
            # The hurt frames flash red: no face on the flash frame.
            if not (SLIME_ROWS[r] == "hurt" and f == 1):
                frame = face(frame)
            sheet.alpha_composite(frame, (f * fw, r * fh))
    return sheet


def tools_sheet(icons):
    src = Image.open(os.path.join(icons, "Cute_Fantasy_Icons_Tools/16x16/Tools_all_16x16.png")).convert("RGBA")
    sheet = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    for i, (c, r) in enumerate([PENCIL, BUCKET]):
        sheet.alpha_composite(src.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16)), (i * 16, 0))
    return sheet


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--td", default=os.path.join(HOME, "dev/tower-defense"), help="Path of Hero repo")
    ap.add_argument("--icons", default=os.path.join(HOME, ".cache/td-agents/packs/Cute_Fantasy_Icons_Premium"),
                    help="Cute Fantasy Icons Premium pack")
    args = ap.parse_args()

    assets = os.path.join(ROOT, "assets")
    for src, dest in COPIES:
        out = os.path.join(assets, dest)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        shutil.copyfile(os.path.join(args.td, src), out)
    slime_sheet(args.td).save(os.path.join(assets, "sprites/slime.png"))
    tools_sheet(args.icons).save(os.path.join(assets, "ui/tools.png"))
    print(f"copied {len(COPIES)} files, made sprites/slime.png and ui/tools.png")


if __name__ == "__main__":
    main()
