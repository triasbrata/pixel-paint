import '../models/puzzle.dart';

/// Online high scores, one board per picture.
abstract interface class Leaderboard {
  /// Whether [puzzle] has an online board here (configured, and the platform
  /// supports it).
  bool has(Puzzle puzzle);

  /// Sends the score of a finished run; the service keeps each player's best.
  Future<void> submit(Puzzle puzzle, int score);

  /// Opens the board for [puzzle] (signing in first if needed); false when it
  /// couldn't.
  Future<bool> show(Puzzle puzzle);
}

/// No online boards: the web build, tests, and before Play Games is set up.
class NoLeaderboard implements Leaderboard {
  const NoLeaderboard();

  @override
  bool has(Puzzle puzzle) => false;
  @override
  Future<void> submit(Puzzle puzzle, int score) async {}
  @override
  Future<bool> show(Puzzle puzzle) async => false;
}
