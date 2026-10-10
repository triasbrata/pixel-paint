import 'dart:math' as math;
import 'dart:ui';

/// Puzzle difficulty, derived from how many colors and cells a picture has.
enum Difficulty {
  easy('Easy', 'Up to 5 colors. Great for kids!', Color(0xFF43A047)),
  medium('Medium', '6 to 9 colors.', Color(0xFF1E88E5)),
  hard('Hard', '10 to 14 colors, with light and dark shades.', Color(0xFFFB8C00)),
  expert('Expert', '15+ colors, with lots of similar shades.', Color(0xFFE53935));

  const Difficulty(this.label, this.description, this.color);

  final String label;
  final String description;
  final Color color;

  /// The harder of the color-count tier and the picture-size tier, so a big
  /// picture with few colors still isn't labelled "easy".
  static Difficulty classify({required int colorCount, required int cellCount}) {
    final byColors = switch (colorCount) {
      <= 5 => easy,
      <= 9 => medium,
      <= 14 => hard,
      _ => expert,
    };
    final bySize = switch (cellCount) {
      <= 32 * 32 => easy,
      <= 48 * 48 => medium,
      <= 64 * 64 => hard,
      _ => expert,
    };
    return values[math.max(byColors.index, bySize.index)];
  }
}
