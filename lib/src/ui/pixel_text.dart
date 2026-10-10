import 'package:flutter/painting.dart';

import 'pixel_scale.dart';

/// The palette of the UI text, from the Kenmi pack.
abstract final class PixelInk {
  static const outline = Color(0xFF3F2832);
  static const button = Color(0xFF3B2210);
  static const cream = Color(0xFFFFF1D6);
  static const parchment = Color(0xFFF6CA9F);
  static const brown = Color(0xFF8A4836);
  static const darkBrown = Color(0xFF5D2C28);
  static const green = Color(0xFF3E8948);
  static const gold = Color(0xFFFFB300);
}

/// Where a text's anchor point sits on it.
enum TextAnchor { topLeft, topCenter, center, centerLeft, centerRight, bottomCenter }

/// Poh Sans drawn on its own 11-px grid: one font pixel is a whole number of
/// device pixels (see [PixelScale.fontPixel]), optionally with a one-font-pixel
/// outline all around, the way pixel games letter their UI.
class PixelText {
  PixelText(this.scale);

  final PixelScale scale;
  final _cache = <(String, double, int, FontWeight), TextPainter>{};

  static const family = 'PohSans';

  /// Size of [text] at [level] (the outline adds one font pixel each side).
  Size measure(String text, TextLevel level, {FontWeight weight = FontWeight.w700, bool outline = true}) {
    final px = scale.fontPixel(level);
    final size = _layout(text, px, const Color(0xFF000000), weight).size;
    return outline ? Size(size.width + 2 * px, size.height + 2 * px) : size;
  }

  /// Breaks [text] into lines no wider than [width].
  List<String> wrap(String text, TextLevel level, double width, {FontWeight weight = FontWeight.w700}) {
    final lines = <String>[];
    var line = '';
    for (final word in text.split(' ')) {
      final next = line.isEmpty ? word : '$line $word';
      if (line.isNotEmpty && measure(next, level, weight: weight, outline: false).width > width) {
        lines.add(line);
        line = word;
      } else {
        line = next;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }

  /// Draws [text] at [at] (placed by [anchor]); returns its box.
  Rect draw(
    Canvas canvas,
    String text,
    Offset at, {
    TextLevel level = TextLevel.normal,
    Color color = PixelInk.cream,
    Color? outline = PixelInk.outline,
    FontWeight weight = FontWeight.w700,
    TextAnchor anchor = TextAnchor.topLeft,
    double opacity = 1,
  }) {
    final px = scale.fontPixel(level);
    final fill = _layout(text, px, color, weight);
    final pad = outline == null ? 0.0 : px;
    final box = Size(fill.width + 2 * pad, fill.height + 2 * pad);
    final topLeft = scale.snapOffset(switch (anchor) {
      TextAnchor.topLeft => at,
      TextAnchor.topCenter => at - Offset(box.width / 2, 0),
      TextAnchor.center => at - Offset(box.width / 2, box.height / 2),
      TextAnchor.centerLeft => at - Offset(0, box.height / 2),
      TextAnchor.centerRight => at - Offset(box.width, box.height / 2),
      TextAnchor.bottomCenter => at - Offset(box.width / 2, box.height),
    });
    if (opacity < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    final origin = topLeft + Offset(pad, pad);
    if (outline != null) {
      final ring = _layout(text, px, outline, weight);
      for (final d in const [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]) {
        ring.paint(canvas, origin + Offset(d.$1 * px, d.$2 * px));
      }
    }
    fill.paint(canvas, origin);
    if (opacity < 1) canvas.restore();
    return topLeft & box;
  }

  TextPainter _layout(String text, double px, Color color, FontWeight weight) {
    final key = (text, px, color.toARGB32(), weight);
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_cache.length > 600) _cache.clear(); // scores and counts change a lot
    return _cache[key] = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontSize: 11 * px,
          height: 1,
          color: color,
          fontWeight: weight,
          fontFeatures: const [FontFeature.disable('liga'), FontFeature.disable('calt')],
        ),
      ),
    )..layout();
  }
}
