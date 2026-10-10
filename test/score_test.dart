import 'package:color_by_number/src/game/paint_tool.dart';
import 'package:color_by_number/src/game/puzzle_progress.dart';
import 'package:color_by_number/src/game/score_keeper.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late PuzzleProgress progress;
  late Duration time;
  late ScoreKeeper scorer;

  setUp(() {
    progress = PuzzleProgress(tinyPuzzle());
    time = Duration.zero;
    scorer = ScoreKeeper(progress, now: () => time);
  });

  /// A correct Pencil paint, [gap] after the previous one.
  ScoreEvent pencil({Duration gap = const Duration(milliseconds: 200)}) {
    time += gap;
    return scorer.paint(PaintTool.pencil, correctCells: 1);
  }

  test('the Pencil scores 10 a cell, Fill 3 a cell', () {
    expect(pencil().points, 10);
    expect(scorer.paint(PaintTool.fill, correctCells: 12).points, 36);
    expect(scorer.score, 46);
    expect(progress.score, 46, reason: 'the score is kept with the picture');
  });

  test('every 4 paints in a row raise the multiplier, up to 20x', () {
    expect([for (var i = 0; i < 4; i++) pencil().points], [10, 10, 10, 10]);
    expect(scorer.lastEvent!.leveledUp, isTrue);
    expect(scorer.level, 2);
    expect(pencil().points, 20, reason: 'the next paint counts double');
    expect(scorer.steps, 1);

    // A Fill tap is one step, however big the area.
    final fill = scorer.paint(PaintTool.fill, correctCells: 50);
    expect(fill.points, 3 * 50 * 2);
    expect(scorer.steps, 2);

    for (var i = 0; i < 200; i++) {
      pencil(gap: const Duration(milliseconds: 50));
    }
    expect(scorer.level, ScoreKeeper.maxLevel);
    expect(scorer.steps, 0);
    expect(pencil().points, 10 * ScoreKeeper.maxLevel);
  });

  test('a pause longer than the window drops the multiplier one level at a time', () {
    for (var i = 0; i < 9; i++) {
      pencil();
    }
    expect((scorer.level, scorer.steps), (3, 1));
    time += const Duration(milliseconds: 1500);
    expect(scorer.level, 3);
    expect(scorer.timeLeft, closeTo(1 - 1500000 / ScoreKeeper.windowFor(3).inMicroseconds, 1e-6));

    // 3x ran out: 2x, from its first step, with a fresh window.
    time += ScoreKeeper.windowFor(3) - const Duration(milliseconds: 1500) + const Duration(milliseconds: 500);
    expect((scorer.level, scorer.steps), (2, 0));
    expect(scorer.timeLeft, closeTo(1 - 500000 / ScoreKeeper.windowFor(2).inMicroseconds, 1e-6));
    expect(pencil(gap: Duration.zero).points, 20, reason: 'painting again goes on from 2x');
    expect(scorer.steps, 1);

    // Then 2x runs out too: the combo is over.
    time += ScoreKeeper.windowFor(2) + const Duration(milliseconds: 1);
    expect(scorer.level, 1);
    expect(scorer.timeLeft, 0);
    expect(pencil().points, 10, reason: 'a new combo starts from 1x');
    expect(scorer.steps, 1);
  });

  test('a long pause drops several levels', () {
    for (var i = 0; i < 20; i++) {
      pencil();
    }
    expect(scorer.level, 6);
    time += ScoreKeeper.windowFor(6) + ScoreKeeper.windowFor(5) + const Duration(milliseconds: 1);
    expect((scorer.level, scorer.steps), (4, 0));
    time += const Duration(minutes: 1);
    expect((scorer.level, scorer.timeLeft), (1, 0.0));
  });

  test('the window shrinks from 3 to 2 seconds as the multiplier rises', () {
    expect(ScoreKeeper.windowFor(1), const Duration(seconds: 3));
    expect(ScoreKeeper.windowFor(20), const Duration(seconds: 2));
    expect(ScoreKeeper.windowFor(10) < ScoreKeeper.windowFor(5), isTrue);
  });

  test('a wrong color breaks the combo but keeps the points', () {
    for (var i = 0; i < 5; i++) {
      pencil();
    }
    final mistake = scorer.paint(PaintTool.pencil, mistake: true);
    expect(mistake.points, 0);
    expect(mistake.comboBroken, isTrue);
    expect(scorer.level, 1);
    expect(scorer.score, 60);

    // Nothing to break when there was no combo.
    expect(scorer.paint(PaintTool.pencil, mistake: true).comboBroken, isFalse);
  });

  test('a stroke can be undone, combo and all', () {
    pencil();
    final before = scorer.snapshot();
    for (var i = 0; i < 4; i++) {
      pencil();
    }
    expect(scorer.level, 2);

    scorer.restore(before);
    expect(scorer.score, 10);
    expect(scorer.level, 1);
    expect(scorer.steps, 1);
  });

  test('starting over clears the score and the combo', () {
    for (var i = 0; i < 4; i++) {
      pencil();
    }
    progress.reset();
    scorer.reset();
    expect(scorer.score, 0);
    expect(scorer.level, 1);
  });

  test('scores are shown with thousands separators', () {
    expect(formatScore(0), '0');
    expect(formatScore(950), '950');
    expect(formatScore(12345), '12,345');
    expect(formatScore(1234567), '1,234,567');
  });

  test('a tight spot shows a short score, never more than it is', () {
    expect(formatScoreShort(9999), '9,999');
    expect(formatScoreShort(10000), '10K');
    expect(formatScoreShort(12345), '12K');
    expect(formatScoreShort(999999), '999K');
    expect(formatScoreShort(1234567), '1.2M');
    expect(formatScoreShort(1999999), '1.9M');
    expect(formatScoreShort(12345678), '12M');
  });
}
