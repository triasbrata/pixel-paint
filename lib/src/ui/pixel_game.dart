import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../audio/sound_effects.dart';
import 'pixel_scale.dart';
import 'pixel_text.dart';
import 'ui_sprites.dart';

/// A Flame game drawn in pixel art: the sheets, the pixel scale for the
/// current screen, the pixel font and the sounds, for every component.
abstract class PixelGame extends FlameGame {
  PixelGame({required this.sprites, this.sounds = const SilentSounds()});

  final UiSprites sprites;
  final Sounds sounds;

  PixelScale scale = const PixelScale(8, 2.625);
  late PixelText text = PixelText(scale);

  /// Seconds since the game started, for idle animations.
  double time = 0;

  @override
  Color backgroundColor() => const Color(0xFFCFEFFF);

  @override
  void onGameResize(Vector2 size) {
    final context = buildContext;
    final dpr = context != null && context.mounted
        ? MediaQuery.devicePixelRatioOf(context)
        : PlatformDispatcher.instance.views.first.devicePixelRatio;
    final next = PixelScale.forScreen(Size(size.x, size.y), dpr);
    if (next.devicePixels != scale.devicePixels || next.devicePixelRatio != scale.devicePixelRatio) {
      scale = next;
      text = PixelText(scale);
    }
    super.onGameResize(size);
  }

  @override
  void update(double dt) {
    time += dt;
    super.update(dt);
  }
}
