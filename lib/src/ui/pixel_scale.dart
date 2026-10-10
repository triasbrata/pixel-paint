import 'dart:math' as math;
import 'dart:ui';

/// How big one pixel of the UI art is on screen.
///
/// A whole number of device pixels, so every art pixel comes out the same
/// size (no uneven 2-3-2 rows); even on high-density screens, so icons can
/// sit on buttons at exactly half that size ([half]). Positions are snapped
/// to device pixels. About 3 dp on a phone and 4 dp on a tablet, which makes
/// a 16-px button a comfortable touch target; landscape screens go by their
/// height, so a short window still fits the book's rows.
class PixelScale {
  const PixelScale(this.devicePixels, this.devicePixelRatio);

  factory PixelScale.forScreen(Size size, double devicePixelRatio) {
    final landscape = size.width > size.height;
    final target = (landscape ? size.height / 190 : size.shortestSide / 140).clamp(2.5, 4.0);
    final low = devicePixelRatio < 1.5;
    int whole(double device, {required bool up}) {
      if (low) return up ? device.round() : device.floor();
      return (up ? (device / 2).round() : (device / 2).floor()) * 2;
    }

    // Never bigger than 4 dp, whatever rounding to whole pixels does.
    final px = math.min(whole(target * devicePixelRatio, up: true), whole(4.0 * devicePixelRatio, up: false));
    return PixelScale(math.max(2, px), devicePixelRatio);
  }

  /// Device pixels per art pixel.
  final int devicePixels;
  final double devicePixelRatio;

  /// Logical pixels per art pixel.
  double get unit => devicePixels / devicePixelRatio;

  /// Logical pixels per art pixel for icons drawn on buttons: half of [unit].
  double get half => devicePixels / 2 / devicePixelRatio;

  /// [artPixels] in logical pixels.
  double px(num artPixels) => artPixels * unit;

  /// Logical size of one font pixel for text at [level] (see [TextLevel]).
  double fontPixel(TextLevel level) => switch (level) {
        TextLevel.small => math.max(2, devicePixels * 3 ~/ 8) / devicePixelRatio,
        TextLevel.normal => math.max(2, devicePixels ~/ 2) / devicePixelRatio,
        TextLevel.large => math.max(3, devicePixels * 3 ~/ 4) / devicePixelRatio,
        TextLevel.title => devicePixels / devicePixelRatio,
      };

  double snap(double v) => (v * devicePixelRatio).roundToDouble() / devicePixelRatio;
  Offset snapOffset(Offset o) => Offset(snap(o.dx), snap(o.dy));
  Rect snapRect(Rect r) => Rect.fromLTRB(snap(r.left), snap(r.top), snap(r.right), snap(r.bottom));
}

/// Text sizes, each a whole number of device pixels per font pixel.
enum TextLevel { small, normal, large, title }
