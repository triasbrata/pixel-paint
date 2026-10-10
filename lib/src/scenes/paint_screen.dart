import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../game/paint_tool.dart';
import '../game/puzzle_progress.dart';
import '../game/score_keeper.dart';
import '../ui/pixel_button.dart';
import '../ui/pixel_scale.dart';
import '../ui/pixel_text.dart';
import '../ui/ui_sprites.dart';
import 'dialogs.dart';
import 'mascot.dart';
import 'paint_book_game.dart';
import 'paint_effects.dart';
import 'paint_grid.dart';
import 'paint_hud.dart';
import 'palette_strip.dart';

/// The coloring page: the options button, the combo meter and the score in a
/// row above the picture on its parchment sheet, and the tools and the color
/// guide in a row below. The slime sits on the picture and hops out of the
/// way of the cells still waiting for the selected color. Music, sounds, the leaderboard, Reset and Home are in
/// the pause menu ([PauseDialog]); the combo clock stops while any dialog is
/// open.
class PaintScreen extends Screen {
  PaintScreen(this.progress);

  final PuzzleProgress progress;

  late int selected;
  late int _selectedRemaining;
  late bool _wasComplete;
  var tool = PaintTool.pencil;

  /// Times the combo window (on the fake clock in widget tests).
  final _stopwatch = clock.stopwatch()..start();
  late final ScoreKeeper scorer = ScoreKeeper(progress, now: () => _stopwatch.elapsed);
  ScoreSnapshot? _strokeStart;
  Duration _lastBuzz = -_buzzGap;

  /// Level-ups closer together than this share one vibration.
  static const _buzzGap = Duration(milliseconds: 120);

  late final PaintGrid grid = PaintGrid(
    progress: progress,
    selectedNumber: () => selected,
    onPaint: _onPaint,
    onStrokeStart: () => _strokeStart = scorer.snapshot(),
    onStrokeUndone: () {
      if (_strokeStart case final start?) scorer.restore(start);
    },
  );
  late final PaintEffects effects = PaintEffects();
  late final MiniMap miniMap = MiniMap(progress, grid);
  late final PaletteStrip palette = PaletteStrip(progress, selected: () => selected, onSelect: select);
  late final ScoreLabel scoreLabel = ScoreLabel(scorer);
  late final ComboMeter combo = ComboMeter(scorer);
  late final Slime slime = Slime(greetings: const ['You got this!', 'Pretty!', 'Hi!']);

  late final options = PixelButton(glyph: ButtonGlyph.pause, onTap: openPause);
  late final pencil = PixelButton(art: (game.sprites.tools, UiSprites.pencil), shape: UiShape.square, onTap: () => setTool(PaintTool.pencil));
  late final fill = PixelButton(art: (game.sprites.tools, UiSprites.bucket), shape: UiShape.square, onTap: () => setTool(PaintTool.fill));
  late final find = PixelButton(art: (game.sprites.crosshairs, UiSprites.crosshair), color: UiColor.white, onTap: grid.findCell);
  late final zoomIn = PixelButton(icon: IconRef.plus, color: UiColor.white, onTap: () => grid.zoomStep(1.6));
  late final zoomOut = PixelButton(icon: IconRef.minus, color: UiColor.white, onTap: grid.resetView);

  Rect _page = Rect.zero;
  bool _narrow = false;

  /// Pointers that went down on the grid.
  final _gridPointers = <int>{};

  @override
  Future<void> onLoad() async {
    selected = _nextUnfinished(from: 1) ?? 1;
    _selectedRemaining = progress.remaining(selected);
    _wasComplete = progress.isComplete;
    progress.addListener(_onProgress);
    pencil.toggled = true;
    addAll([grid, effects, miniMap, palette, scoreLabel, combo, options, pencil, fill, find, zoomIn, zoomOut, slime]);
  }

  @override
  void onRemove() {
    progress.removeListener(_onProgress);
    scorer.dispose();
    super.onRemove();
  }

  // --- Layout -----------------------------------------------------------------

  @override
  void layout() {
    final s = game.scale, u = s.unit;
    final w = size.x, h = size.y;
    _narrow = w / u < 200;
    Vector2 sq(double side) => Vector2.all(side * u);

    _layoutTopRow();

    // The page with the picture.
    final paletteH = 26 * u;
    _page = s.snapRect(Rect.fromLTRB(3 * u, 22 * u, w - 3 * u, h - paletteH - u));
    final gridRect = _page.deflate(5 * u);
    grid
      ..position = Vector2(gridRect.left, gridRect.top)
      ..size = Vector2(gridRect.width, gridRect.height)
      ..resized();
    effects
      ..position = grid.position.clone()
      ..size = grid.size.clone();
    miniMap
      ..position = Vector2(s.snap(gridRect.left + 2 * u), s.snap(gridRect.top + 2 * u))
      ..size = miniMap.sizeFor(u);
    var y = gridRect.bottom - 2 * u;
    for (final b in [zoomOut, zoomIn, find]) {
      y -= 16 * u;
      b
        ..position = Vector2(s.snap(gridRect.right - 18 * u), s.snap(y))
        ..size = sq(16);
      y -= 2 * u;
    }

    // The tools (they stay put) and the color guide (it scrolls) in one row.
    final toolsY = h - paletteH + PaletteStrip.swatchMiddle * u - 8 * u;
    pencil
      ..position = Vector2(s.snap(4 * u), s.snap(toolsY))
      ..size = sq(16);
    fill
      ..position = Vector2(s.snap(22 * u), s.snap(toolsY))
      ..size = sq(16);
    palette
      ..position = Vector2(s.snap(40 * u), s.snap(h - paletteH))
      ..size = Vector2(w - s.snap(40 * u), paletteH);

    // The slime lives on the picture, out of the way.
    slime
      ..size = slime.frameSize
      ..place(_clearSpot(near: Offset(gridRect.left, gridRect.bottom)));
  }

  int _scoreDigits = 0;

  /// One row: the options button, the combo meter, the score. The score gets
  /// the room its number needs and the meter the rest, so this runs again
  /// whenever the score gains (or loses) a digit.
  void _layoutTopRow() {
    final s = game.scale, u = s.unit;
    _scoreDigits = '${scorer.score}'.length;
    options
      ..position = Vector2(s.snap(3 * u), s.snap(3 * u))
      ..size = Vector2.all(16 * u);
    scoreLabel.level = _narrow ? TextLevel.normal : TextLevel.large;
    final left = 3 * u + 16 * u + 4 * u;
    double scoreW() => math.max((_narrow ? 30 : 44) * u, scoreLabel.widthFor(scorer.score)).ceilToDouble();
    // The meter keeps at least 48u: past that the score is shortened ("1.2M").
    scoreLabel.compact = false;
    if (size.x - 4 * u - scoreW() - 4 * u - left < 48 * u) scoreLabel.compact = true;
    final width = scoreW();
    scoreLabel
      ..position = Vector2(s.snap(size.x - 4 * u - width), s.snap(3 * u))
      ..size = Vector2(width, 16 * u);
    final right = scoreLabel.x - 4 * u;
    final comboW = math.min(right - left, 110 * u).floorToDouble();
    combo
      ..size = Vector2(comboW, 16 * u)
      ..position = Vector2(s.snap(left + (right - left - comboW) / 2), s.snap(3 * u));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if ('${scorer.score}'.length != _scoreDigits) _layoutTopRow();
    // Paused while a dialog is open: the combo waits.
    final paused = game.hasDialog;
    if (paused && _stopwatch.isRunning) _stopwatch.stop();
    if (!paused && !_stopwatch.isRunning) _stopwatch.start();
    zoomIn.enabled = grid.canZoomIn;
    zoomOut.enabled = grid.canZoomOut;
    pencil.toggled = tool == PaintTool.pencil;
    fill.toggled = tool == PaintTool.fill;
    _keepSlimeClear(dt);
  }

  @override
  void render(Canvas canvas) {
    final s = game.scale, u = s.unit, sp = game.sprites;
    Pix.nine(canvas, sp.frames, UiSprites.parchment, _page, UiSprites.parchmentInsets, u);
  }

  // --- The slime keeps out of the way --------------------------------------------

  double _slimeWait = 0;

  /// Once the player's hands are off the picture, moves the slime (quickly,
  /// with a "Sorry!") when it covers cells still waiting for the selected
  /// color and a clearer spot exists.
  void _keepSlimeClear(double dt) {
    _slimeWait -= dt;
    if (_slimeWait > 0) return;
    _slimeWait = 0.15;
    if (slime.moving || _gridPointers.isNotEmpty || game.hasDialog) return;
    final here = _slimeCost(slime.position.toOffset());
    if (here == 0) return;
    final spot = _clearSpot(near: slime.position.toOffset());
    if (_slimeCost(spot.toOffset()) >= here) return;
    slime.moveTo(spot);
    slime.say('Sorry!', seconds: 1.0);
  }

  /// The slime's position (top-left) inside the picture area that covers the
  /// fewest cells waiting for the selected color, and no controls, nearest to
  /// [near].
  Vector2 _clearSpot({required Offset near}) {
    final s = game.scale;
    final area = grid.toRect(), body = slime.body;
    final minX = area.left - body.left, maxX = area.right - body.right;
    final minY = area.top - body.top, maxY = area.bottom - body.bottom;
    final step = 6 * s.unit;
    var best = Offset(minX, maxY);
    var bestScore = double.infinity;
    for (var y = maxY; y >= minY; y -= step) {
      for (var x = minX; x <= maxX; x += step) {
        final at = Offset(x, y);
        final score = _slimeCost(at) * 1e6 + (at - near).distance;
        if (score < bestScore) {
          bestScore = score;
          best = at;
        }
      }
    }
    return Vector2(s.snap(best.dx), s.snap(best.dy));
  }

  /// What the slime's body would cover with its top-left at [topLeft]: one
  /// for each cell still waiting for the selected color, far more for a
  /// control on the picture (the mini map, the zoom buttons).
  double _slimeCost(Offset topLeft) {
    final u = game.scale.unit;
    final body = slime.body.shift(topLeft);
    var cost = 0.0;
    for (final c in <PositionComponent>[if (miniMap.shown) miniMap, find, zoomIn, zoomOut]) {
      if (c.toRect().inflate(2 * u).overlaps(body)) cost += 1000;
    }
    final puzzle = progress.puzzle, cols = puzzle.width, rows = puzzle.height;
    final cell = grid.cell, origin = grid.gridOrigin + grid.position.toOffset();
    final x0 = math.max(0, ((body.left - origin.dx) / cell).floor());
    final x1 = math.min(cols, ((body.right - origin.dx) / cell).ceil());
    final y0 = math.max(0, ((body.top - origin.dy) / cell).floor());
    final y1 = math.min(rows, ((body.bottom - origin.dy) / cell).ceil());
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = y * cols + x;
        if (puzzle.cells[i] == selected && progress.paintedAt(i) != selected) cost++;
      }
    }
    return cost;
  }

  // --- Input ------------------------------------------------------------------

  @override
  void onRawPointer(PointerEvent event) {
    final point = event.localPosition;
    switch (event) {
      case PointerDownEvent():
        if (grid.owns(point) && !game.controlAt(point)) {
          _gridPointers.add(event.pointer);
          grid.handlePointer(event);
        }
      case PointerScrollEvent() || PointerPanZoomStartEvent() || PointerPanZoomUpdateEvent():
        if (grid.owns(point)) grid.handlePointer(event);
      case PointerUpEvent() || PointerCancelEvent():
        if (_gridPointers.remove(event.pointer)) grid.handlePointer(event);
      default:
        if (_gridPointers.contains(event.pointer)) grid.handlePointer(event);
    }
  }

  void setTool(PaintTool next) {
    tool = next;
    grid.tool = next;
  }

  void select(int number) {
    selected = number;
    _selectedRemaining = progress.remaining(number);
  }

  int? _nextUnfinished({required int from}) {
    final count = progress.puzzle.palette.length;
    for (var k = 0; k < count; k++) {
      final number = (from - 1 + k) % count + 1;
      if (progress.remaining(number) > 0) return number;
    }
    return null;
  }

  void _onProgress() {
    if (progress.isComplete) {
      if (!_wasComplete) {
        _wasComplete = true;
        // After the paint that finished it has been scored.
        scheduleMicrotask(_celebrate);
      }
      return;
    }
    _wasComplete = false;
    // Move on only when the current color has *just* been finished.
    final remaining = progress.remaining(selected);
    if (remaining == 0 && _selectedRemaining > 0) {
      final next = _nextUnfinished(from: selected);
      if (next != null) return select(next);
    }
    _selectedRemaining = remaining;
  }

  // --- Scoring and effects ---------------------------------------------------------

  void _onPaint(PaintEvent e) {
    final event = scorer.paint(e.tool, correctCells: e.cells.length, mistake: e.mistake);
    if (e.mistake) {
      game.sounds.mistake();
      if (event.comboBroken) slime.oops();
      return;
    }
    if (event.points == 0) return;

    final color = event.level > 1 ? comboColor(event.level) : PixelInk.cream;
    final puzzle = progress.puzzle;
    Color cellColor(int i) => puzzle.entry(puzzle.cells[i]).color;
    switch (e.tool) {
      case PaintTool.pencil:
        game.sounds.paint();
        final center = e.cellCenter(e.cells.single);
        effects.popup(center, event.points, color: color, merge: true,
            level: event.level >= 10 ? TextLevel.large : TextLevel.normal);
        effects.burst([center], [cellColor(e.cells.single)], perPoint: 3);
      case PaintTool.fill:
        game.sounds.fill();
        final step = math.max(1, e.cells.length ~/ 40);
        final sample = [for (var k = 0; k < e.cells.length; k += step) e.cells[k]];
        effects
          ..burst([for (final i in sample) e.cellCenter(i)], [for (final i in sample) cellColor(i)],
              perPoint: sample.length < 12 ? 3 : 1)
          ..popup(e.at, event.points, color: color, level: TextLevel.large)
          ..sparkle(e.at, count: 3, spread: 12 * game.scale.unit);
    }

    if (event.leveledUp) {
      final max = event.level == ScoreKeeper.maxLevel;
      if (max || event.level % 5 == 0) {
        // A high combo: the slime cheers it, with a "wow!".
        game.sounds.wow();
        slime.cheer(_comboCheer(event.level));
      } else {
        game.sounds.comboUp();
        slime.hop();
      }
      if (_stopwatch.elapsed - _lastBuzz >= _buzzGap) {
        _lastBuzz = _stopwatch.elapsed;
        max ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
      }
    }
  }

  // --- Dialogs ------------------------------------------------------------------

  Future<void> _celebrate() async {
    final puzzle = progress.puzzle;
    final store = game.data.store;
    final newBest = await store.recordFinish(progress);
    final best = store.bestOf(puzzle);
    final leaderboard = game.data.leaderboard;
    if (leaderboard.has(puzzle)) {
      unawaited(leaderboard.submit(puzzle, progress.score).catchError((Object e) {
        debugPrint('Leaderboard submit failed: $e');
      }));
    }
    if (!isMounted) return;
    game.sounds.finish();
    slime.cheer('Yay!');
    effects.sparkle(Offset(grid.center.x, grid.center.y), count: 10, spread: grid.size.x * 0.6);

    late final CelebrationDialog dialog;
    dialog = CelebrationDialog(
      progress: progress,
      newBest: newBest,
      best: best,
      actions: [
        if (leaderboard.has(puzzle)) (label: 'Ranks', color: UiColor.orange, onTap: showLeaderboard),
        (label: 'Admire', color: UiColor.peach, onTap: () => dialog.close()),
        (label: 'More', color: UiColor.green, onTap: game.showBook),
      ],
    );
    game.add(dialog);
  }

  Future<void> showLeaderboard() async {
    final shown = await game.data.leaderboard.show(progress.puzzle);
    if (!shown && isMounted) slime.say("Can't sign in", seconds: 2.2);
  }

  /// The app went to the background: the combo stops at once and the pause
  /// menu is waiting when the player comes back.
  void pauseForBackground() {
    _stopwatch.stop();
    if (isMounted && !game.hasDialog) openPause();
  }

  static String _comboCheer(int level) => switch (level) {
        >= ScoreKeeper.maxLevel => 'MAX COMBO!',
        >= 15 => 'Super! x$level!',
        >= 10 => 'Amazing! x$level!',
        _ => 'Wow! x$level!',
      };

  /// Opens the pause menu.
  void openPause() {
    late final PauseDialog dialog;
    dialog = PauseDialog(
      progress: progress,
      onRanks: game.data.leaderboard.has(progress.puzzle) ? showLeaderboard : null,
      actions: [
        (label: 'Home', color: UiColor.peach, onTap: game.showBook),
        (
          label: 'Reset',
          color: UiColor.red,
          onTap: () {
            dialog.close();
            _confirmReset();
          },
        ),
        (label: 'Resume', color: UiColor.green, onTap: () => dialog.close()),
      ],
    );
    game.add(dialog);
  }

  void _confirmReset() {
    late final ConfirmDialog dialog;
    dialog = ConfirmDialog(
      title: 'Start over?',
      message: 'This clears every painted cell in this picture.',
      actions: [
        (label: 'Cancel', color: UiColor.peach, onTap: () => dialog.close()),
        (
          label: 'Clear',
          color: UiColor.red,
          onTap: () {
            dialog.close();
            progress.reset();
            scorer.reset();
            select(1);
            grid.resetView();
          },
        ),
      ],
    );
    game.add(dialog);
  }
}
