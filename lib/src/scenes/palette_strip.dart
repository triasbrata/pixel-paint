import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../game/puzzle_progress.dart';
import '../ui/pixel_scale.dart';
import '../ui/pixel_text.dart';
import '../ui/ui_sprites.dart';
import 'paint_book_game.dart';

/// The color guide: a row of colored tiles (the UI's beveled slot, tinted),
/// one per palette number, with how many cells each still needs. Drag to
/// scroll, tap to pick.
class PaletteStrip extends PositionComponent with TapCallbacks, DragCallbacks, HasGameReference<PaintBookGame> {
  PaletteStrip(this.progress, {required this.selected, required this.onSelect});

  final PuzzleProgress progress;
  final int Function() selected;
  final void Function(int number) onSelect;

  double _scroll = 0;
  double _target = 0;
  int _revealed = -1;

  /// How far down the strip the swatches' centers are, in units.
  static const swatchMiddle = 15.0;

  double get _swatch => 16 * game.scale.unit;
  double get _pitch => 20 * game.scale.unit;
  double get _start => 4 * game.scale.unit;
  double get _maxScroll =>
      math.max(0, _start * 2 + progress.puzzle.palette.length * _pitch - 4 * game.scale.unit - size.x);

  /// Center of swatch [number] in the strip's coordinates.
  Offset swatchCenter(int number) =>
      Offset(_start + (number - 1) * _pitch + _swatch / 2 - _scroll, swatchMiddle * game.scale.unit);

  /// Scrolls so [number] is in view (eased).
  void reveal(int number) {
    final center = _start + (number - 1) * _pitch + _swatch / 2;
    _target = (center - size.x / 2).clamp(0.0, _maxScroll);
  }

  @override
  void update(double dt) {
    final number = selected();
    if (number != _revealed) {
      _revealed = number;
      reveal(number);
    }
    _scroll += (_target - _scroll) * math.min(1.0, dt * 12);
    if ((_target - _scroll).abs() < 0.5) _scroll = _target;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _scroll = (_scroll - event.localDelta.x).clamp(0.0, _maxScroll);
    _target = _scroll;
  }

  @override
  void onTapUp(TapUpEvent event) {
    final x = event.localPosition.x + _scroll - _start;
    final i = (x / _pitch).floor();
    if (i < 0 || i >= progress.puzzle.palette.length || x - i * _pitch > _swatch + game.scale.unit) return;
    game.sounds.click();
    onSelect(i + 1);
  }

  @override
  void render(Canvas canvas) {
    final s = game.scale, u = s.unit, sp = game.sprites;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, -6 * u, size.x, size.y + 6 * u));
    final picked = selected();
    for (final entry in progress.puzzle.palette) {
      final n = entry.number;
      final center = swatchCenter(n);
      if (center.dx < -_swatch || center.dx > size.x + _swatch) continue;
      final isPicked = n == picked;
      final remaining = progress.remaining(n);
      final rect = s.snapRect(Rect.fromCenter(center: center - Offset(0, isPicked ? 3 * u : 0), width: _swatch, height: _swatch));

      // The white tile, tinted with the color: the border stays dark.
      final tint = Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(entry.color, BlendMode.modulate);
      Pix.nine(canvas, sp.frames, UiSprites.tile(1, isPicked ? Look.hover : Look.normal), rect, UiSprites.tileInsets, s.half,
          using: tint);
      if (isPicked) {
        Pix.nine(canvas, sp.selectors, UiSprites.selector, s.snapRect(rect.inflate(3 * u)), UiSprites.selectorInsets, s.half);
      }
      final face = Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - UiSprites.tileBevel * s.half);

      final light = entry.color.computeLuminance() < 0.35;
      if (remaining == 0) {
        Pix.sprite(canvas, sp.icons, IconRef.check.rect,
            s.snapRect(Rect.fromCenter(center: face.center, width: 16 * s.half, height: 16 * s.half)));
      } else {
        game.text.draw(canvas, '$n', face.center, level: TextLevel.large,
            color: light ? PixelInk.cream : PixelInk.outline, outline: light ? PixelInk.outline : const Color(0xCCFFFFFF),
            anchor: TextAnchor.center);
        // How many cells are left, on a little tag.
        final tag = game.text.measure('$remaining', TextLevel.small);
        final tagRect = s.snapRect(Rect.fromLTWH(rect.right - tag.width - u, rect.top - 3 * u, tag.width + 2 * u, tag.height + u));
        Pix.nine(canvas, sp.bars, UiSprites.barTrack, tagRect, UiSprites.barInsets, s.half);
        game.text.draw(canvas, '$remaining', tagRect.center, level: TextLevel.small, color: PixelInk.cream, outline: null,
            anchor: TextAnchor.center);
      }
    }
    canvas.restore();
  }
}
