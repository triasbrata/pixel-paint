import 'package:flutter/painting.dart';

/// A short, human-friendly English name for [color], e.g. "Light Blue".
///
/// Similar shades can end up with the same name; the palette number is what
/// tells them apart.
String colorName(Color color) {
  final hsl = HSLColor.fromColor(color);
  final l = hsl.lightness;
  final s = hsl.saturation;
  final h = hsl.hue;

  if (s < 0.15 || l < 0.08 || l > 0.95) {
    if (l < 0.15) return 'Black';
    if (l < 0.35) return 'Dark Gray';
    if (l < 0.65) return 'Gray';
    if (l < 0.88) return 'Light Gray';
    return 'White';
  }

  // Browns and beiges are dark or muted oranges and yellows (and muted reds).
  final brownish = (h >= 15 && h < 50 && (l < 0.45 || (s < 0.45 && l < 0.6))) ||
      ((h < 15 || h >= 345) && s < 0.5 && l < 0.45);
  if (brownish) return l < 0.25 ? 'Dark Brown' : 'Brown';
  if (h >= 15 && h < 50 && l > 0.72 && s < 0.7) return 'Beige';
  if ((h < 15 || h >= 330) && l > 0.7) return 'Pink';

  final hueName = switch (h) {
    < 15 => 'Red',
    < 45 => 'Orange',
    < 66 => 'Yellow',
    < 85 => 'Lime',
    < 160 => 'Green',
    < 195 => 'Teal',
    < 250 => 'Blue',
    < 285 => 'Purple',
    < 330 => 'Magenta',
    _ => 'Red',
  };
  // Saturated reds and blues look darker than their HSL lightness says.
  final luma = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
  if (l < 0.36 || (luma < 0.3 && l < 0.45)) return 'Dark $hueName';
  if (l > 0.62) return 'Light $hueName';
  return hueName;
}
