import 'dart:convert';

import 'package:color_by_number/src/game/progress_store.dart';
import 'package:color_by_number/src/game/puzzle_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('PuzzleProgress', () {
    test('right color counts and locks the cell', () {
      final puzzle = tinyPuzzle();
      final progress = PuzzleProgress(puzzle);
      final target = puzzle.cells[0];

      expect(progress.paint(0, target), 0);
      expect(progress.correctCount, 1);
      expect(progress.remaining(target), 1);
      // Locked: neither another color nor the same color changes it.
      expect(progress.paint(0, target % 3 + 1), isNull);
      expect(progress.paint(0, target), isNull);
      expect(progress.paintedAt(0), target);
    });

    test('wrong color is kept as a mistake until repainted', () {
      final puzzle = tinyPuzzle();
      final progress = PuzzleProgress(puzzle);
      final target = puzzle.cells[0];
      final wrong = target % 3 + 1;

      expect(progress.paint(0, wrong), 0);
      expect(progress.paintedAt(0), wrong);
      expect(progress.correctCount, 0);
      expect(progress.isStarted, isTrue);

      expect(progress.paint(0, target), wrong);
      expect(progress.correctCount, 1);
    });

    test('completes when every cell has its color, and notifies', () {
      final puzzle = tinyPuzzle();
      final progress = PuzzleProgress(puzzle);
      var notified = 0;
      progress.addListener(() => notified++);

      for (var i = 0; i < puzzle.cells.length; i++) {
        progress.paint(i, puzzle.cells[i]);
      }
      expect(progress.isComplete, isTrue);
      expect(progress.fraction, 1);
      expect(notified, puzzle.cells.length);
      for (final e in puzzle.palette) {
        expect(progress.remaining(e.number), 0);
      }
    });

    test('revert restores earlier values and counts', () {
      final puzzle = tinyPuzzle();
      final progress = PuzzleProgress(puzzle);
      final undo = <int, int>{};
      for (final i in [0, 1]) {
        undo[i] = progress.paint(i, puzzle.cells[i])!;
      }
      expect(progress.correctCount, 2);

      progress.revert(undo);
      expect(progress.correctCount, 0);
      expect(progress.isStarted, isFalse);
      expect(progress.remaining(puzzle.cells[0]), isPositive);
    });

    test('fill paints the whole touching area of that number', () {
      final puzzle = regionsPuzzle();
      final progress = PuzzleProgress(puzzle);
      final redNumber = puzzle.cells[0];
      var notified = 0;
      progress.addListener(() => notified++);

      final changed = progress.fill(0, redNumber);
      expect(changed.keys.toSet(), {0, 1, 3}, reason: 'top-left red area only');
      expect(changed.values.toSet(), {0});
      expect(progress.paintedAt(7), 0, reason: 'separate red area is untouched');
      expect(notified, 1, reason: 'one notification for the whole fill');

      // Filling a finished area again changes nothing.
      expect(progress.fill(1, redNumber), isEmpty);
    });

    test('fill goes through already-painted cells and fixes mistakes', () {
      final puzzle = regionsPuzzle();
      final progress = PuzzleProgress(puzzle);
      final redNumber = puzzle.cells[0];
      final greenNumber = puzzle.cells[2];
      progress.paint(0, redNumber); // correct, sits between cells 1 and 3
      progress.paint(1, greenNumber); // mistake

      final changed = progress.fill(3, redNumber);
      expect(changed, {1: greenNumber, 3: 0});
      expect([0, 1, 3].map(progress.paintedAt), everyElement(redNumber));
    });

    test('fill with the wrong color only marks the tapped cell', () {
      final puzzle = regionsPuzzle();
      final progress = PuzzleProgress(puzzle);
      final greenNumber = puzzle.cells[2];

      expect(progress.fill(0, greenNumber), {0: 0});
      expect(progress.paintedAt(1), 0);
      expect(progress.correctCount, 0);
    });

    test('a fill can be reverted', () {
      final puzzle = regionsPuzzle();
      final progress = PuzzleProgress(puzzle);
      progress.revert(progress.fill(0, puzzle.cells[0]));
      expect(progress.isStarted, isFalse);
    });

    test('reset clears everything', () {
      final puzzle = tinyPuzzle();
      final progress = PuzzleProgress(puzzle)
        ..paint(0, puzzle.cells[0])
        ..paint(1, puzzle.cells[0]);
      progress.reset();
      expect(progress.isStarted, isFalse);
      expect(progress.correctCount, 0);
    });

    test('restores a snapshot, and ignores one that does not fit', () {
      final puzzle = tinyPuzzle();
      final original = PuzzleProgress(puzzle)
        ..paint(0, puzzle.cells[0])
        ..paint(1, puzzle.cells[0]);
      final restored = PuzzleProgress(puzzle, restored: original.snapshot());
      expect(restored.correctCount, original.correctCount);
      expect(restored.paintedAt(1), original.paintedAt(1));

      final bad = original.snapshot()..[2] = 99;
      expect(PuzzleProgress(puzzle, restored: bad).isStarted, isFalse);
    });
  });

  group('ProgressStore', () {
    test('saves progress and loads it back in a new session', () async {
      final storage = MemoryStorage();
      final puzzle = tinyPuzzle();
      final first = ProgressStore(storage);
      first.of(puzzle).paint(0, puzzle.cells[0]);
      await first.flush();

      final second = ProgressStore(storage).of(puzzle);
      expect(second.correctCount, 1);
      expect(second.paintedAt(0), puzzle.cells[0]);
    });

    testWidgets('debounces saves', (tester) async {
      final storage = MemoryStorage();
      final puzzle = tinyPuzzle();
      final store = ProgressStore(storage, saveDelay: const Duration(milliseconds: 400));
      store.of(puzzle).paint(0, puzzle.cells[0]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(storage.values, isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(storage.values, hasLength(1));
    });

    test('drops saved progress when the picture changed', () async {
      final storage = MemoryStorage();
      final store = ProgressStore(storage);
      final puzzle = tinyPuzzle(id: 'same');
      store.of(puzzle).paint(0, puzzle.cells[0]);
      await store.flush();

      final changed = puzzleFromRows(['rg', 'gr'], {'r': red, 'g': green}, id: 'same');
      expect(ProgressStore(storage).of(changed).isStarted, isFalse);
    });

    test('saves the score with the picture', () async {
      final storage = MemoryStorage();
      final puzzle = tinyPuzzle();
      final first = ProgressStore(storage);
      first.of(puzzle)
        ..paint(0, puzzle.cells[0])
        ..addScore(120);
      await first.flush();
      expect(ProgressStore(storage).of(puzzle).score, 120);
    });

    test('reads saves from before scores existed', () {
      final storage = MemoryStorage();
      final puzzle = tinyPuzzle();
      final cells = PuzzleProgress(puzzle)..paint(0, puzzle.cells[0]);
      storage.values['progress_v1/tiny'] = '${puzzle.fingerprint}:${base64Encode(cells.snapshot())}';
      final loaded = ProgressStore(storage).of(puzzle);
      expect(loaded.correctCount, 1);
      expect(loaded.score, 0);
    });

    test('keeps the best finished score per picture', () async {
      final storage = MemoryStorage();
      final store = ProgressStore(storage);
      final puzzle = tinyPuzzle();
      var notified = 0;
      store.addListener(() => notified++);
      final progress = store.of(puzzle)..addScore(300);
      expect(store.bestOf(puzzle), 0);

      expect(await store.recordFinish(progress), isTrue);
      expect(store.bestOf(puzzle), 300);
      expect(notified, 1);

      progress
        ..reset()
        ..addScore(200);
      expect(await store.recordFinish(progress), isFalse, reason: 'lower than the best');
      expect(ProgressStore(storage).bestOf(puzzle), 300, reason: 'kept across sessions');
    });

    test('removes the save after a reset', () async {
      final storage = MemoryStorage();
      final store = ProgressStore(storage);
      final puzzle = tinyPuzzle();
      store.of(puzzle).paint(0, puzzle.cells[0]);
      await store.flush();
      store.of(puzzle).reset();
      await store.flush();
      expect(storage.values, isEmpty);
    });
  });
}
