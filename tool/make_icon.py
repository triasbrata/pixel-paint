"""Draws the app icon from a pixel sprite: the left half painted, the right half
the way the game shows cells that still need painting — gray, with numbers.

    python3 tool/make_icon.py assets/puzzles/cherries.png \\
        -o assets/icon/icon.png --foreground assets/icon/icon_foreground.png

Every icon is a squircle (a superellipse, the continuous-corner shape of iOS
icons), except where the system cuts the shape itself:

  -o            squircle icon on transparent corners (web, older Android)
  --ios         full square — iOS requires it opaque and masks it to a squircle
  --foreground  Android adaptive icon layers; the launcher picks the shape
  --background  (squircle on Xiaomi/HyperOS), sprite kept inside the safe zone
  --macos       squircle tile with the margin and shadow macOS icons use
  --favicon     small squircle tile with the sprite drawn pixel-exact
Needs Pillow.
"""
import argparse
import colorsys
import os
import shutil

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
TOP = (239, 231, 255)     # lavender
BOTTOM = (255, 227, 239)  # pink
NUMBER = (38, 50, 56)


def default_font():
    flutter = shutil.which("flutter")
    if flutter:
        sdk = os.path.dirname(os.path.dirname(os.path.realpath(flutter)))
        path = os.path.join(sdk, "bin", "cache", "artifacts", "material_fonts", "Roboto-Bold.ttf")
        if os.path.exists(path):
            return path
    return None


def load_sprite(path):
    img = Image.open(path).convert("RGBA")
    box = img.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
    return img.crop(box)


def palette_numbers(img):
    """Same numbering as the game: grays first, then by hue, dark to light."""
    colors = {p[:3] for p in img.get_flattened_data() if p[3] >= 128}

    def key(c):
        h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in c))
        group = -1 if s < 0.15 else int(((h * 360 + 15) % 360) // 30)
        return group, l

    return {c: i + 1 for i, c in enumerate(sorted(colors, key=key))}


def shade(c):
    luma = (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255
    v = round((0.55 + 0.42 * luma) * 255)
    return v, v, v


def draw_sprite(img, cell, font_path):
    """The sprite scaled up, half in color and half as numbered gray cells."""
    w, h = img.size
    numbers = palette_numbers(img)
    out = Image.new("RGBA", (w * cell, h * cell), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    fonts = {}
    split = (w + 1) // 2
    grid = max(2, cell // 22)

    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a < 128:
                continue
            box = (x * cell, y * cell, (x + 1) * cell - 1, (y + 1) * cell - 1)
            if x < split:
                draw.rectangle(box, fill=(r, g, b, 255))
                continue
            draw.rectangle(box, fill=shade((r, g, b)) + (255,))
            draw.rectangle(box, outline=(0, 0, 0, 34), width=grid)
            n = numbers[(r, g, b)]
            size = round(cell * (0.42 if n >= 10 else 0.54))
            if size not in fonts:
                fonts[size] = ImageFont.truetype(font_path, size) if font_path else ImageFont.load_default(size)
            draw.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), str(n), font=fonts[size],
                      fill=NUMBER + (255,), anchor="mm")
    return out


def shadow_of(sprite, offset, blur, alpha):
    mask = sprite.getchannel("A").point(lambda a: alpha if a else 0)
    shadow = Image.new("RGBA", sprite.size, (60, 30, 90, 0))
    shadow.putalpha(mask)
    pad = blur * 3
    canvas = Image.new("RGBA", (sprite.width + 2 * pad, sprite.height + 2 * pad), (0, 0, 0, 0))
    canvas.alpha_composite(shadow, (pad, pad))
    return canvas.filter(ImageFilter.GaussianBlur(blur)), (offset[0] - pad, offset[1] - pad)


def gradient():
    grad = Image.linear_gradient("L").resize((SIZE, SIZE))
    return Image.composite(Image.new("RGBA", (SIZE, SIZE), BOTTOM + (255,)),
                           Image.new("RGBA", (SIZE, SIZE), TOP + (255,)), grad)


def squircle_mask(size, n=5.0, supersample=4):
    """Superellipse |x|^n + |y|^n <= 1, anti-aliased by drawing it bigger."""
    big = size * supersample
    mask = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(mask)
    r = big / 2
    for y in range(big):
        dy = abs(y + 0.5 - r) / r
        if dy < 1:
            half = (1 - dy ** n) ** (1 / n) * r
            draw.line([(r - half, y), (r + half - 1, y)], fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def squircle(image):
    out = image.copy()
    out.putalpha(squircle_mask(image.width))
    return out


def macos_tile(icon):
    """macOS icons are a squircle on a transparent canvas, with a margin."""
    tile = 824
    inner = squircle(icon.resize((tile, tile), Image.LANCZOS))
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow, (dx, dy) = shadow_of(inner, (0, 10), 12, 90)
    off = (SIZE - tile) // 2
    canvas.alpha_composite(shadow, (off + dx, off + dy))
    canvas.alpha_composite(inner, (off, off))
    return canvas


def compose(img, box_fraction, font_path, background):
    cell = int(SIZE * box_fraction / max(img.size))
    sprite = draw_sprite(img, cell, font_path)
    canvas = gradient() if background else Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    x = (SIZE - sprite.width) // 2
    y = (SIZE - sprite.height) // 2
    shadow, (dx, dy) = shadow_of(sprite, (0, cell // 2), cell // 2, 70)
    canvas.alpha_composite(shadow, (x + dx, y + dy))
    canvas.alpha_composite(sprite, (x, y))
    return canvas


def favicon(img, size=64):
    """Squircle tile with the half-painted sprite pixel-exact (no numbers): a
    downscaled 1024 icon is just a blur at favicon sizes."""
    w, h = img.size
    pixels = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    split = (w + 1) // 2
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a >= 128:
                pixels.putpixel((x, y), ((r, g, b) if x < split else shade((r, g, b))) + (255,))
    scale = (size * 3 // 4) // max(w, h)
    sprite = pixels.resize((w * scale, h * scale), Image.NEAREST)
    tile = squircle(gradient().resize((size, size), Image.LANCZOS))
    tile.alpha_composite(sprite, ((size - sprite.width) // 2, (size - sprite.height) // 2))
    return tile


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sprite")
    ap.add_argument("-o", "--output", help="squircle icon PNG (1024×1024)")
    ap.add_argument("--ios", help="full-square iOS icon PNG")
    ap.add_argument("--foreground", help="Android adaptive-icon foreground PNG")
    ap.add_argument("--background", help="Android adaptive-icon background PNG")
    ap.add_argument("--macos", help="macOS squircle-tile PNG")
    ap.add_argument("--favicon", help="web favicon PNG")
    ap.add_argument("--font", default=default_font(), help="TTF for the numbers (default: Roboto Bold from Flutter)")
    args = ap.parse_args()

    img = load_sprite(args.sprite)
    icon = compose(img, 0.76, args.font, background=True)
    if args.output:
        squircle(icon).save(args.output)
    if args.ios:
        icon.convert("RGB").save(args.ios)
    if args.foreground:
        # Launchers mask adaptive icons down to a circle ~61% of the canvas wide.
        compose(img, 0.48, args.font, background=False).save(args.foreground)
    if args.background:
        gradient().convert("RGB").save(args.background)
    if args.macos:
        macos_tile(icon).save(args.macos)
    if args.favicon:
        favicon(img).save(args.favicon)
    print(f"{args.sprite}: {img.width}x{img.height} sprite, {len(palette_numbers(img))} colors")


if __name__ == "__main__":
    main()
