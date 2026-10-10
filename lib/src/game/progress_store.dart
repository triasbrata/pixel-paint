import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle.dart';
import 'puzzle_progress.dart';

/// Key-value storage for saved progress, so tests can swap in memory storage.
abstract interface class ProgressStorage {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class SharedPrefsStorage implements ProgressStorage {
  SharedPrefsStorage._(this._prefs);

  static Future<SharedPrefsStorage> open() async => SharedPrefsStorage._(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(),
        ),
      );

  final SharedPreferencesWithCache _prefs;

  @override
  String? read(String key) => _prefs.getString(key);
  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

class MemoryStorage implements ProgressStorage {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// Hands out one [PuzzleProgress] per puzzle and saves changes to [storage],
/// and keeps each picture's best finished score (notifying when one changes).
///
/// Saves are debounced because dragging across the grid paints many cells in
/// quick succession.
class ProgressStore with ChangeNotifier {
  ProgressStore(this.storage, {this.saveDelay = const Duration(milliseconds: 400)});

  final ProgressStorage storage;
  final Duration saveDelay;
  final _progress = <String, PuzzleProgress>{};
  final _dirty = <String>{};
  Timer? _saveTimer;

  PuzzleProgress of(Puzzle puzzle) => _progress.putIfAbsent(puzzle.id, () {
        final (cells, score) = _load(puzzle);
        final progress = PuzzleProgress(puzzle, restored: cells, score: score);
        progress.addListener(() => _markDirty(puzzle.id));
        return progress;
      });

  /// The best score a finished run of [puzzle] reached on this device, or 0.
  int bestOf(Puzzle puzzle) => int.tryParse(storage.read(_bestKey(puzzle.id)) ?? '') ?? 0;

  /// Records a finished run; returns whether it beat the best score.
  Future<bool> recordFinish(PuzzleProgress progress) async {
    if (progress.score <= bestOf(progress.puzzle)) return false;
    await storage.write(_bestKey(progress.puzzle.id), '${progress.score}');
    notifyListeners();
    return true;
  }

  /// Writes any pending changes right away (e.g. when the app is backgrounded).
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final ids = _dirty.toList();
    _dirty.clear();
    for (final id in ids) {
      final progress = _progress[id]!;
      final key = _key(id);
      if (progress.isStarted) {
        await storage.write(
          key,
          '${progress.puzzle.fingerprint}:${base64Encode(progress.snapshot())}:${progress.score}',
        );
      } else {
        await storage.remove(key);
      }
    }
  }

  void _markDirty(String id) {
    _dirty.add(id);
    _saveTimer ??= Timer(saveDelay, flush);
  }

  /// `<fingerprint>:<cells in base64>:<score>`; saves from before scoring
  /// have no score part.
  (Uint8List?, int) _load(Puzzle puzzle) {
    if (storage.read(_key(puzzle.id))?.split(':')
        case [final fingerprint, final cells, ...final rest] when fingerprint == '${puzzle.fingerprint}') {
      try {
        return (base64Decode(cells), rest.isEmpty ? 0 : int.tryParse(rest.first) ?? 0);
      } on FormatException {
        return (null, 0);
      }
    }
    return (null, 0);
  }

  static String _key(String id) => 'progress_v1/$id';
  static String _bestKey(String id) => 'best_v1/$id';
}
