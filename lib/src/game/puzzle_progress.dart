import 'package:flutter/foundation.dart';

import '../models/puzzle.dart';

/// What the player has painted so far on one puzzle.
///
/// Cells painted with the right number are locked. Cells painted with a wrong
/// number keep that color (shown as a mistake) until repainted. The [score]
/// of the current run is kept here too, so it is saved and reset with the cells.
class PuzzleProgress extends ChangeNotifier {
  PuzzleProgress(this.puzzle, {Uint8List? restored, int score = 0})
      : _painted = Uint8List(puzzle.cells.length),
        _remaining = List<int>.filled(puzzle.palette.length + 1, 0) {
    for (final n in puzzle.cells) {
      if (n != 0) _remaining[n]++;
    }
    if (restored != null && _isValid(restored)) {
      for (var i = 0; i < restored.length; i++) {
        if (restored[i] != 0) _set(i, restored[i]);
      }
      _score = score;
    }
  }

  final Puzzle puzzle;
  final Uint8List _painted;

  /// Cells still missing the right color, indexed by palette number.
  final List<int> _remaining;
  int _correct = 0;
  int _score = 0;

  int paintedAt(int index) => _painted[index];
  int remaining(int number) => _remaining[number];
  int get correctCount => _correct;
  double get fraction => puzzle.paintableCount == 0 ? 1 : _correct / puzzle.paintableCount;
  bool get isComplete => _correct == puzzle.paintableCount;
  bool get isStarted => _painted.any((n) => n != 0);
  int get score => _score;

  void addScore(int points) {
    if (points == 0) return;
    _score += points;
    notifyListeners();
  }

  void setScore(int score) {
    if (score == _score) return;
    _score = score;
    notifyListeners();
  }

  /// Paints cell [index] with palette [number].
  ///
  /// Returns the cell's previous value, or null when nothing changed (empty
  /// cell, already correct, or already that color).
  int? paint(int index, int number) {
    final target = puzzle.cells[index];
    final current = _painted[index];
    if (target == 0 || current == target || current == number) return null;
    _set(index, number);
    notifyListeners();
    return current;
  }

  /// Flood fill from cell [index]: every cell joined to it (up, down, left,
  /// right) that has the same number gets painted with [number].
  ///
  /// Only when [number] is the right color; a wrong color paints just the
  /// tapped cell, so one slip doesn't cover a whole area with mistakes.
  /// Returns the previous value of every cell that changed.
  Map<int, int> fill(int index, int number) {
    final target = puzzle.cells[index];
    if (target != number) {
      final previous = paint(index, number);
      return previous == null ? const {} : {index: previous};
    }

    final width = puzzle.width;
    final changed = <int, int>{};
    final seen = Uint8List(puzzle.cells.length)..[index] = 1;
    final pending = [index];
    void visit(int i) {
      if (seen[i] == 0 && puzzle.cells[i] == target) {
        seen[i] = 1;
        pending.add(i);
      }
    }

    while (pending.isNotEmpty) {
      final i = pending.removeLast();
      if (_painted[i] != target) {
        changed[i] = _painted[i];
        _set(i, target);
      }
      final x = i % width;
      if (x > 0) visit(i - 1);
      if (x < width - 1) visit(i + 1);
      if (i >= width) visit(i - width);
      if (i + width < puzzle.cells.length) visit(i + width);
    }
    if (changed.isNotEmpty) notifyListeners();
    return changed;
  }

  /// Puts cells back to earlier values, e.g. to undo the stray stroke left by
  /// the first finger of a pinch.
  void revert(Map<int, int> previous) {
    if (previous.isEmpty) return;
    previous.forEach(_set);
    notifyListeners();
  }

  void reset() {
    for (var i = 0; i < _painted.length; i++) {
      if (_painted[i] != 0) _set(i, 0);
    }
    _score = 0;
    notifyListeners();
  }

  Uint8List snapshot() => Uint8List.fromList(_painted);

  void _set(int index, int value) {
    final target = puzzle.cells[index];
    if (_painted[index] == target) {
      _correct--;
      _remaining[target]++;
    }
    _painted[index] = value;
    if (value == target) {
      _correct++;
      _remaining[target]--;
    }
  }

  bool _isValid(Uint8List data) =>
      data.length == _painted.length &&
      data.every((n) => n <= puzzle.palette.length) &&
      // Nothing can be painted on empty cells.
      Iterable.generate(data.length).every((i) => puzzle.cells[i] != 0 || data[i] == 0);
}
