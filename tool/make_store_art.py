"""Store graphics for Google Play and itch.io, from the screenshots that
tool/store_screenshots_test.dart renders (run tool/update_store_art.sh for both).

    python3 tool/make_store_art.py

Writes
  android/fastlane/metadata/android/en-US/images/   Google Play (fastlane supply layout)
      icon.png                512x512 hi-res icon
      featureGraphic.png      1024x500
      phoneScreenshots/       1080x1920, captioned
      sevenInchScreenshots/   1920x1080, captioned
      tenInchScreenshots/     2560x1440, captioned
  store/itch/                 itch.io
      cover.png               630x500 cover image
      banner.png              960x240 page banner
      screenshots/            1920x1200, plain

Captions count the puzzles in assets/puzzles, so they stay true as puzzles are
added. Fonts: Pixelify Sans and Nunito (SIL OFL) in tool/fonts. Needs Pillow.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_icon import default_font, draw_sprite, load_sprite, shade  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "build", "store", "raw")
PLAY = os.path.join(ROOT, "android", "fastlane", "metadata", "android", "en-US", "images")
ITCH = os.path.join(ROOT, "store", "itch")
FONTS = os.path.join(ROOT, "tool", "fonts")
PUZZLES = os.path.join(ROOT, "assets", "puzzles")

LAVENDER = (239, 231, 255)
PINK = (255, 227, 239)
INK = (46, 31, 94)        # titles
INK_SOFT = (92, 75, 138)  # subtitles
BEZEL = (31, 26, 46)
ACCENT = (124, 77, 255)   # the app's seed color


def puzzle_stats():
    """(number of puzzles, fewest colors, most colors) in assets/puzzles."""
    counts = []
    for path in glob.glob(os.path.join(PUZZLES, "*.png")):
        img = Image.open(path).convert("RGBA")
        counts.append(len({p[:3] for p in img.get_flattened_data() if p[3] >= 128}))
    return len(counts), min(counts), max(counts)


def captions():
    n, fewest, most = puzzle_stats()
    return {
        "1_paint": ("Color pixel art by number", "Pick a color, then tap or drag over its cells"),
        "2_combo": ("Paint fast, combo up to 20x", "Quick, correct cells multiply your points"),
        "3_zoom": ("Zoom in on every detail", "The mini map always shows where you are"),
        "4_fill": ("Pencil or Fill", "Fill paints a whole area of one number at once"),
        "5_home": (f"{n} pictures to paint", f"From {fewest} colors to {most}, easy to expert"),
        "6_done": ("Finish it, beat your best", "A leaderboard for every picture"),
        "7_admire": ("Cozy music, no ads", "Play offline, anytime"),
    }


# --- Drawing helpers ------------------------------------------------------------

def font(name, size, weight):
    f = ImageFont.truetype(os.path.join(FONTS, name), size)
    f.set_variation_by_axes([weight])
    return f


def gradient(size, start=LAVENDER, end=PINK, horizontal=False):
    w, h = size
    ramp = Image.linear_gradient("L")  # dark to light, top to bottom
    if horizontal:
        ramp = ramp.transpose(Image.TRANSPOSE)  # left to right
    ramp = ramp.resize((w, h))
    return Image.composite(Image.new("RGB", size, end), Image.new("RGB", size, start), ramp)


def confetti(canvas, seed, count, cell, alpha=60):
    """Faint pixel squares scattered over the background, like loose cells."""
    import random
    rnd = random.Random(seed)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    colors = [(124, 77, 255), (255, 112, 166), (255, 183, 77), (77, 182, 172), (100, 181, 246)]
    w, h = canvas.size
    for _ in range(count):
        x, y = rnd.randrange(w), rnd.randrange(h)
        s = cell * rnd.choice((1, 1, 1, 2))
        draw.rectangle((x, y, x + s - 1, y + s - 1), fill=rnd.choice(colors) + (alpha,))
    canvas.paste(layer, (0, 0), layer)


def drop_shadow(canvas, box, radius, blur, offset, alpha):
    x0, y0, x1, y1 = box
    pad = blur * 3
    mask = Image.new("L", (x1 - x0 + 2 * pad, y1 - y0 + 2 * pad), 0)
    ImageDraw.Draw(mask).rounded_rectangle((pad, pad, pad + x1 - x0, pad + y1 - y0), radius, fill=alpha)
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    shadow = Image.new("RGB", mask.size, (60, 30, 90))
    canvas.paste(shadow, (x0 - pad + offset[0], y0 - pad + offset[1]), mask)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def device(screen, bezel, radius):
    """The screenshot inside a dark device bezel."""
    w, h = screen.width + 2 * bezel, screen.height + 2 * bezel
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, w - 1, h - 1), radius + bezel, fill=BEZEL + (255,))
    body.alpha_composite(rounded(screen, radius), (bezel, bezel))
    return body


def centered_text(draw, y, text, fnt, fill, width):
    x0, _, x1, _ = draw.textbbox((0, 0), text, font=fnt)
    draw.text(((width - (x1 - x0)) / 2 - x0, y), text, font=fnt, fill=fill)


def fit_text(text, name, size, weight, max_width):
    while size > 10:
        f = font(name, size, weight)
        if f.getlength(text) <= max_width:
            return f
        size -= 2
    return font(name, size, weight)


# --- Screenshots ----------------------------------------------------------------

def captioned(shot, size, title, subtitle, *, portrait, seed):
    """A store screenshot: caption on top, the app below in a device frame."""
    w, h = size
    k = w / 1080 if portrait else w / 2560  # scale everything with the canvas
    canvas = gradient(size)
    confetti(canvas, seed, 70, round(14 * k))
    draw = ImageDraw.Draw(canvas)

    top = round(110 * k) if portrait else round(70 * k)
    title_font = fit_text(title, "Nunito.ttf", round((80 if portrait else 104) * k), 900, w - 2 * round(60 * k))
    sub_font = fit_text(subtitle, "Nunito.ttf", round((40 if portrait else 52) * k), 650, w - 2 * round(60 * k))
    centered_text(draw, top, title, title_font, INK, w)
    sub_y = top + round((112 if portrait else 138) * k)
    centered_text(draw, sub_y, subtitle, sub_font, INK_SOFT, w)

    frame_top = sub_y + round((110 if portrait else 100) * k)
    bezel = round((18 if portrait else 20) * k)
    max_w = round((860 if portrait else 2200) * k) - 2 * bezel
    max_h = h - frame_top - round((70 if portrait else 60) * k) - 2 * bezel
    scale = min(max_w / shot.width, max_h / shot.height)
    screen = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
    phone = device(screen, bezel, round((44 if portrait else 30) * k))
    x = (w - phone.width) // 2
    drop_shadow(canvas, (x, frame_top, x + phone.width, frame_top + phone.height),
                round(60 * k), round(28 * k), (0, round(18 * k)), 110)
    canvas.paste(phone, (x, frame_top), phone)
    return canvas


def screenshots():
    texts = captions()
    jobs = [
        ("phone", "phoneScreenshots", (1080, 1920), True),
        ("tablet", "tenInchScreenshots", (2560, 1440), False),
    ]
    for kind, folder, size, portrait in jobs:
        out_dir = os.path.join(PLAY, folder)
        os.makedirs(out_dir, exist_ok=True)
        for old in glob.glob(os.path.join(out_dir, "*.png")) + glob.glob(os.path.join(PLAY, "sevenInchScreenshots", "*.png")):
            os.remove(old)
        for n, name in enumerate(sorted(texts), 1):
            shot = Image.open(os.path.join(RAW, kind, f"{name}.png")).convert("RGB")
            title, subtitle = texts[name]
            img = captioned(shot, size, title, subtitle, portrait=portrait, seed=n)
            img.save(os.path.join(out_dir, f"{name}.png"), optimize=True)
            if kind == "tablet":
                seven = os.path.join(PLAY, "sevenInchScreenshots")
                os.makedirs(seven, exist_ok=True)
                img.resize((1920, 1080), Image.LANCZOS).save(os.path.join(seven, f"{name}.png"), optimize=True)

    # itch.io: the plain tablet screenshots; the page itself explains them.
    out_dir = os.path.join(ITCH, "screenshots")
    os.makedirs(out_dir, exist_ok=True)
    for old in glob.glob(os.path.join(out_dir, "*.png")):
        os.remove(old)
    for n, name in enumerate(["3_zoom", "2_combo", "1_paint", "4_fill", "5_home", "7_admire"], 1):
        shot = Image.open(os.path.join(RAW, "tablet", f"{name}.png")).convert("RGB")
        label = name.split("_", 1)[1]
        shot.resize((1920, 1200), Image.LANCZOS).save(os.path.join(out_dir, f"{n}_{label}.png"), optimize=True)


# --- Key art --------------------------------------------------------------------

def sprite_art(name, cell, numbers_font):
    """A puzzle sprite drawn like the app icon: half painted, half numbered."""
    return draw_sprite(load_sprite(os.path.join(PUZZLES, f"{name}.png")), cell, numbers_font)


def sticker(name, cell):
    """A finished sprite, pixel-exact, with a soft shadow."""
    img = load_sprite(os.path.join(PUZZLES, f"{name}.png"))
    return img.resize((img.width * cell, img.height * cell), Image.NEAREST)


def paste_with_shadow(canvas, img, xy, blur, offset, alpha=70):
    mask = img.getchannel("A").point(lambda a: alpha if a else 0)
    pad = blur * 3
    big = Image.new("L", (img.width + 2 * pad, img.height + 2 * pad), 0)
    big.paste(mask, (pad, pad))
    big = big.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new("RGB", big.size, (60, 30, 90)), (xy[0] - pad + offset[0], xy[1] - pad + offset[1]), big)
    canvas.paste(img, xy, img)


def title_text(draw, xy, text, size, anchor="la"):
    """'Pixel Paint' in the pixel font, with a hard pixel shadow."""
    f = font("PixelifySans.ttf", size, 700)
    off = max(2, size // 24)
    draw.text((xy[0] + off, xy[1] + off), text, font=f, fill=(255, 255, 255), anchor=anchor)
    draw.text(xy, text, font=f, fill=INK, anchor=anchor)
    return f


def feature_graphic(numbers_font):
    w, h = 1024, 500
    canvas = gradient((w, h), horizontal=True)
    confetti(canvas, 7, 60, 10)
    draw = ImageDraw.Draw(canvas)
    # Text on the left half, the picture on the right; nothing near the edges,
    # where Play may crop.
    title_text(draw, (64, 170), "Pixel Paint", 92)
    tagline = font("Nunito.ttf", 34, 800)
    draw.text((68, 290), "Color pixel art by number", font=tagline, fill=INK_SOFT)

    hero = sprite_art("lollipop", 22, numbers_font)
    hx, hy = w - hero.width - 90, (h - hero.height) // 2
    paste_with_shadow(canvas, hero, (hx, hy), 12, (0, 12))
    for name, xy in [("lemon", (430, 50)), ("blue_gems", (440, 375)), ("red_potion", (hx + hero.width - 80, 395))]:
        paste_with_shadow(canvas, sticker(name, 5), xy, 6, (0, 6), 60)
    canvas.save(os.path.join(PLAY, "featureGraphic.png"), optimize=True)


def itch_cover(numbers_font):
    w, h = 630, 500
    canvas = gradient((w, h))
    confetti(canvas, 3, 40, 8)
    draw = ImageDraw.Draw(canvas)
    title_text(draw, (w // 2, 42), "Pixel Paint", 92, anchor="mt")
    hero = sprite_art("cherries", 19, numbers_font)
    paste_with_shadow(canvas, hero, ((w - hero.width) // 2, 158), 10, (0, 10))
    for name, xy in [("lemon", (34, 300)), ("blue_gems", (500, 300))]:
        paste_with_shadow(canvas, sticker(name, 6), xy, 6, (0, 6), 60)
    canvas.save(os.path.join(ITCH, "cover.png"), optimize=True)


def itch_banner():
    w, h = 960, 240
    canvas = gradient((w, h), horizontal=True)
    confetti(canvas, 11, 50, 8)
    draw = ImageDraw.Draw(canvas)
    f = title_text(draw, (w // 2, 62), "Pixel Paint", 84, anchor="mt")
    tag = font("Nunito.ttf", 26, 800)
    centered_text(draw, 166, "Color pixel art by number", tag, INK_SOFT, w)
    # Two finished pictures on each side of the title (numbers would be specks
    # at this size), centered in the space left.
    half = f.getlength("Pixel Paint") / 2
    for names, (lo, hi) in [(("lemon", "cherries"), (0, w / 2 - half)), (("mushroom", "lollipop"), (w / 2 + half, w))]:
        imgs = [sticker(n, 6) for n in names]
        gap = 18
        x = round((lo + hi - sum(i.width for i in imgs) - gap) / 2)
        for img in imgs:
            paste_with_shadow(canvas, img, (x, (h - img.height) // 2), 5, (0, 5), 60)
            x += img.width + gap
    canvas.save(os.path.join(ITCH, "banner.png"), optimize=True)


def play_icon():
    icon = Image.open(os.path.join(ROOT, "assets", "icon", "icon_ios.png")).convert("RGB")
    # Full square: Google Play rounds the corners itself.
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(PLAY, "icon.png"), optimize=True)


def main():
    if not os.path.isdir(RAW):
        sys.exit(f"{RAW} is missing: run `flutter test tool/store_screenshots_test.dart` first")
    os.makedirs(PLAY, exist_ok=True)
    os.makedirs(ITCH, exist_ok=True)
    numbers_font = default_font()
    screenshots()
    feature_graphic(numbers_font)
    itch_cover(numbers_font)
    itch_banner()
    play_icon()
    print("Google Play:", os.path.relpath(PLAY, ROOT))
    print("itch.io:    ", os.path.relpath(ITCH, ROOT))


if __name__ == "__main__":
    main()
