import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'color_names.dart';
import 'difficulty.dart';

/// One line of the color guide, e.g. `3 → Light Blue`.
class PaletteEntry {
  PaletteEntry({required this.number, required this.color})
      : name = colorName(color),
        shade = _grayscaleShade(color);

  /// 1-based number printed on the cells and the swatch.
  final int number;
  final Color color;
  final String name;

  /// The gray that stands in for [color] on cells that aren't painted yet, so
  /// the picture shows up as a black-and-white version of itself.
  final Color shade;

  static Color _grayscaleShade(Color c) {
    final luma = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    // Squeeze into a light band so the numbers on top stay readable.
    final v = 0.55 + 0.42 * luma;
    return Color.from(alpha: 1, red: v, green: v, blue: v);
  }
}

/// A pixel-art picture turned into a color-by-number grid.
class Puzzle {
  Puzzle._({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.cells,
    required this.palette,
  })  : paintableCount = cells.where((c) => c != 0).length,
        difficulty = Difficulty.classify(
          colorCount: palette.length,
          cellCount: cells.where((c) => c != 0).length,
        ),
        fingerprint = _fingerprint(width, height, cells, palette);

  /// Builds a puzzle from straight (non-premultiplied) RGBA pixels.
  ///
  /// Every distinct opaque color becomes one palette number; transparent
  /// pixels become empty cells. Fully transparent borders are trimmed off.
  factory Puzzle.fromRgba({
    required String id,
    required String name,
    required int width,
    required int height,
    required Uint8List rgba,
  }) {
    if (rgba.length != width * height * 4) {
      throw ArgumentError('Expected ${width * height * 4} RGBA bytes, got ${rgba.length}.');
    }
    bool opaque(int x, int y) => rgba[(y * width + x) * 4 + 3] >= 128;

    var minX = width, minY = height, maxX = -1, maxY = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!opaque(x, y)) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0) throw ArgumentError('Puzzle "$id" has no opaque pixels.');

    final w = maxX - minX + 1;
    final h = maxY - minY + 1;
    final argbAt = List<int>.filled(w * h, 0);
    final distinct = <int>{};
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!opaque(minX + x, minY + y)) continue;
        final o = ((minY + y) * width + minX + x) * 4;
        final argb = 0xFF000000 | rgba[o] << 16 | rgba[o + 1] << 8 | rgba[o + 2];
        argbAt[y * w + x] = argb;
        distinct.add(argb);
      }
    }

    if (distinct.length > 255) {
      throw ArgumentError('Puzzle "$id" has ${distinct.length} colors; 255 is the limit.');
    }
    final colors = distinct.map(Color.new).toList()..sort(_paletteOrder);
    final numberOf = {for (var i = 0; i < colors.length; i++) colors[i].toARGB32(): i + 1};
    final cells = Uint16List(w * h);
    for (var i = 0; i < cells.length; i++) {
      if (argbAt[i] != 0) cells[i] = numberOf[argbAt[i]]!;
    }

    return Puzzle._(
      id: id,
      name: name,
      width: w,
      height: h,
      cells: cells,
      palette: [
        for (var i = 0; i < colors.length; i++) PaletteEntry(number: i + 1, color: colors[i]),
      ],
    );
  }

  final String id;
  final String name;
  final int width;
  final int height;

  /// Row-major palette numbers (1-based); 0 marks an empty cell.
  final Uint16List cells;
  final List<PaletteEntry> palette;
  final int paintableCount;
  final Difficulty difficulty;

  /// Changes whenever the picture changes, so stale saved progress is dropped.
  final int fingerprint;

  PaletteEntry entry(int number) => palette[number - 1];

  /// Grays first, then by hue, dark to light inside each hue, so similar
  /// shades get neighbouring numbers.
  static int _paletteOrder(Color a, Color b) {
    final ha = HSLColor.fromColor(a), hb = HSLColor.fromColor(b);
    final byGroup = _hueGroup(ha).compareTo(_hueGroup(hb));
    if (byGroup != 0) return byGroup;
    return ha.lightness.compareTo(hb.lightness);
  }

  static int _hueGroup(HSLColor c) =>
      c.saturation < 0.15 ? -1 : ((c.hue + 15) % 360 / 30).floor();

  static int _fingerprint(int w, int h, Uint16List cells, List<PaletteEntry> palette) {
    // Rolling hash kept under 2^30 so it is exact on the web too.
    var hash = 17;
    void mix(int v) => hash = (hash * 31 + v) & 0x3FFFFFFF;
    mix(w);
    mix(h);
    cells.forEach(mix);
    for (final e in palette) {
      mix(e.color.toARGB32());
    }
    return hash;
  }
}
