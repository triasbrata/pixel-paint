import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../game/puzzle_progress.dart';
import '../game/score_keeper.dart';
import '../ui/pixel_button.dart';
import '../ui/pixel_scale.dart';
import '../ui/pixel_text.dart';
import '../ui/ui_sprites.dart';
import 'paint_book_game.dart';

/// A button at the bottom of a dialog.
typedef DialogAction = ({String label, UiColor color, void Function() onTap});

/// A parchment panel with a ribbon title, some content and a row of buttons.
abstract class PanelDialog extends DialogLayer {
  PanelDialog(this.title, this.actions);

  final String title;
  final List<DialogAction> actions;
  final _buttons = <PixelButton>[];
  Rect panel = Rect.zero;

  /// Height of the content, in logical pixels, for a panel [width] wide.
  double contentHeight(double width);

  /// Draws the content into [area].
  void renderContent(Canvas canvas, Rect area);

  @override
  Future<void> onLoad() async {
    for (final a in actions) {
      _buttons.add(PixelButton(label: a.label, color: a.color, onTap: a.onTap));
    }
    addAll(_buttons);
  }

  @override
  void layout() {
    final s = game.scale, u = s.unit;
    final width = math.min(size.x - 12 * u, 150 * u);
    final content = contentHeight(width - 24 * u);
    final height = 18 * u + content + 30 * u;
    panel = s.snapRect(Rect.fromCenter(center: Offset(size.x / 2, size.y / 2), width: width, height: height));

    // Buttons share the bottom row.
    final gap = 3 * u;
    final bw = math.min(46 * u, (width - 16 * u - gap * (_buttons.length - 1)) / math.max(1, _buttons.length));
    var x = panel.center.dx - (bw * _buttons.length + gap * (_buttons.length - 1)) / 2;
    for (final b in _buttons) {
      b
        ..position = Vector2(s.snap(x), s.snap(panel.bottom - 24 * u))
        ..size = Vector2(s.snap(bw), 16 * u);
      x += bw + gap;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas); // the dim layer
    final s = game.scale, u = s.unit, sp = game.sprites;
    Pix.nine(canvas, sp.frames, UiSprites.parchment, panel, UiSprites.parchmentInsets, u);
    final level = TextLevel.large;
    final ribbonW = game.text.measure(title, level).width + 36 * u;
    final ribbon = s.snapRect(Rect.fromCenter(center: Offset(panel.center.dx, panel.top), width: ribbonW, height: 20 * u));
    Pix.nine(canvas, sp.ribbons, UiSprites.ribbon, ribbon, UiSprites.ribbonInsets, u);
    game.text.draw(canvas, title, ribbon.center - Offset(0, 2 * u), level: level, anchor: TextAnchor.center);
    renderContent(canvas, Rect.fromLTRB(panel.left + 12 * u, panel.top + 16 * u, panel.right - 12 * u, panel.bottom - 28 * u));
  }
}

/// "You did it!": the finished picture, its score and the best one.
class CelebrationDialog extends PanelDialog {
  CelebrationDialog({
    required this.progress,
    required this.newBest,
    required this.best,
    required List<DialogAction> actions,
  }) : super('You did it!', actions);

  final PuzzleProgress progress;
  final bool newBest;
  final int? best;

  @override
  double contentHeight(double width) => game.scale.unit * (56 + 30);

  @override
  void renderContent(Canvas canvas, Rect area) {
    final s = game.scale, u = s.unit, sp = game.sprites;
    final slot = s.snapRect(Rect.fromCenter(center: Offset(area.center.dx, area.top + 28 * u), width: 54 * u, height: 54 * u));
    Pix.nine(canvas, sp.frames, UiSprites.container, slot, UiSprites.containerInsets, u);
    game.thumbnails.draw(canvas, progress, slot.deflate(4 * u), s);

    var y = slot.bottom + 4 * u;
    game.text.draw(canvas, '${progress.puzzle.name} is fully colored.', Offset(area.center.dx, y),
        level: TextLevel.normal, color: PixelInk.darkBrown, outline: null, anchor: TextAnchor.topCenter);
    y += 9 * u;
    final score = game.text.draw(canvas, formatScore(progress.score), Offset(area.center.dx + 5 * u, y + 5 * u),
        level: TextLevel.title, anchor: TextAnchor.center);
    Pix.sprite(canvas, sp.icons, IconRef.star.rect, s.snapRect(Rect.fromLTWH(score.left - 18 * s.half, score.center.dy - 8 * s.half, 16 * s.half, 16 * s.half)));
    y += 13 * u;
    if (newBest) {
      game.text.draw(canvas, 'New best!', Offset(area.center.dx, y), level: TextLevel.normal, color: PixelInk.gold,
          anchor: TextAnchor.topCenter);
    } else if (best case final b? when b > 0) {
      game.text.draw(canvas, 'Best: ${formatScore(b)}', Offset(area.center.dx, y), level: TextLevel.normal,
          color: PixelInk.brown, outline: null, anchor: TextAnchor.topCenter);
    }
  }
}

/// A question with a few lines of explanation.
class ConfirmDialog extends PanelDialog {
  ConfirmDialog({required String title, required this.message, required List<DialogAction> actions})
      : super(title, actions);

  final String message;

  List<String> _lines(double width) => game.text.wrap(message, TextLevel.normal, width);

  @override
  double contentHeight(double width) => (_lines(width).length * 9 + 4) * game.scale.unit;

  @override
  void renderContent(Canvas canvas, Rect area) {
    final u = game.scale.unit;
    var y = area.top + 2 * u;
    for (final line in _lines(area.width)) {
      game.text.draw(canvas, line, Offset(area.center.dx, y), color: PixelInk.darkBrown, outline: null,
          anchor: TextAnchor.topCenter);
      y += 9 * u;
    }
  }
}

/// The pause menu: how far the picture is, the music and sound switches, the
/// leaderboard, then Home, Reset and Resume. A tap outside the panel resumes.
/// The coloring page's combo clock stands still while it is open.
class PauseDialog extends PanelDialog {
  PauseDialog({required this.progress, required this.onRanks, required List<DialogAction> actions})
      : super('Paused', actions);

  final PuzzleProgress progress;

  /// Opens the picture's leaderboard; null when it has none.
  final void Function()? onRanks;

  late final music = PixelButton(icon: IconRef.note, onTap: _toggleMusic);
  late final sounds = PixelButton(icon: IconRef.speaker, onTap: _toggleSounds);
  late final trophy = PixelButton(icon: IconRef.trophy, color: UiColor.orange, onTap: () => onRanks?.call());

  List<PixelButton> get _switches => [
        if (game.data.music != null) music,
        if (game.data.sounds != null) sounds,
        if (onRanks != null) trophy,
      ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _showSwitches();
    addAll(_switches);
  }

  void _toggleMusic() {
    game.data.music?.toggle();
    _showSwitches();
  }

  void _toggleSounds() {
    game.data.sounds?.toggle();
    _showSwitches();
  }

  void _showSwitches() {
    music.icon = (game.data.music?.enabled ?? true) ? IconRef.note : IconRef.noteOff;
    sounds.icon = (game.data.sounds?.enabled ?? true) ? IconRef.speaker : IconRef.speakerOff;
  }

  @override
  double contentHeight(double width) => 33 * game.scale.unit;

  @override
  void layout() {
    super.layout();
    final s = game.scale, u = s.unit;
    final row = _switches;
    final gap = 4 * u;
    var x = panel.center.dx - (row.length * 16 * u + (row.length - 1) * gap) / 2;
    for (final b in row) {
      b
        ..position = Vector2(s.snap(x), s.snap(panel.top + 29 * u))
        ..size = Vector2.all(16 * u);
      x += 16 * u + gap;
    }
  }

  @override
  void renderContent(Canvas canvas, Rect area) {
    game.text.draw(canvas, '${progress.puzzle.name}  ${(progress.fraction * 100).floor()}%',
        Offset(area.center.dx, area.top + 2 * game.scale.unit),
        color: PixelInk.darkBrown, outline: null, anchor: TextAnchor.topCenter);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!panel.contains(event.localPosition.toOffset())) close();
  }
}
