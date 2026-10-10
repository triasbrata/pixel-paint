import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/gestures.dart';

import '../audio/sound_effects.dart';
import '../game_data.dart';
import '../models/difficulty.dart';
import '../models/puzzle.dart';
import '../ui/pixel_game.dart';
import 'book_screen.dart';
import 'paint_screen.dart';
import 'sky.dart';
import 'thumbnails.dart';

/// Pixel Paint as one Flame game: the sky, then either the book of pictures
/// or the coloring page, with dialogs on top.
class PaintBookGame extends PixelGame {
  PaintBookGame(this.data)
      : super(sprites: data.sprites, sounds: data.sounds ?? const SilentSounds());

  final GameData data;
  final thumbnails = Thumbnails();

  Screen? _screen;
  Screen? get screen => _screen;

  /// Where the book was left open.
  Difficulty bookTab = Difficulty.easy;
  int bookSpread = 0;

  @override
  Future<void> onLoad() async {
    add(SkyBackdrop());
    showBook();
  }

  void showBook() {
    unawaited(data.store.flush());
    _show(BookScreen());
  }

  void openPuzzle(Puzzle puzzle) => _show(PaintScreen(data.store.of(puzzle)));

  void _show(Screen next) {
    _screen?.removeFromParent();
    for (final dialog in _dialogs.toList()) {
      dialog.close();
    }
    _screen = next;
    add(next);
  }

  /// Dialogs from the moment they're added until they close: one added while
  /// the engine is paused (in the background) counts before it mounts.
  final _dialogs = <DialogLayer>[];

  @override
  FutureOr<void> add(Component component) {
    if (component is DialogLayer) _dialogs.add(component);
    return super.add(component);
  }

  bool get hasDialog {
    _dialogs.removeWhere((d) => d.closed);
    return _dialogs.isNotEmpty;
  }

  /// Leaving the app pauses the coloring page: the engine stops updating, so
  /// its combo clock is stopped here, and the pause menu waits on return.
  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    if (state case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached) {
      if (_screen case final PaintScreen paint) paint.pauseForBackground();
    }
  }

  /// The system back button: closes a dialog, or leaves the coloring page.
  /// Returns false on the book, where back leaves the app.
  bool back() {
    if (hasDialog) {
      _dialogs.last.close();
      return true;
    }
    if (_screen is PaintScreen) {
      showBook();
      return true;
    }
    return false;
  }

  /// Raw pointer events from the widget (painting needs every finger).
  void onRawPointer(PointerEvent event) {
    if (hasDialog) return;
    _screen?.onRawPointer(event);
  }

  /// Whether a button or other control is at [point], so painting leaves it.
  bool controlAt(Offset point) =>
      componentsAtPoint(Vector2(point.dx, point.dy)).any((c) => c is TapCallbacks || c is DragCallbacks);
}

/// One full screen of the game; lays itself out for the game's size.
abstract class Screen extends PositionComponent with HasGameReference<PaintBookGame> {
  void onRawPointer(PointerEvent event) {}

  /// Places children for [size] (logical pixels) at the current pixel scale.
  void layout();

  @override
  void onMount() {
    super.onMount();
    size = game.size;
    layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    if (isMounted) layout();
  }
}

/// A modal layer: dims what's below and takes every tap.
abstract class DialogLayer extends PositionComponent with TapCallbacks, HasGameReference<PaintBookGame> {
  DialogLayer() : super(priority: 100);

  bool _closed = false;

  /// Closed (or closing): it no longer counts as open.
  bool get closed => _closed;

  void close() {
    _closed = true;
    removeFromParent();
  }

  void layout();

  @override
  void onMount() {
    super.onMount();
    size = game.size;
    layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    if (isMounted) layout();
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0x8A3F2832));
  }
}
