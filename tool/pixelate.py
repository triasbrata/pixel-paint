"""Turn a pixel-art style picture into a color-by-number puzzle PNG.

Big AI-generated "pixel art" isn't on a clean grid and has thousands of colors
(JPEG noise, glows, gradients). This shrinks it to a small grid, reduces it to a
fixed palette, and cleans up specks that would be tedious to paint.

    python3 tool/pixelate.py in.jpg -o assets/puzzles/shiba.png --width 64 --colors 12

Needs Pillow and NumPy (`pip install pillow numpy`).
"""
import argparse

import numpy as np
from PIL import Image


def srgb_to_lab(rgb):
    """sRGB in 0..1 → CIE Lab, so color distances match what eyes see."""
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def nearest(points, centers, chunk=100_000):
    out = np.empty(len(points), dtype=np.int32)
    for s in range(0, len(points), chunk):
        p = points[s:s + chunk]
        out[s:s + chunk] = ((p[:, None, :] - centers[None]) ** 2).sum(-1).argmin(1)
    return out


def kmeans(points, k, iters=40, seed=1):
    rng = np.random.default_rng(seed)
    # k-means++ seeding.
    centers = [points[rng.integers(len(points))]]
    d2 = ((points - centers[0]) ** 2).sum(1)
    for _ in range(1, k):
        if d2.sum() == 0:
            break
        centers.append(points[rng.choice(len(points), p=d2 / d2.sum())])
        d2 = np.minimum(d2, ((points - centers[-1]) ** 2).sum(1))
    centers = np.array(centers)
    for _ in range(iters):
        labels = nearest(points, centers)
        new = np.array([points[labels == j].mean(0) if (labels == j).any() else centers[j]
                        for j in range(len(centers))])
        if np.abs(new - centers).max() < 0.05:
            break
        centers = new
    return centers


def block_mode(labels, cell, weights):
    """Most common label in each cell×cell block, with per-label weights."""
    k = len(weights)
    h, w = labels.shape[0] // cell, labels.shape[1] // cell
    blocks = labels[:h * cell, :w * cell].reshape(h, cell, w, cell).transpose(0, 2, 1, 3).reshape(h, w, -1)
    counts = np.zeros((h, w, k), dtype=np.int32)
    for j in range(k):
        counts[..., j] = (blocks == j).sum(-1)
    return (counts * weights).argmax(-1)


def remove_specks(grid, passes=2):
    """A cell that matches none of its 4 neighbours takes the most common neighbour color."""
    h, w = grid.shape
    for _ in range(passes):
        changed = 0
        padded = np.pad(grid, 1, mode="edge")
        out = grid.copy()
        for y in range(h):
            for x in range(w):
                c = grid[y, x]
                n4 = [padded[y, x + 1], padded[y + 2, x + 1], padded[y + 1, x], padded[y + 1, x + 2]]
                if c in n4:
                    continue
                n8 = padded[y:y + 3, x:x + 3].ravel()
                n8 = np.delete(n8, 4)
                vals, counts = np.unique(n8, return_counts=True)
                out[y, x] = vals[counts.argmax()]
                changed += 1
        grid = out
        if not changed:
            break
    return grid


def merge_colors(grid, lab, min_cells, min_delta):
    """Folds rare colors and near-identical shades into their closest neighbour."""
    while True:
        used, counts = np.unique(grid, return_counts=True)
        if len(used) <= 2:
            return grid
        sub = lab[used]
        dist = np.sqrt(((sub[:, None] - sub[None]) ** 2).sum(-1))
        np.fill_diagonal(dist, np.inf)
        rare = counts.argmin()
        if counts[rare] < min_cells:
            src, dst = rare, dist[rare].argmin()
        else:
            i, j = np.unravel_index(dist.argmin(), dist.shape)
            if dist[i, j] >= min_delta:
                return grid
            # Keep the more common of the two shades.
            src, dst = (i, j) if counts[i] < counts[j] else (j, i)
        grid = np.where(grid == used[src], used[dst], grid)


def pixelate(path, width, colors, method="mode", min_cells=4, min_delta=6.0, crop=None, outline_boost=2.0):
    img = Image.open(path).convert("RGB")
    if crop:
        img = img.crop(crop)
    height = max(1, round(width * img.height / img.width))

    if method == "box":
        small = np.asarray(img.resize((width, height), Image.BOX), dtype=np.float64) / 255
        lab = srgb_to_lab(small).reshape(-1, 3)
        centers = kmeans(lab, colors)
        grid = nearest(lab, centers).reshape(height, width)
        rgb_flat = small.reshape(-1, 3)
    else:
        # Sample each target cell at sub×sub, quantize the samples, and give
        # each cell its most common color: crisp colors, no blended edges.
        sub = 6
        mid = np.asarray(img.resize((width * sub, height * sub), Image.BOX), dtype=np.float64) / 255
        lab_mid = srgb_to_lab(mid).reshape(-1, 3)
        rng = np.random.default_rng(0)
        sample = lab_mid[rng.choice(len(lab_mid), min(len(lab_mid), 60_000), replace=False)]
        centers = kmeans(sample, colors)
        labels = nearest(lab_mid, centers).reshape(height * sub, width * sub)
        # Thin dark outlines rarely fill half a block; weight them up so the
        # shapes keep their edges.
        weights = np.where(centers[:, 0] < 28, outline_boost, 1.0)
        grid = block_mode(labels, sub, weights)
        rgb_flat = mid.reshape(-1, 3)
        lab = lab_mid
        grid_labels_for_color = labels.ravel()

    grid = remove_specks(grid)
    grid = merge_colors(grid, centers, min_cells, min_delta)
    grid = remove_specks(grid, passes=1)

    # Each palette color is the average of the source pixels in its cluster.
    src_labels = grid_labels_for_color if method != "box" else grid.ravel()
    palette = np.zeros((len(centers), 3))
    for j in np.unique(grid):
        members = rgb_flat[src_labels == j]
        palette[j] = members.mean(0) if len(members) else 0
    out = (palette[grid] * 255).round().clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGB"), len(np.unique(grid))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--width", type=int, default=64, help="grid width in cells (height keeps the aspect ratio)")
    ap.add_argument("--colors", type=int, default=16, help="palette size before merging similar shades")
    ap.add_argument("--method", choices=["mode", "box"], default="mode")
    ap.add_argument("--min-cells", type=int, default=4, help="merge colors used by fewer cells than this")
    ap.add_argument("--min-delta", type=float, default=6.0, help="merge colors closer than this (CIE ΔE)")
    ap.add_argument("--outline-boost", type=float, default=2.0, help="weight of very dark colors when picking a cell's color")
    ap.add_argument("--crop", help="left,top,right,bottom in source pixels")
    ap.add_argument("--preview", help="also write an enlarged preview PNG here")
    args = ap.parse_args()

    crop = tuple(int(v) for v in args.crop.split(",")) if args.crop else None
    puzzle, n = pixelate(args.input, args.width, args.colors, args.method, args.min_cells, args.min_delta, crop, args.outline_boost)
    puzzle.save(args.output)
    if args.preview:
        scale = max(1, 960 // puzzle.width)
        puzzle.resize((puzzle.width * scale, puzzle.height * scale), Image.NEAREST).save(args.preview)
    print(f"{args.output}: {puzzle.width}x{puzzle.height}, {n} colors")


if __name__ == "__main__":
    main()
