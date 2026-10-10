import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import 'pixel_game.dart';
import 'pixel_scale.dart';
import 'pixel_text.dart';
import 'ui_sprites.dart';

/// A button from the Kenmi sheet: a stretchable label button, or a 16-px
/// round/square one with a glyph, an icon from the icon sheet, or any sprite.
///
/// Hovering lifts it to the half-pressed look, pressing sinks it; [toggled]
/// keeps it pressed (for tools and switches).
class PixelButton extends PositionComponent with TapCallbacks, HoverCallbacks, HasGameReference<PixelGame> {
  PixelButton({
    required this.onTap,
    this.label,
    this.glyph,
    this.icon,
    this.art,
    this.color = UiColor.peach,
    this.shape = UiShape.round,
    this.toggled = false,
    this.enabled = true,
    this.visible = true,
    this.textLevel = TextLevel.normal,
    super.position,
    super.size,
    super.priority,
  });

  void Function() onTap;
  String? label;
  ButtonGlyph? glyph;
  IconRef? icon;

  /// Any other sprite drawn on a blank button: (sheet, rect).
  (ui.Image, Rect)? art;

  UiColor color;
  UiShape shape;
  bool toggled;
  bool enabled;

  /// Hidden buttons are neither drawn nor tappable.
  bool visible;
  TextLevel textLevel;

  bool _down = false;

  Look get look => !enabled
      ? Look.normal
      : _down || toggled
          ? Look.pressed
          : isHovered
              ? Look.hover
              : Look.normal;

  @override
  bool containsLocalPoint(Vector2 point) => visible && super.containsLocalPoint(point);

  @override
  void onTapDown(TapDownEvent event) {
    if (enabled) _down = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    final wasDown = _down;
    _down = false;
    if (enabled && wasDown) {
      game.sounds.click();
      onTap();
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) => _down = false;

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final sprites = game.sprites;
    final scale = game.scale;
    final rect = size.toRect();
    final tint = enabled ? color : UiColor.grey;
    final sink = look.index * scale.unit;

    if (label case final text?) {
      Pix.nine(canvas, sprites.buttons, UiSprites.wideButton(tint, shape, look), rect, UiSprites.wideInsets, scale.unit);
      final dark = const {UiColor.green, UiColor.blue, UiColor.red, UiColor.purple}.contains(tint);
      game.text.draw(
        canvas,
        text,
        rect.center + Offset(0, sink / 2 - scale.unit / 2),
        level: textLevel,
        color: dark ? PixelInk.cream : PixelInk.button,
        outline: dark ? PixelInk.outline : null,
        anchor: TextAnchor.center,
      );
      return;
    }

    // Icon buttons: the icon inside a beveled tile from the frames sheet,
    // drawn at the icons' pixel size, so the icon sits in the UI's own
    // border instead of being stuck onto a button.
    final px = scale.half;
    final row = toggled ? UiSprites.tileRow(UiColor.green) : UiSprites.tileRow(tint);
    final sunk = look == Look.pressed;
    final tileRect = sunk ? Rect.fromLTRB(rect.left, rect.top + UiSprites.tileBevel * px, rect.right, rect.bottom) : rect;
    Pix.nine(canvas, sprites.frames, UiSprites.tile(row, look), scale.snapRect(tileRect),
        sunk ? UiSprites.tileSunkInsets : UiSprites.tileInsets, px);
    final face = sunk ? tileRect : Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - UiSprites.tileBevel * px);
    final iconPaint = enabled ? null : (Paint()..color = const Color(0x66000000));
    Rect at(double size) => scale.snapRect(Rect.fromCenter(center: face.center, width: size, height: size));
    if (glyph case final g?) {
      // The glyph sheet's icons are small in their cells: one size up.
      Pix.sprite(canvas, sprites.buttonIcons, UiSprites.glyphIcon(g), at(16 * scale.unit), using: iconPaint);
    } else if (icon case final i?) {
      Pix.sprite(canvas, sprites.icons, i.rect, at(16 * px), using: iconPaint);
    } else if (art case (final image, final src)) {
      Pix.sprite(canvas, image, src, at(16 * px), using: iconPaint);
    }
  }
}
