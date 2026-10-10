import 'dart:math' as math;

import 'package:color_by_number/src/app.dart';
import 'package:color_by_number/src/audio/background_music.dart';
import 'package:color_by_number/src/audio/sound_effects.dart';
import 'package:color_by_number/src/data/puzzle_loader.dart';
import 'package:color_by_number/src/game/leaderboard.dart';
import 'package:color_by_number/src/game/paint_tool.dart';
import 'package:color_by_number/src/game/progress_store.dart';
import 'package:color_by_number/src/game/score_keeper.dart';
import 'package:color_by_number/src/models/difficulty.dart';
import 'package:color_by_number/src/models/puzzle.dart';
import 'package:color_by_number/src/scenes/book_screen.dart';
import 'package:color_by_number/src/scenes/dialogs.dart';
import 'package:color_by_number/src/scenes/paint_book_game.dart';
import 'package:color_by_number/src/scenes/paint_screen.dart';
import 'package:color_by_number/src/ui/pixel_button.dart';
import 'package:color_by_number/src/ui/ui_sprites.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

late UiSprites sprites;

class _SilentBank implements SoundBank {
  final played = <String>[];

  @override
  Future<void> play(String name, {double volume = 1}) async => played.add(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => sprites = await UiSprites.load());

  late Puzzle tiny;
  late MemoryStorage storage;
  late ProgressStore store;

  setUp(() {
    tiny = tinyPuzzle();
    storage = MemoryStorage();
    store = ProgressStore(storage);
  });

  GameData data(List<Puzzle> puzzles, {MusicController? music, SoundEffects? sounds, Leaderboard? leaderboard}) =>
      GameData(
        puzzles: puzzles,
        store: store,
        sprites: sprites,
        music: music,
        sounds: sounds,
        leaderboard: leaderboard ?? const NoLeaderboard(),
      );

  Future<void> frames(WidgetTester tester, [int n = 3]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<PaintBookGame> start(WidgetTester tester, GameData d) async {
    await tester.pumpWidget(PixelPaintApp(load: () async => d));
    await tester.pump();
    await tester.pump();
    final game = tester.widget<GameWidget<PaintBookGame>>(find.byType(GameWidget<PaintBookGame>)).game!;
    await frames(tester);
    return game;
  }

  BookScreen book(PaintBookGame game) => game.screen! as BookScreen;
  PaintScreen painting(PaintBookGame game) => game.screen! as PaintScreen;

  Future<PaintScreen> open(WidgetTester tester, PaintBookGame game, Puzzle puzzle) async {
    book(game).selectTab(puzzle.difficulty);
    await frames(tester);
    final slot = book(game).slots.firstWhere((s) => s.$2.puzzle.id == puzzle.id).$1;
    await tester.tapAt(slot.center);
    await frames(tester);
    return painting(game);
  }

  /// Screen position of grid cell ([x], [y]) at the current zoom.
  Offset cell(PaintScreen screen, int x, int y) =>
      screen.grid.absolutePosition.toOffset() + screen.grid.cellCenter(y * screen.progress.puzzle.width + x);

  Future<void> press(WidgetTester tester, PixelButton button) async {
    await tester.tapAt(button.absoluteCenter.toOffset());
    await frames(tester);
  }

  PixelButton buttonLabeled(Iterable<PixelButton> buttons, String label) => buttons.firstWhere((b) => b.label == label);

  /// Opens the coloring page's pause menu.
  Future<PauseDialog> pause(WidgetTester tester, PaintBookGame game, PaintScreen screen) async {
    await press(tester, screen.options);
    return game.children.whereType<PauseDialog>().single;
  }

  testWidgets('paint a whole picture by number', (tester) async {
    // Cells: row 0 = black red, row 1 = green red, row 2 = black green.
    // Palette: 1 Black, 2 Red, 3 Green.
    expect([for (final e in tiny.palette) e.name], ['Black', 'Red', 'Green']);
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    final progress = store.of(tiny);
    expect(screen.selected, 1, reason: 'color 1 is preselected');

    await tester.tapAt(cell(screen, 0, 0));
    await frames(tester);
    expect(progress.paintedAt(0), 1);

    // Black on a red cell is a mistake: painted, but not counted.
    await tester.tapAt(cell(screen, 1, 0));
    await frames(tester);
    expect(progress.paintedAt(1), 1);
    expect(progress.correctCount, 1);

    // Finishing black moves the selection on to red...
    await tester.tapAt(cell(screen, 0, 2));
    await frames(tester);
    expect(screen.selected, 2);
    // ...so dragging down the right column fixes the mistake and paints both reds.
    await tester.dragFrom(cell(screen, 1, 0), cell(screen, 1, 1) - cell(screen, 1, 0));
    await frames(tester);
    expect(progress.paintedAt(1), 2);
    expect(progress.paintedAt(3), 2);

    // Then green is selected; finishing it completes the picture.
    await tester.tapAt(cell(screen, 0, 1));
    await frames(tester);
    await tester.tapAt(cell(screen, 1, 2));
    await frames(tester, 6);
    expect(progress.isComplete, isTrue);
    final dialog = game.children.whereType<CelebrationDialog>().single;
    expect(dialog.newBest, isTrue);

    await press(tester, buttonLabeled(dialog.children.whereType<PixelButton>(), 'More'));
    await frames(tester);
    expect(game.screen, isA<BookScreen>());
    await tester.pump(const Duration(seconds: 1));
    expect(storage.values['progress_v1/tiny'], endsWith(':70'), reason: 'progress and score are saved on leaving');
    expect(storage.values['best_v1/tiny'], '70', reason: 'the best score is the final one');
  });

  testWidgets('a picture reopened with one cell left celebrates on the first tap', (tester) async {
    final progress = store.of(tiny);
    for (var i = 0; i < tiny.cells.length - 1; i++) {
      progress.paint(i, tiny.cells[i]);
    }
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    await tester.tapAt(cell(screen, 1, 2));
    await frames(tester, 6);
    expect(progress.isComplete, isTrue);
    expect(game.children.whereType<CelebrationDialog>(), hasLength(1));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('finishing a color with the first stroke moves on to the next', (tester) async {
    store.of(tiny).paint(0, tiny.cells[0]); // black has one cell left
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    await tester.tapAt(cell(screen, 0, 2));
    await frames(tester);
    await tester.tapAt(cell(screen, 1, 0));
    await frames(tester);
    expect(store.of(tiny).paintedAt(1), 2, reason: 'red was selected');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping a swatch selects that color', (tester) async {
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    await tester.tapAt(screen.palette.absolutePosition.toOffset() + screen.palette.swatchCenter(3));
    await frames(tester);
    expect(screen.selected, 3);
    await tester.tapAt(cell(screen, 0, 1));
    await frames(tester);
    expect(store.of(tiny).paintedAt(2), 3);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a quick second finger turns the stroke into a pinch-zoom', (tester) async {
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    final progress = store.of(tiny);
    expect(screen.grid.canZoomOut, isFalse);

    final first = await tester.startGesture(cell(screen, 0, 0), pointer: 1);
    await tester.pump();
    expect(progress.paintedAt(0), 1, reason: 'one finger paints immediately');
    expect(progress.score, 10);

    final second = await tester.startGesture(cell(screen, 1, 2), pointer: 2);
    await tester.pump();
    expect(progress.isStarted, isFalse, reason: 'the accidental paint is undone');
    expect(progress.score, 0, reason: 'and so are its points');

    await first.moveBy(const Offset(-60, -60));
    await second.moveBy(const Offset(60, 60));
    await first.up();
    await second.up();
    await frames(tester);
    expect(progress.isStarted, isFalse, reason: 'pinching never paints');
    expect(screen.grid.canZoomOut, isTrue, reason: 'zoomed in');

    await press(tester, screen.zoomOut);
    expect(screen.grid.canZoomOut, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('"Find a cell" centers the next cell of the selected color', (tester) async {
    // A big green field with one red cell far from the middle.
    final rows = List.generate(40, (y) => List.generate(60, (x) => x == 45 && y == 30 ? 'r' : 'g').join());
    final big = puzzleFromRows(rows, {'r': red, 'g': green}, id: 'big', name: 'Big');
    expect(big.palette.first.name, 'Red', reason: 'red is number 1, preselected');
    final game = await start(tester, data([big]));
    final screen = await open(tester, game, big);

    await press(tester, screen.find);
    expect(screen.grid.canZoomOut, isTrue, reason: 'zoomed in on it');
    expect(screen.grid.found, 30 * 60 + 45);

    await tester.tapAt(screen.grid.absoluteCenter.toOffset());
    await frames(tester);
    expect(store.of(big).paintedAt(30 * 60 + 45), 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the Fill tool paints a whole touching area in one tap', (tester) async {
    final regions = regionsPuzzle();
    final game = await start(tester, data([regions]));
    final screen = await open(tester, game, regions);
    final progress = store.of(regions);

    await press(tester, screen.fill);
    expect(screen.tool, PaintTool.fill);
    await tester.tapAt(cell(screen, 1, 0));
    await frames(tester);
    expect([0, 1, 3].map(progress.paintedAt), everyElement(1));
    expect(progress.paintedAt(7), 0);
    expect(progress.score, 9, reason: 'Fill scores 3 a cell');

    // Back to the pencil: one cell per tap.
    await press(tester, screen.pencil);
    await tester.tapAt(cell(screen, 1, 2));
    await frames(tester);
    expect(progress.paintedAt(7), 1);
    expect(progress.paintedAt(8), 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the mini map shows while zoomed and moves the view', (tester) async {
    final rows = List.generate(40, (y) => List.generate(60, (x) => x < 30 ? 'r' : 'g').join());
    final big = puzzleFromRows(rows, {'r': red, 'g': green}, id: 'big', name: 'Big');
    final game = await start(tester, data([big]));
    final screen = await open(tester, game, big);
    expect(screen.miniMap.shown, isFalse, reason: 'whole picture is visible');

    // Three steps: enough to zoom both ways on a wide screen.
    for (var i = 0; i < 3; i++) {
      await press(tester, screen.zoomIn);
    }
    expect(screen.miniMap.shown, isTrue);

    // Tap the mini map's bottom-right corner: the view jumps there, nothing is painted.
    final map = screen.miniMap.toAbsoluteRect();
    await tester.tapAt(map.bottomRight - const Offset(8, 8));
    await frames(tester);
    final progress = store.of(big);
    expect(progress.isStarted, isFalse);

    await tester.tapAt(screen.grid.absoluteCenter.toOffset());
    await frames(tester);
    final painted = [for (var i = 0; i < big.cells.length; i++) if (progress.paintedAt(i) != 0) i];
    expect(painted, hasLength(1));
    expect(painted.single % 60, greaterThan(35), reason: 'in the green half');
    expect(painted.single ~/ 60, greaterThan(20), reason: 'in the lower half');

    await press(tester, screen.zoomOut);
    expect(screen.miniMap.shown, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('music and sounds switch off and on, saved; music pauses in the background', (tester) async {
    final player = FakeMusicPlayer();
    final music = MusicController(player, storage);
    final bank = _SilentBank();
    final sounds = SoundEffects(storage, bank: bank);
    final game = await start(tester, data([tiny], music: music, sounds: sounds));
    expect(player.calls, ['play']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(player.calls.last, 'pause');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(player.calls.last, 'play');

    final buttons = book(game).children.whereType<PixelButton>();
    await press(tester, buttons.firstWhere((b) => b.icon == IconRef.note));
    expect(player.calls.last, 'pause');
    expect(storage.values['settings/music'], 'off');
    expect(bank.played, contains('click'), reason: 'buttons click');

    await press(tester, buttons.firstWhere((b) => b.icon == IconRef.speaker));
    expect(storage.values['settings/sfx'], 'off');
    bank.played.clear();

    // The coloring page's pause menu shows the same switches, and the choice outlives the session.
    final screen = await open(tester, game, tiny);
    var menu = await pause(tester, game, screen);
    expect(menu.music.icon, IconRef.noteOff);
    expect(menu.sounds.icon, IconRef.speakerOff);
    await press(tester, buttonLabeled(menu.children.whereType<PixelButton>(), 'Resume'));
    await tester.tapAt(cell(screen, 0, 0));
    await frames(tester);
    expect(bank.played, isEmpty, reason: 'sounds are off');
    expect(MusicController(FakeMusicPlayer(), storage).enabled, isFalse);
    expect(SoundEffects(storage, bank: _SilentBank()).enabled, isFalse);

    // Both switch back on from the pause menu.
    menu = await pause(tester, game, screen);
    await press(tester, menu.music);
    await press(tester, menu.sounds);
    expect(player.calls.last, 'play');
    expect((menu.music.icon, menu.sounds.icon), (IconRef.note, IconRef.speaker));
    expect((storage.values['settings/music'], storage.values['settings/sfx']), ('on', 'on'));
    await press(tester, buttonLabeled(menu.children.whereType<PixelButton>(), 'Resume'));
    bank.played.clear();
    await tester.tapAt(cell(screen, 0, 2));
    await frames(tester);
    expect(bank.played, contains('place'), reason: 'painting makes a sound again');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('bookmarks pick the difficulty', (tester) async {
    final hard = puzzleFromRows(
      [List.generate(12, (i) => String.fromCharCode(97 + i)).join()],
      {for (var i = 0; i < 12; i++) String.fromCharCode(97 + i): 0xFF000000 | (i * 20) << 16 | 0x4080},
      id: 'many_colors',
      name: 'Many Colors',
    );
    expect(hard.difficulty, Difficulty.hard);
    final game = await start(tester, data([tiny, hard]));
    expect([for (final s in book(game).slots) s.$2.puzzle.id], ['tiny']);

    final flag = book(game).flags.firstWhere((f) => f.$2 == Difficulty.hard).$1;
    await tester.tapAt(flag.center);
    await frames(tester);
    expect(game.bookTab, Difficulty.hard);
    expect([for (final s in book(game).slots) s.$2.puzzle.id], ['many_colors']);
  });

  testWidgets('the book flips pages when a difficulty has many pictures', (tester) async {
    final many = [for (var i = 0; i < 30; i++) tinyPuzzle(id: 'tiny_$i')];
    final game = await start(tester, data(many));
    final screen = book(game);
    expect(screen.spreads, greaterThan(1));
    final first = screen.slots.first.$2.puzzle.id;

    await press(tester, screen.children.whereType<PixelButton>().firstWhere((b) => b.icon == IconRef.right));
    expect(game.bookSpread, 1);
    expect(screen.slots.first.$2.puzzle.id, isNot(first));
  });

  for (final size in const [Size(800, 600), Size(1280, 800), Size(360, 640)]) {
    testWidgets('each book page lists its pictures in rows that fit (${size.width.round()}x${size.height.round()})',
        (tester) async {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      final many = [for (var i = 0; i < 30; i++) tinyPuzzle(id: 'tiny_$i')];
      final sounds = SoundEffects(storage, bank: _SilentBank());
      final game = await start(tester, data(many, music: MusicController(FakeMusicPlayer(), storage), sounds: sounds));
      final screen = book(game);
      final rows = [for (final s in screen.slots) s.$1];
      expect(rows.length, inInclusiveRange(2, 8), reason: '2 to 4 rows a page');
      expect(screen.spreads, (many.length / rows.length).ceil());

      // Rows stay on their pages: below the top buttons, left of the bookmarks,
      // above the page arrows, and clear of each other.
      bool isArrow(PixelButton b) => b.icon == IconRef.left || b.icon == IconRef.right;
      final buttons = screen.children.whereType<PixelButton>();
      final top = buttons.where((b) => !isArrow(b)).map((b) => b.toAbsoluteRect().bottom).reduce(math.max);
      final arrows = [for (final b in buttons.where(isArrow)) b.toAbsoluteRect()];
      final flagsLeft = screen.flags.map((f) => f.$1.left).reduce(math.min);
      for (final (i, row) in rows.indexed) {
        expect(row.height, greaterThan(0));
        expect(row.left, greaterThanOrEqualTo(0), reason: 'row $i');
        expect(row.top, greaterThan(top), reason: 'row $i');
        expect(row.right, lessThan(flagsLeft), reason: 'row $i');
        expect(row.bottom, lessThan(arrows.map((a) => a.top).reduce(math.min)), reason: 'row $i');
        for (final other in rows.skip(i + 1)) {
          expect(row.overlaps(other), isFalse, reason: 'row $i and $other');
        }
      }

      // A tap on a row's text, away from its picture, opens it.
      final second = screen.slots[1];
      await tester.tapAt(Offset(second.$1.right - 4, second.$1.center.dy));
      await frames(tester);
      expect(painting(game).progress.puzzle.id, second.$2.puzzle.id);
    });
  }

  testWidgets('quick paints build a combo; each pause drops it a level', (tester) async {
    final strip = puzzleFromRows(['rrrrrr', 'rrrrrr'], {'r': red}, id: 'strip', name: 'Strip');
    final game = await start(tester, data([strip]));
    final screen = await open(tester, game, strip);

    // One row above the picture: the options button, the meter, the score.
    final box = screen.combo.toAbsoluteRect(), score = screen.scoreLabel.toAbsoluteRect();
    expect(box.left, greaterThan(screen.options.toAbsoluteRect().right));
    expect(box.right, lessThan(score.left));
    expect(box.top, score.top, reason: 'in the same row as the score');
    expect(box.bottom, lessThan(screen.grid.toAbsoluteRect().top), reason: 'above the picture');

    Future<void> paint(int i) async {
      await tester.tapAt(cell(screen, i % 6, i ~/ 6));
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (var i = 0; i < 4; i++) {
      await paint(i);
    }
    expect(screen.scorer.score, 40);
    expect(screen.scorer.level, 2, reason: '4 paints in a row');

    await paint(4);
    expect(screen.scorer.score, 60, reason: 'double points at x2');
    for (var i = 5; i < 8; i++) {
      await paint(i);
    }
    final meter = screen.combo.scorer;
    expect((meter.level, screen.scorer.score), (3, 120));

    // The x3 bar runs out: the meter drops to x2 with a fresh bar, not to x1.
    await tester.pump(ScoreKeeper.windowFor(3));
    await frames(tester);
    expect((meter.level, meter.steps), (2, 0), reason: 'one level down, from its first step');
    expect(meter.timeLeft, greaterThan(0.5), reason: 'a new window for x2');

    await paint(8);
    expect(screen.scorer.score, 140, reason: 'painting again goes on at x2');

    // Then the x2 bar runs out too: the combo is over.
    await tester.pump(ScoreKeeper.windowFor(2));
    await frames(tester);
    expect((meter.level, meter.timeLeft), (1, 0.0));
    await tester.pump(const Duration(seconds: 1));
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(1280, 800)]) {
    testWidgets('the score makes room as it grows, beside the combo meter (${size.width.round()}x${size.height.round()})',
        (tester) async {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      final game = await start(tester, data([tiny]));
      final screen = await open(tester, game, tiny);
      final u = game.scale.unit, label = screen.scoreLabel, wide = screen.combo.width;
      for (final score in [9, 999, 9999, 12345, 999999, 1234567, 9999999]) {
        store.of(tiny).setScore(score);
        await frames(tester, 30); // the label counts up to it
        final room = label.toAbsoluteRect(), meter = screen.combo.toAbsoluteRect();
        final text = label.compact ? formatScoreShort(score) : formatScore(score);
        final drawn = game.text.measure(text, label.level).width + u + 16 * game.scale.half;
        expect(drawn, lessThanOrEqualTo(room.width), reason: 'star and "$text" fit the label');
        expect(room.right, lessThanOrEqualTo(size.width));
        expect(room.right - drawn, greaterThan(meter.right), reason: 'the star of $score clears the meter');
        expect(meter.width, greaterThanOrEqualTo(48 * u), reason: 'the meter keeps 48u at $score');
        if (size.width / u >= 200) expect(label.compact, isFalse, reason: 'room for the whole number');
      }
      if (size.width / u < 200) expect(screen.combo.width, lessThan(wide), reason: 'on a phone the meter gave way');
    });
  }

  testWidgets('combo milestones get a wow and a cheer; other level-ups a sparkle', (tester) async {
    final field = puzzleFromRows(['rrrrrrrrrr', 'rrrrrrrrrr'], {'r': red}, id: 'field', name: 'Field');
    final bank = _SilentBank();
    final game = await start(tester, data([field], sounds: SoundEffects(storage, bank: bank)));
    final screen = await open(tester, game, field);
    Future<void> paint(int i) async {
      await tester.tapAt(cell(screen, i % 10, i ~/ 10));
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (var i = 0; i < 4; i++) {
      bank.played.clear();
      await paint(i);
    }
    expect(screen.scorer.level, 2);
    expect(bank.played, containsAllInOrder(['place', 'magic']), reason: 'x2 sparkles');
    expect(bank.played, isNot(contains('wow')));

    for (var i = 4; i < 16; i++) {
      bank.played.clear();
      await paint(i);
    }
    expect(screen.scorer.level, 5);
    expect(bank.played, containsAllInOrder(['place', 'wow']), reason: 'x5 is a milestone');
    expect(bank.played, isNot(contains('magic')), reason: 'the wow instead of the sparkle');
    expect(screen.slime.speech, 'Wow! x5!');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the combo waits while the pause menu is open', (tester) async {
    final strip = puzzleFromRows(['rrrrrr', 'rrrrrr'], {'r': red}, id: 'strip', name: 'Strip');
    final game = await start(tester, data([strip]));
    final screen = await open(tester, game, strip);
    for (var i = 0; i < 8; i++) {
      await tester.tapAt(cell(screen, i % 6, i ~/ 6));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(screen.scorer.level, 3);
    final left = screen.scorer.timeLeft;

    final menu = await pause(tester, game, screen);
    await tester.pump(ScoreKeeper.windowFor(3) * 3);
    expect(screen.scorer.level, 3, reason: 'the clock stands still');
    await press(tester, buttonLabeled(menu.children.whereType<PixelButton>(), 'Resume'));
    expect(game.hasDialog, isFalse);
    expect(screen.scorer.level, 3);
    expect(screen.scorer.timeLeft, closeTo(left, 0.1), reason: 'the bar goes on where it stopped');

    // Once closed, the clock runs again.
    await tester.pump(ScoreKeeper.windowFor(3));
    expect(screen.scorer.level, 2);
    await tester.pump(const Duration(seconds: 1));
  });

  /// The app going to the background and coming back, as the system reports it.
  void background(WidgetTester tester) {
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  void foreground(WidgetTester tester) {
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  testWidgets('going to the background pauses the coloring page, combo and all', (tester) async {
    final strip = puzzleFromRows(['rrrrrr', 'rrrrrr'], {'r': red}, id: 'strip', name: 'Strip');
    final game = await start(tester, data([strip]));
    final screen = await open(tester, game, strip);
    for (var i = 0; i < 8; i++) {
      await tester.tapAt(cell(screen, i % 6, i ~/ 6));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(screen.scorer.level, 3);

    background(tester);
    await tester.pump(ScoreKeeper.windowFor(3) * 3);
    expect(screen.scorer.level, 3, reason: 'the combo stopped at once');
    foreground(tester);
    await frames(tester);
    expect(game.children.whereType<PauseDialog>(), hasLength(1), reason: 'one pause menu is waiting');

    await tester.pump(ScoreKeeper.windowFor(3) * 2);
    expect(screen.scorer.level, 3, reason: 'still frozen until the menu closes');
    await press(tester, buttonLabeled(game.children.whereType<PauseDialog>().single.children.whereType<PixelButton>(), 'Resume'));
    expect(game.hasDialog, isFalse);
    expect(screen.scorer.level, 3);

    await tester.pump(ScoreKeeper.windowFor(3));
    expect(screen.scorer.level, 2, reason: 'then it drops as usual');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('going to the background keeps an open dialog and adds no other', (tester) async {
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    final menu = await pause(tester, game, screen);
    await press(tester, buttonLabeled(menu.children.whereType<PixelButton>(), 'Reset'));
    final question = game.children.whereType<ConfirmDialog>().single;

    background(tester);
    foreground(tester);
    await frames(tester);
    expect(game.children.whereType<DialogLayer>(), [question]);

    // The same over the celebration.
    await press(tester, buttonLabeled(question.children.whereType<PixelButton>(), 'Cancel'));
    final progress = store.of(tiny);
    for (var i = 0; i < tiny.cells.length - 1; i++) {
      progress.paint(i, tiny.cells[i]);
    }
    await tester.tapAt(cell(screen, 1, 2));
    await frames(tester, 6);
    final celebration = game.children.whereType<CelebrationDialog>().single;
    background(tester);
    foreground(tester);
    await frames(tester);
    expect(game.children.whereType<DialogLayer>(), [celebration]);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the pause menu closes on Resume or a tap outside, and goes Home', (tester) async {
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    var menu = await pause(tester, game, screen);
    expect(game.hasDialog, isTrue);
    await press(tester, buttonLabeled(menu.children.whereType<PixelButton>(), 'Resume'));
    expect(game.hasDialog, isFalse);

    menu = await pause(tester, game, screen);
    await tester.tapAt(menu.panel.topLeft - const Offset(4, 4));
    await frames(tester);
    expect(game.hasDialog, isFalse);
    expect(store.of(tiny).isStarted, isFalse, reason: 'a tap that closes the menu never paints');

    menu = await pause(tester, game, screen);
    await press(tester, buttonLabeled(menu.children.whereType<PixelButton>(), 'Home'));
    expect(game.screen, isA<BookScreen>());
    expect(game.hasDialog, isFalse);
  });

  testWidgets('a finished picture goes to its leaderboard', (tester) async {
    final leaderboard = FakeLeaderboard({'tiny'});
    final progress = store.of(tiny);
    for (var i = 0; i < tiny.cells.length - 1; i++) {
      progress.paint(i, tiny.cells[i]);
    }
    final game = await start(tester, data([tiny], leaderboard: leaderboard));
    final screen = await open(tester, game, tiny);
    final menu = await pause(tester, game, screen);
    expect(menu.trophy.isMounted, isTrue);
    await press(tester, menu.trophy);
    expect(leaderboard.shown, ['tiny'], reason: 'the pause menu opens the board');
    await press(tester, buttonLabeled(menu.children.whereType<PixelButton>(), 'Resume'));

    await tester.tapAt(cell(screen, 1, 2));
    await frames(tester, 6);
    expect(leaderboard.submitted, {'tiny': 10});
    final dialog = game.children.whereType<CelebrationDialog>().single;
    await press(tester, buttonLabeled(dialog.children.whereType<PixelButton>(), 'Ranks'));
    expect(leaderboard.shown, ['tiny', 'tiny']);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('pictures without an online board show no leaderboard button', (tester) async {
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    final menu = await pause(tester, game, screen);
    expect(menu.trophy.isMounted, isFalse);
    expect(menu.music.isMounted || menu.sounds.isMounted, isFalse, reason: 'no music or sounds to switch');
  });

  testWidgets('starting over asks first, then clears the picture and its score', (tester) async {
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    await tester.tapAt(cell(screen, 0, 0));
    await frames(tester);
    final progress = store.of(tiny);
    expect(progress.score, 10);

    final menu = await pause(tester, game, screen);
    await press(tester, buttonLabeled(menu.children.whereType<PixelButton>(), 'Reset'));
    expect(game.children.whereType<PauseDialog>(), isEmpty, reason: 'the question replaces the menu');
    final dialog = game.children.whereType<ConfirmDialog>().single;
    await press(tester, buttonLabeled(dialog.children.whereType<PixelButton>(), 'Clear'));
    expect(game.hasDialog, isFalse);
    expect(progress.isStarted, isFalse);
    expect(progress.score, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the back button closes a dialog, then leaves the coloring page', (tester) async {
    final game = await start(tester, data([tiny]));
    final screen = await open(tester, game, tiny);
    await pause(tester, game, screen);
    expect(game.hasDialog, isTrue);

    await tester.binding.handlePopRoute();
    await frames(tester);
    expect(game.hasDialog, isFalse);
    expect(game.screen, isA<PaintScreen>());

    await tester.binding.handlePopRoute();
    await frames(tester);
    expect(game.screen, isA<BookScreen>());
  });

  testWidgets('the slime moves off cells still to paint once hands are off the picture', (tester) async {
    final strip = puzzleFromRows(['rrrrrr', 'rrrrrr'], {'r': red}, id: 'strip', name: 'Strip');
    final game = await start(tester, data([strip]));
    final screen = await open(tester, game, strip);
    final slime = screen.slime, progress = store.of(strip);
    Rect body() => slime.body.shift(slime.absolutePosition.toOffset());
    final side = screen.grid.cell;
    bool coversWaiting() => [
          for (var i = 0; i < strip.cells.length; i++)
            if (progress.paintedAt(i) != strip.cells[i])
              Rect.fromCenter(center: cell(screen, i % 6, i ~/ 6), width: side, height: side),
        ].any(body().overlaps);
    void sitOn(int x, int y) => slime.place(cell(screen, x, y).toVector2() - slime.body.center.toVector2());

    expect(screen.grid.toAbsoluteRect().contains(body().center), isTrue, reason: 'it lives on the picture');
    expect(coversWaiting(), isFalse, reason: 'placed on a clear spot');

    // Its body is not a brush.
    sitOn(0, 0);
    expect(coversWaiting(), isTrue);
    await tester.tapAt(body().center);
    expect(progress.paintedAt(0), 0);

    await frames(tester, 30);
    expect(slime.moving, isFalse);
    expect(coversWaiting(), isFalse, reason: 'it scooted away');
    expect(slime.speech, 'Sorry!');

    // Not while a finger is on the picture.
    final finger = await tester.startGesture(cell(screen, 5, 1));
    sitOn(1, 0);
    final held = slime.position.clone();
    await frames(tester, 30);
    expect(slime.position, held);
    expect(coversWaiting(), isTrue);
    await finger.up();
    await frames(tester, 30);
    expect(coversWaiting(), isFalse);
    expect(slime.speech, 'Sorry!');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('every bundled sprite loads as a valid puzzle', (tester) async {
    final puzzles = (await tester.runAsync(loadBundledPuzzles))!;
    expect(puzzles, isNotEmpty);
    for (final p in puzzles) {
      expect(p.palette.length, greaterThanOrEqualTo(2), reason: p.id);
      expect(p.paintableCount, greaterThan(0), reason: p.id);
    }
    expect({for (final p in puzzles) p.difficulty}, Difficulty.values.toSet());
    final byId = {for (final p in puzzles) p.id: p};
    expect(byId.keys, containsAll(['lemon', 'mango', 'iron_sword']));
    expect(byId['sleepy_cat']!.difficulty, Difficulty.medium);
    expect(byId['shiba_meadow']!.difficulty, Difficulty.hard);
    for (final id in ['moon_witch', 'mermaid_reef', 'treehouse_tea']) {
      expect(byId[id]!.difficulty, Difficulty.expert, reason: id);
    }
  });
}
