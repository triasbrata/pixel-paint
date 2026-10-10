import 'package:flutter/foundation.dart';

import 'paint_tool.dart';
import 'puzzle_progress.dart';

/// What one paint action earned, for the score effects.
class ScoreEvent {
  const ScoreEvent({
    required this.points,
    required this.level,
    this.leveledUp = false,
    this.comboBroken = false,
  });

  /// Points added to the score (0 for a wrong color).
  final int points;

  /// The combo multiplier after this action.
  final int level;

  /// This action raised the multiplier.
  final bool leveledUp;

  /// A wrong color ended a running combo.
  final bool comboBroken;
}

/// Saved state of a [ScoreKeeper], to undo a stroke.
typedef ScoreSnapshot = ({int score, int chain, Duration last});

/// Points and the combo multiplier for one painting session.
///
/// Every correct paint (a cell with the Pencil, or one Fill tap) adds a step
/// to the combo chain; every [stepsPerLevel] steps raise the multiplier, up to
/// [maxLevel]. When the player pauses longer than the combo window (which gets
/// shorter as the multiplier rises), the multiplier drops one level and the
/// window starts again, down to 1x; a wrong color ends the combo at once.
///
/// The score itself lives in [PuzzleProgress], so it is saved and reset with
/// the picture; the combo only lasts while the picture is open.
class ScoreKeeper extends ChangeNotifier {
  ScoreKeeper(this.progress, {required this.now});

  static const pencilPoints = 10;
  static const fillPoints = 3;
  static const maxLevel = 20;
  static const stepsPerLevel = 4;
  static const slowestWindow = Duration(seconds: 3);
  static const fastestWindow = Duration(seconds: 2);

  final PuzzleProgress progress;

  /// A monotonic clock (a stopwatch in the app, a fake one in tests).
  final Duration Function() now;

  int _chain = 0;
  Duration _last = Duration.zero;
  ScoreEvent? _lastEvent;

  int get score => progress.score;

  /// What the latest paint did, for the widgets that animate it.
  ScoreEvent? get lastEvent => _lastEvent;

  /// The multiplier right now: 1 when there is no combo.
  int get level => _levelOf(_settled().chain);

  /// Correct paints toward the next level, 0 to [stepsPerLevel] - 1.
  int get steps {
    final chain = _settled().chain;
    return _levelOf(chain) == maxLevel ? 0 : chain % stepsPerLevel;
  }

  /// Share of the current level's window left: 1 right after a paint (or a
  /// drop), 0 once the combo is over.
  double get timeLeft {
    final (:chain, :since) = _settled();
    if (chain == 0) return 0;
    final left = 1 - (now() - since).inMicroseconds / windowFor(_levelOf(chain)).inMicroseconds;
    return left.clamp(0.0, 1.0);
  }

  /// How long the player may pause at multiplier [level] before it drops.
  static Duration windowFor(int level) =>
      slowestWindow - (slowestWindow - fastestWindow) * ((level - 1) / (maxLevel - 1));

  /// Scores one paint action: [correctCells] cells that just got their right
  /// color (1 for the Pencil, the whole area for a Fill), or a [mistake].
  ScoreEvent paint(PaintTool tool, {int correctCells = 0, bool mistake = false}) {
    _settle();
    if (mistake) {
      final broken = _chain > 0;
      _chain = 0;
      return _emit(ScoreEvent(points: 0, level: 1, comboBroken: broken));
    }
    if (correctCells == 0) return ScoreEvent(points: 0, level: level);

    final before = _levelOf(_chain);
    final base = tool == PaintTool.pencil ? pencilPoints : fillPoints;
    final points = base * correctCells * before;
    _chain++;
    _last = now();
    progress.addScore(points);
    final after = _levelOf(_chain);
    return _emit(ScoreEvent(points: points, level: after, leveledUp: after > before));
  }

  ScoreEvent _emit(ScoreEvent event) {
    _lastEvent = event;
    notifyListeners();
    return event;
  }

  /// Ends the combo, e.g. when the picture starts over.
  void reset() {
    _chain = 0;
    _lastEvent = null;
    notifyListeners();
  }

  ScoreSnapshot snapshot() => (score: progress.score, chain: _chain, last: _last);

  void restore(ScoreSnapshot s) {
    _chain = s.chain;
    _last = s.last;
    progress.setScore(s.score);
    notifyListeners();
  }

  /// The chain and when its current level's window began, now: every window
  /// that ran out since the last paint dropped one level, to the first step
  /// of the level below (from 2x the combo is over).
  ({int chain, Duration since}) _settled() {
    final t = now();
    var chain = _chain, since = _last;
    while (chain > 0) {
      final level = _levelOf(chain);
      final end = since + windowFor(level);
      if (t <= end) break;
      chain = level <= 1 ? 0 : (level - 2) * stepsPerLevel;
      since = end;
    }
    return (chain: chain, since: since);
  }

  void _settle() {
    final (:chain, :since) = _settled();
    _chain = chain;
    _last = since;
  }

  static int _levelOf(int chain) => (1 + chain ~/ stepsPerLevel).clamp(1, maxLevel);
}

/// 12345 → "12,345".
String formatScore(int score) {
  final digits = '$score';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A short score for a tight spot, never more than it is: 9,999, 12K, 999K,
/// 1.2M, 12M.
String formatScoreShort(int score) {
  if (score < 10000) return formatScore(score);
  if (score < 1000000) return '${score ~/ 1000}K';
  if (score < 10000000) return '${score ~/ 1000000}.${score ~/ 100000 % 10}M';
  return '${score ~/ 1000000}M';
}
