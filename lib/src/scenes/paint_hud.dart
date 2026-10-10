import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../game/puzzle_progress.dart';
import '../game/score_keeper.dart';
import '../ui/pixel_game.dart';
import '../ui/pixel_scale.dart';
import '../ui/pixel_text.dart';
import '../ui/ui_sprites.dart';
import 'paint_book_game.dart';
import 'paint_effects.dart';
import 'paint_grid.dart';

/// The star and the score, counting up to the real one, right-aligned.
class ScoreLabel extends PositionComponent with HasGameReference<PixelGame> {
  ScoreLabel(this.scorer);

  final ScoreKeeper scorer;
  double _shown = 0;
  double _bump = 0;

  /// The number's size: large, or normal where the row is tight (a phone).
  TextLevel level = TextLevel.large;

  /// Shortened ("1.2M") where the full number would crowd the combo meter.
  bool compact = false;

  String _text(int score) => compact ? formatScoreShort(score) : formatScore(score);

  /// Width the label needs for a score as long as [score] (its digits drawn
  /// as the widest one, so the room only changes with the digit count).
  double widthFor(int score) {
    final s = game.scale;
    final widest = _text(score).replaceAll(RegExp('[0-9]'), '8');
    return game.text.measure(widest, level).width + s.unit + 16 * s.half;
  }

  @override
  void onMount() {
    super.onMount();
    _shown = scorer.score.toDouble();
  }

  @override
  void update(double dt) {
    final target = scorer.score.toDouble();
    if (_shown != target) {
      if (target > _shown) _bump = 1;
      final step = math.max(1.0, (target - _shown).abs() * math.min(1.0, dt * 9));
      _shown = (target - _shown).abs() <= step ? target : _shown + step * (target - _shown).sign;
    }
    _bump = math.max(0, _bump - dt * 5);
  }

  @override
  void render(Canvas canvas) {
    // Right-aligned: the star sits just left of the number as it grows.
    final s = game.scale;
    final star = 16 * s.half;
    final lift = _bump * s.unit;
    final text = game.text.draw(canvas, _text(_shown.round()), Offset(size.x, size.y / 2),
        level: level, anchor: TextAnchor.centerRight);
    Pix.sprite(canvas, game.sprites.icons, IconRef.star.rect,
        s.snapRect(Rect.fromLTWH(text.left - s.unit - star, (size.y - star) / 2 - lift, star, star)));
  }
}

/// The combo meter: the multiplier, a bar that drains
/// while the player pauses, and dots for the steps to the next level. It
/// bounces on a level up, dips when the bar runs out and the multiplier drops
/// a level, shakes red when a wrong color breaks the combo, and cycles colors
/// at the top level.
class ComboMeter extends PositionComponent with HasGameReference<PixelGame> {
  ComboMeter(this.scorer);

  final ScoreKeeper scorer;
  ScoreEvent? _seen;
  double _bump = 0;
  double _shake = 0;
  double _drop = 0;
  int _level = 1;

  @override
  void update(double dt) {
    final event = scorer.lastEvent;
    if (event != null && !identical(event, _seen)) {
      _seen = event;
      if (event.leveledUp) _bump = 1;
      if (event.comboBroken) _shake = 1;
    }
    final level = scorer.level;
    if (level < _level && _shake == 0 && level > 1) _drop = 1;
    _level = level;
    _bump = math.max(0, _bump - dt * 3.5);
    _drop = math.max(0, _drop - dt * 3);
    _shake = math.max(0, _shake - dt * 2.4);
  }

  @override
  void render(Canvas canvas) {
    final s = game.scale, u = s.unit, sp = game.sprites;
    final level = scorer.level;
    final max = level >= ScoreKeeper.maxLevel;
    final broken = _shake > 0;
    final color = broken
        ? const Color(0xFFE5484D)
        : max
            ? rainbow[(game.time * 8).floor() % rainbow.length]
            : comboColor(level);

    final dx = broken ? math.sin(_shake * math.pi * 6) * 3 * u * _shake : 0.0;
    final grow = 1 + 0.25 * math.sin(math.pi * _bump) - 0.15 * math.sin(math.pi * _drop);
    final dip = 2 * u * math.sin(math.pi * _drop);
    canvas.save();
    canvas.translate(s.snap(dx), 0);

    // The multiplier, in its tier's color.
    final badge = Rect.fromLTWH(0, (size.y - 18 * u) / 2, 24 * u, 18 * u);
    canvas.save();
    canvas.translate(badge.center.dx, badge.center.dy + s.snap(dip));
    canvas.scale(grow);
    canvas.translate(-badge.center.dx, -badge.center.dy);
    game.text.draw(canvas, 'x$level', badge.center, level: TextLevel.large, color: level <= 1 && !broken ? PixelInk.cream : color,
        anchor: TextAnchor.center);
    canvas.restore();

    // Time left before the combo drops.
    final track = s.snapRect(Rect.fromLTWH(badge.right + 2 * u, size.y / 2 - 5 * u, size.x - badge.right - 2 * u, 6 * u));
    Pix.nine(canvas, sp.bars, UiSprites.barTrack, track, UiSprites.barInsets, u);
    final inner = Rect.fromLTRB(track.left + 2 * u, track.top + u, track.right - 2 * u, track.bottom - u);
    final left = scorer.timeLeft;
    if (left > 0 && inner.width > 0) {
      final fill = s.snapRect(Rect.fromLTWH(inner.left, inner.top, inner.width * left, inner.height));
      canvas.drawRect(fill, Paint()..color = color);
      canvas.drawRect(s.snapRect(Rect.fromLTWH(fill.left, fill.top, fill.width, s.half)),
          Paint()..color = const Color(0x66FFFFFF));
    }

    // Steps toward the next multiplier, or MAX.
    final dotsTop = track.bottom + u;
    if (max) {
      game.text.draw(canvas, 'MAX', Offset(track.center.dx, dotsTop + u), level: TextLevel.small, color: color,
          anchor: TextAnchor.topCenter);
    } else {
      final n = ScoreKeeper.stepsPerLevel;
      final w = (track.width - (n - 1) * u) / n;
      for (var i = 0; i < n && w > 0; i++) {
        canvas.drawRect(
          s.snapRect(Rect.fromLTWH(track.left + i * (w + u), dotsTop, w, 2 * u)),
          Paint()..color = i < scorer.steps ? color : const Color(0x553F2832),
        );
      }
    }
    canvas.restore();
  }
}

/// The whole picture in small, with a frame around the part on screen.
/// Tap or drag on it to move the view there.
class MiniMap extends PositionComponent with TapCallbacks, DragCallbacks, HasGameReference<PaintBookGame> {
  MiniMap(this.progress, this.grid);

  final PuzzleProgress progress;
  final PaintGrid grid;

  static const maxArt = Size(48, 34); // art pixels

  bool get shown => grid.zoomedIn;

  @override
  bool containsLocalPoint(Vector2 point) => shown && super.containsLocalPoint(point);

  /// Size for the current picture, in logical pixels.
  Vector2 sizeFor(double unit) {
    final p = progress.puzzle;
    final k = math.min(maxArt.width / p.width, maxArt.height / p.height);
    return Vector2(p.width * k * unit + 8 * unit, p.height * k * unit + 8 * unit);
  }

  Rect get _picture => Rect.fromLTRB(4 * game.scale.unit, 4 * game.scale.unit, size.x - 4 * game.scale.unit,
      size.y - 4 * game.scale.unit);

  void _jump(Vector2 local) {
    final r = _picture;
    final p = progress.puzzle;
    grid.centerOn(Offset((local.x - r.left) / r.width * p.width, (local.y - r.top) / r.height * p.height));
  }

  @override
  void onTapDown(TapDownEvent event) => _jump(event.localPosition);

  @override
  void onDragUpdate(DragUpdateEvent event) => _jump(event.localEndPosition);

  @override
  void render(Canvas canvas) {
    if (!shown) return;
    final s = game.scale, u = s.unit;
    Pix.nine(canvas, game.sprites.frames, UiSprites.parchment, size.toRect(), UiSprites.parchmentInsets, s.half);
    final r = _picture;
    canvas.drawImageRect(game.thumbnails.of(progress), Rect.fromLTWH(0, 0, progress.puzzle.width.toDouble(),
        progress.puzzle.height.toDouble()), r, Pix.paint);
    final v = grid.visibleCells;
    final p = progress.puzzle;
    final kx = r.width / p.width, ky = r.height / p.height;
    final frame = s.snapRect(Rect.fromLTRB(r.left + v.left * kx, r.top + v.top * ky, r.left + v.right * kx, r.top + v.bottom * ky));
    // Dim what's off screen, frame what's on it.
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(r)
      ..addRect(frame);
    canvas.drawPath(dim, Paint()..color = const Color(0x553F2832));
    final line = Paint()..color = const Color(0xFFFF5D8F);
    final t = u / 2;
    canvas
      ..drawRect(Rect.fromLTWH(frame.left, frame.top, frame.width, t), line)
      ..drawRect(Rect.fromLTWH(frame.left, frame.bottom - t, frame.width, t), line)
      ..drawRect(Rect.fromLTWH(frame.left, frame.top, t, frame.height), line)
      ..drawRect(Rect.fromLTWH(frame.right - t, frame.top, t, frame.height), line);
  }
}
