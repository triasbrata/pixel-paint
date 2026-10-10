// Renders the store screenshots from the real app, mid-game:
//
//     flutter test tool/store_screenshots_test.dart
//
// Writes build/store/raw/<device>/<shot>.png. tool/make_store_art.py then adds
// the captions and sizes them for Google Play and itch.io
// (tool/update_store_art.sh runs both).
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:color_by_number/src/app.dart';
import 'package:color_by_number/src/audio/background_music.dart';
import 'package:color_by_number/src/audio/sound_effects.dart';
import 'package:color_by_number/src/data/puzzle_loader.dart';
import 'package:color_by_number/src/game/leaderboard.dart';
import 'package:color_by_number/src/game/paint_tool.dart';
import 'package:color_by_number/src/game/progress_store.dart';
import 'package:color_by_number/src/game/puzzle_progress.dart';
import 'package:color_by_number/src/models/difficulty.dart';
import 'package:color_by_number/src/models/puzzle.dart';
import 'package:color_by_number/src/scenes/book_screen.dart';
import 'package:color_by_number/src/scenes/paint_book_game.dart';
import 'package:color_by_number/src/scenes/paint_screen.dart';
import 'package:color_by_number/src/ui/ui_sprites.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class Device {
  const Device(this.name, this.size, this.pixelRatio);

  final String name;
  final Size size; // logical pixels
  final double pixelRatio;
}

const phone = Device('phone', Size(411, 731), 3); // 9:16 portrait
const tablet = Device('tablet', Size(1280, 800), 2); // 16:10 landscape

/// What a shot shows on each device. Shots that catch an effect mid-flight
/// don't wait for the animations to settle.
class Shot {
  const Shot(this.name, this.run, {this.settle = true, this.leaderboard = false});

  final String name;
  final Future<void> Function(WidgetTester tester, Device device, Studio studio) run;
  final bool settle;

  /// Show the Leaderboard button, as on Android with Play Games set up.
  final bool leaderboard;
}

final shots = [
  Shot('1_paint', (tester, device, studio) async {
    // The core idea: numbered gray cells turning into a picture, with the
    // points popping up from the last few taps.
    final id = device == phone ? 'mushroom' : 'sleepy_cat';
    final screen = await studio.open(tester, studio.play(id, done: 0.5));
    for (final i in studio.waiting(screen).take(6)) {
      await tester.tapAt(studio.at(screen, i));
      await tester.pump(const Duration(milliseconds: 70));
    }
    await tester.pump(const Duration(milliseconds: 160));
  }, settle: false),
  Shot('2_combo', (tester, device, studio) async {
    // Quick sweeps along rows of the selected color: the combo climbs.
    final puzzle = studio.puzzle('moon_witch');
    final screen = await studio.open(tester, studio.play(puzzle.id, done: 0.3, biggestFirst: true));
    final row = studio.longestRun(screen, onScreen: false);
    final middle = row[row.length ~/ 2];
    await studio.zoomTo(tester, screen,
        cell: device == phone ? 13 : 16,
        center: Offset(middle % puzzle.width + 0.5, middle ~/ puzzle.width + 0.5));
    for (var sweep = 0; sweep < 3; sweep++) {
      final run = studio.longestRun(screen);
      if (run.length < 4) break;
      final from = studio.at(screen, run.first);
      await tester.dragFrom(from, studio.at(screen, run.last) - from);
      await tester.pump(const Duration(milliseconds: 90));
    }
    await tester.pump(const Duration(milliseconds: 220));
  }, settle: false),
  Shot('3_zoom', (tester, device, studio) async {
    // Close up on the mermaid, half painted, with the mini map in the corner.
    final puzzle = studio.puzzle('mermaid_reef');
    final screen = await studio.open(tester, studio.reveal(puzzle.id, through: const Offset(0.54, 0.38)));
    await studio.zoomTo(tester, screen,
        cell: 18, center: Offset(puzzle.width * (device == phone ? 0.51 : 0.48), puzzle.height * 0.4));
  }),
  Shot('4_fill', (tester, device, studio) async {
    // A Fill lands: the whole area at once, pixels flying.
    final puzzle = studio.puzzle('shiba_meadow');
    final screen = await studio.open(tester, studio.play(puzzle.id, done: 0.45, biggestFirst: true));
    screen.setTool(PaintTool.fill);
    await studio.zoomTo(tester, screen,
        cell: device == phone ? 18 : 17, center: Offset(puzzle.width * (device == phone ? 0.4 : 0.5), puzzle.height * 0.42));
    final view = screen.grid.visibleCells.center;
    final progress = screen.progress;
    final cell = [
      for (var i = 0; i < puzzle.cells.length; i++)
        if (puzzle.cells[i] != 0 && progress.paintedAt(i) != puzzle.cells[i]) i,
    ].reduce((a, b) => _distance(puzzle, a, view) <= _distance(puzzle, b, view) ? a : b);
    screen.select(puzzle.cells[cell]);
    await tester.pump();
    await tester.tapAt(studio.at(screen, cell));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 140));
  }, settle: false),
  Shot('5_home', (tester, device, studio) async {
    for (final (id, done) in [
      ('maki_roll', 1.0),
      ('roast_ham', 0.4),
      ('mango', 1.0),
      ('lime_soda', 0.7),
      ('moon_witch', 0.45),
      ('mermaid_reef', 1.0),
      ('treehouse_tea', 0.55),
    ]) {
      studio.play(id, done: done, biggestFirst: true);
    }
    await tester.runAsync(() => Future<void>.delayed(Duration.zero)); // best scores saved
    (studio.game.screen! as BookScreen).selectTab(Difficulty.expert);
  }),
  Shot('6_done', (tester, device, studio) async {
    // One cell left; painting it brings up the celebration.
    final puzzle = studio.puzzle('treehouse_tea');
    final progress = studio.store.of(puzzle);
    final last = puzzle.cells.length ~/ 2 + puzzle.width ~/ 3;
    for (var i = 0; i < puzzle.cells.length; i++) {
      if (i != last) progress.paint(i, puzzle.cells[i]);
    }
    progress.setScore(356000);
    final screen = await studio.open(tester, progress);
    await tester.tapAt(studio.at(screen, last));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }, leaderboard: true),
  Shot('7_admire', (tester, device, studio) async {
    final id = device == phone ? 'shiba_meadow' : 'mermaid_reef';
    await studio.open(tester, studio.play(id, done: 1));
  }),
];

double _distance(Puzzle p, int i, Offset point) =>
    (Offset(i % p.width + 0.5, i ~/ p.width + 0.5) - point).distanceSquared;

void main() {
  for (final device in [phone, tablet]) {
    for (final shot in shots) {
      testWidgets('${device.name} ${shot.name}', (tester) async {
        final studio = Studio();
        await studio.setUp(tester, device, leaderboard: shot.leaderboard);
        await shot.run(tester, device, studio);
        if (shot.settle) await studio.settle(tester);
        await studio.save(tester, 'build/store/raw/${device.name}/${shot.name}.png');
        await tester.pump(const Duration(seconds: 2)); // let the debounced saves run
      });
    }
  }
}

final _boundary = GlobalKey();

/// The app with its real font and the bundled puzzles, ready to stage a shot.
class Studio {
  late List<Puzzle> puzzles;
  late PaintBookGame game;
  final storage = MemoryStorage();
  late final store = ProgressStore(storage);

  Future<void> setUp(WidgetTester tester, Device device, {bool leaderboard = false}) async {
    tester.view.physicalSize = device.size * device.pixelRatio;
    tester.view.devicePixelRatio = device.pixelRatio;
    addTearDown(tester.view.reset);
    late UiSprites sprites;
    await tester.runAsync(() async {
      await _loadFont();
      puzzles = await loadBundledPuzzles();
      sprites = await UiSprites.load();
    });
    final data = GameData(
      puzzles: puzzles,
      store: store,
      sprites: sprites,
      music: MusicController(_Silent(), storage),
      sounds: SoundEffects(storage, bank: _SilentBank()),
      leaderboard: leaderboard ? const _Showcase() : const NoLeaderboard(),
    );
    await tester.pumpWidget(RepaintBoundary(key: _boundary, child: PixelPaintApp(load: () async => data)));
    await tester.pump();
    await tester.pump();
    game = tester.widget<GameWidget<PaintBookGame>>(find.byType(GameWidget<PaintBookGame>)).game!;
    await settle(tester);
  }

  /// A few frames: lets components mount and short animations finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Puzzle puzzle(String id) => puzzles.firstWhere((p) => p.id == id);

  Future<PaintScreen> open(WidgetTester tester, PuzzleProgress progress) async {
    game.openPuzzle(progress.puzzle);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final screen = game.screen! as PaintScreen;
    // Select the color that is partly done, as a player would have it.
    final partial = [
      for (final e in progress.puzzle.palette)
        if (progress.remaining(e.number) > 0 && progress.remaining(e.number) < _count(progress.puzzle, e.number)) e.number,
    ];
    if (partial.isNotEmpty) screen.select(partial.first);
    await tester.pump(const Duration(milliseconds: 16));
    return screen;
  }

  /// Paints whole colors until about [done] of the picture is finished, then
  /// the top part of the next color, like someone halfway through it.
  /// Colors go in palette order, or [biggestFirst] (backgrounds first).
  PuzzleProgress play(String id, {required double done, bool biggestFirst = false}) {
    final puzzle = this.puzzle(id);
    final progress = store.of(puzzle);
    final cellsOf = <int, List<int>>{};
    for (var i = 0; i < puzzle.cells.length; i++) {
      if (puzzle.cells[i] != 0) (cellsOf[puzzle.cells[i]] ??= []).add(i);
    }
    final numbers = [for (final e in puzzle.palette) e.number];
    if (biggestFirst) numbers.sort((a, b) => cellsOf[b]!.length.compareTo(cellsOf[a]!.length));
    var painted = 0;
    for (final n in numbers) {
      final cells = cellsOf[n]!;
      if (painted >= done * puzzle.paintableCount) {
        for (final i in cells.take(cells.length * 2 ~/ 5)) {
          progress.paint(i, n);
        }
        break;
      }
      for (final i in cells) {
        progress.paint(i, n);
      }
      painted += cells.length;
    }
    _scoreFor(progress);
    return progress;
  }

  /// Paints everything left of a slanted line through [through] (fractions of
  /// the picture): one half in color, the other still numbered.
  PuzzleProgress reveal(String id, {required Offset through}) {
    final puzzle = this.puzzle(id);
    final progress = store.of(puzzle);
    for (var i = 0; i < puzzle.cells.length; i++) {
      final x = (i % puzzle.width + 0.5) / puzzle.width;
      final y = (i ~/ puzzle.width + 0.5) / puzzle.height;
      if (puzzle.cells[i] != 0 && (x - through.dx) + (y - through.dy) * 0.5 < 0) progress.paint(i, puzzle.cells[i]);
    }
    _scoreFor(progress);
    return progress;
  }

  /// A score like a player's: ~25 points a painted cell, combos included, and
  /// a best score for finished pictures.
  void _scoreFor(PuzzleProgress progress) {
    progress.setScore(progress.correctCount * 25 ~/ 10 * 10);
    if (progress.isComplete) unawaited(store.recordFinish(progress));
  }

  /// Zooms until cells are about [cell] logical pixels, centered on [center]
  /// (in cells).
  Future<void> zoomTo(WidgetTester tester, PaintScreen screen, {required double cell, required Offset center}) async {
    final grid = screen.grid;
    grid.zoomStep(cell / grid.fitCell);
    grid.centerOn(center);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// Where cell [index] is on screen.
  Offset at(PaintScreen screen, int index) => screen.grid.absolutePosition.toOffset() + screen.grid.cellCenter(index);

  /// Cells still waiting for the selected color, top to bottom.
  List<int> waiting(PaintScreen screen) {
    final p = screen.progress;
    return [
      for (var i = 0; i < p.puzzle.cells.length; i++)
        if (p.puzzle.cells[i] == screen.selected && p.paintedAt(i) != screen.selected) i,
    ];
  }

  /// The longest row of cells waiting for the selected color ([onScreen]:
  /// only cells fully on screen).
  List<int> longestRun(PaintScreen screen, {bool onScreen = true}) {
    final width = screen.progress.puzzle.width;
    final view = screen.grid.visibleCells;
    bool shown(int i) =>
        !onScreen ||
        (i % width >= view.left.ceil() &&
            i % width + 1 <= view.right.floor() &&
            i ~/ width >= view.top.ceil() &&
            i ~/ width + 1 <= view.bottom.floor() - 1);
    var best = <int>[], run = <int>[];
    for (final i in waiting(screen).where(shown)) {
      if (run.isNotEmpty && (i != run.last + 1 || i ~/ width != run.last ~/ width)) run = [];
      run.add(i);
      if (run.length > best.length) best = List.of(run);
    }
    return best;
  }

  int _count(Puzzle p, int number) => p.cells.where((c) => c == number).length;

  Future<void> save(WidgetTester tester, String path) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundary));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
}

/// Every picture has an online board (for the screenshot only).
class _Showcase implements Leaderboard {
  const _Showcase();

  @override
  bool has(Puzzle puzzle) => true;
  @override
  Future<void> submit(Puzzle puzzle, int score) async {}
  @override
  Future<bool> show(Puzzle puzzle) async => true;
}

class _Silent implements MusicPlayer {
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
}

class _SilentBank implements SoundBank {
  @override
  Future<void> play(String name, {double volume = 1}) async {}
}

var _fontLoaded = false;

/// Poh Sans, instead of the test font that draws every glyph as a box.
Future<void> _loadFont() async {
  if (_fontLoaded) return;
  _fontLoaded = true;
  final font = FontLoader('PohSans')..addFont(rootBundle.load('assets/fonts/PohSans.ttf'));
  await font.load();
}
