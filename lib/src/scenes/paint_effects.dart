import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart' show Curves;

import '../game/score_keeper.dart';
import '../ui/pixel_game.dart';
import '../ui/pixel_scale.dart';
import '../ui/pixel_text.dart';
import '../ui/ui_sprites.dart';

/// The color of a combo multiplier, from cool to hot; level 1 is no combo.
Color comboColor(int level) => switch (level) {
      <= 1 => const Color(0xFF8A4836),
      <= 4 => const Color(0xFF2196F3),
      <= 9 => const Color(0xFF00B894),
      <= 14 => const Color(0xFFFF9800),
      <= 19 => const Color(0xFFFF4081),
      _ => const Color(0xFFFFB300),
    };

/// The top multiplier cycles through these.
const rainbow = [
  Color(0xFFFF5D8F),
  Color(0xFFFFB300),
  Color(0xFF6BCB5B),
  Color(0xFF29B6F6),
  Color(0xFFB388FF),
];

/// Score effects over the grid: "+points" popups, pixels thrown up by a
/// Fill, sparkles and score popups. Never takes touches.
class PaintEffects extends PositionComponent with HasGameReference<PixelGame> {
  PaintEffects() : super(priority: 20);

  static const _maxEffects = 400;

  final _effects = <_Effect>[];
  final _random = math.Random();

  /// "+points" rising from [at]. With [merge], points that follow within a
  /// moment add up in one popup that follows the finger, so a drag across a
  /// row reads "+880" rather than a smear of "+10"s.
  void popup(Offset at, int points, {required Color color, TextLevel level = TextLevel.normal, bool merge = false}) {
    if (merge) {
      final last = _effects.whereType<_Popup>().where((p) => p.merge).lastOrNull;
      if (last != null && last.age < 0.25) {
        last
          ..points += points
          ..at = at
          ..color = color
          ..level = level
          ..age = 0;
        return;
      }
    }
    _add(_Popup(at, points, color, level, merge));
  }

  /// Square pixels thrown up from [from], one color each (repeating [colors]).
  void burst(List<Offset> from, List<Color> colors, {int perPoint = 1}) {
    final s = game.scale;
    for (var i = 0; i < from.length; i++) {
      for (var k = 0; k < perPoint; k++) {
        final angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi * 1.2;
        final speed = (30 + _random.nextDouble() * 55) * s.unit;
        _add(_Particle(from[i], Offset(math.cos(angle), math.sin(angle)) * speed, colors[i % colors.length],
            (1 + _random.nextInt(2)) * s.half * 2, gravity: 190 * s.unit));
      }
    }
  }

  /// Twinkling star sparkles (the pack's click animation) around [at].
  void sparkle(Offset at, {int count = 1, double spread = 0}) {
    for (var i = 0; i < count; i++) {
      final d = spread == 0 ? Offset.zero : Offset((_random.nextDouble() - 0.5) * spread, (_random.nextDouble() - 0.5) * spread);
      _add(_Sparkle(at + d, _random.nextDouble() * 0.15));
    }
  }

  void _add(_Effect e) {
    _effects.add(e);
    if (_effects.length > _maxEffects) _effects.removeRange(0, _effects.length - _maxEffects);
  }

  @override
  void update(double dt) {
    for (final e in _effects) {
      e.age += dt;
    }
    _effects.removeWhere((e) => e.age >= e.life);
  }

  @override
  void render(Canvas canvas) {
    final s = game.scale;
    for (final e in _effects) {
      final t = (e.age / e.life).clamp(0.0, 1.0);
      switch (e) {
        case _Particle():
          final pos = e.from + e.velocity * e.age + Offset(0, 0.5 * e.gravity * e.age * e.age) - absolutePosition.toOffset();
          final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
          canvas.drawRect(
            s.snapRect(Rect.fromCenter(center: pos, width: e.size, height: e.size)),
            Paint()..color = e.color.withValues(alpha: fade),
          );
        case _Popup():
          final rise = 14 * s.unit * Curves.easeOutCubic.transform(t);
          final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
          final pop = t < 0.12 ? TextLevel.small : e.level;
          game.text.draw(canvas, '+${formatScore(e.points)}', e.at - absolutePosition.toOffset() - Offset(0, rise),
              level: pop, color: e.color, outline: PixelInk.outline, anchor: TextAnchor.center, opacity: opacity);
        case _Sparkle():
          if (e.age < e.delay) continue;
          final frame = ((e.age - e.delay) / (e.life - e.delay) * 4).floor().clamp(0, 3);
          final side = 16 * s.half * 2;
          Pix.sprite(canvas, game.sprites.click, UiSprites.clickFrame(frame),
              s.snapRect(Rect.fromCenter(center: e.at - absolutePosition.toOffset(), width: side, height: side)));
      }
    }
  }
}

sealed class _Effect {
  double age = 0;
  double get life;
}

class _Popup extends _Effect {
  _Popup(this.at, this.points, this.color, this.level, this.merge);

  Offset at;
  int points;
  Color color;
  TextLevel level;
  final bool merge;

  @override
  double get life => 0.9;
}

class _Particle extends _Effect {
  _Particle(this.from, this.velocity, this.color, this.size, {required this.gravity});

  final Offset from;
  final Offset velocity;
  final Color color;
  final double size;
  final double gravity;

  @override
  double get life => 0.75;
}

class _Sparkle extends _Effect {
  _Sparkle(this.at, this.delay);

  final Offset at;
  final double delay;

  @override
  double get life => 0.45 + delay;
}
