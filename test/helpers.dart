import 'dart:typed_data';

import 'package:color_by_number/src/audio/background_music.dart';
import 'package:color_by_number/src/game/leaderboard.dart';
import 'package:color_by_number/src/models/puzzle.dart';

/// Builds a puzzle from ASCII art: each character maps to an ARGB color in
/// [colors]; any other character is a transparent pixel.
Puzzle puzzleFromRows(List<String> rows, Map<String, int> colors, {String id = 'test', String? name}) {
  final width = rows.first.length;
  final rgba = Uint8List(width * rows.length * 4);
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < width; x++) {
      final argb = colors[rows[y][x]];
      if (argb == null) continue;
      final o = (y * width + x) * 4;
      rgba[o] = argb >> 16 & 0xFF;
      rgba[o + 1] = argb >> 8 & 0xFF;
      rgba[o + 2] = argb & 0xFF;
      rgba[o + 3] = 0xFF;
    }
  }
  return Puzzle.fromRgba(id: id, name: name ?? id, width: width, height: rows.length, rgba: rgba);
}

const red = 0xFFE53935;
const green = 0xFF43A047;
const black = 0xFF101010;

/// A 3x2 puzzle: black / red / green, no empty cells after trimming.
Puzzle tinyPuzzle({String id = 'tiny'}) => puzzleFromRows(
      [
        '....',
        '.kr.',
        '.gr.',
        '.kg.',
      ],
      {'k': black, 'r': red, 'g': green},
      id: id,
      name: 'Tiny',
    );

/// Two red and two green areas:
///
///     r r g
///     r g g
///     g r r
Puzzle regionsPuzzle() => puzzleFromRows(['rrg', 'rgg', 'grr'], {'r': red, 'g': green}, id: 'regions', name: 'Regions');

class FakeMusicPlayer implements MusicPlayer {
  final calls = <String>[];

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> dispose() async => calls.add('dispose');
}

/// Records what the game sends to the online leaderboards.
class FakeLeaderboard implements Leaderboard {
  FakeLeaderboard(this.boards);

  final Set<String> boards;
  final submitted = <String, int>{};
  final shown = <String>[];

  @override
  bool has(Puzzle puzzle) => boards.contains(puzzle.id);
  @override
  Future<void> submit(Puzzle puzzle, int score) async => submitted[puzzle.id] = score;
  @override
  Future<bool> show(Puzzle puzzle) async {
    shown.add(puzzle.id);
    return true;
  }
}
