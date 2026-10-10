import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';

import '../models/puzzle.dart';
import 'leaderboard.dart';
import 'progress_store.dart';

/// Google Play Games leaderboards (Android), one per picture.
///
/// Board IDs come from `assets/config/leaderboards.json`, which
/// `tool/import_games_ids.py` makes from the Play Console export; pictures
/// without one have no online board. Signing in is never forced, since the
/// game must be fully playable without a Google account (children play it
/// too): the player signs in by opening a leaderboard. A score finished while
/// signed out waits in [storage] and goes up after the next sign-in.
class PlayGamesLeaderboard implements Leaderboard {
  PlayGamesLeaderboard(this._ids, this._storage);

  static const configAsset = 'assets/config/leaderboards.json';

  /// The leaderboards for this platform: Play Games on Android when some board
  /// is configured, otherwise none.
  static Future<Leaderboard> load(ProgressStorage storage, {AssetBundle? bundle}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return const NoLeaderboard();
    final Map<String, String> ids;
    try {
      final json = jsonDecode(await (bundle ?? rootBundle).loadString(configAsset)) as Map<String, dynamic>;
      ids = (json['leaderboards'] as Map<String, dynamic>? ?? const {}).cast<String, String>();
    } on Object catch (e) {
      debugPrint('No leaderboard config: $e');
      return const NoLeaderboard();
    }
    if (ids.isEmpty) return const NoLeaderboard();
    final leaderboard = PlayGamesLeaderboard(ids, storage);
    // Play Games signs returning players in by itself; send anything waiting.
    unawaited(_signedIn().then((yes) => yes ? leaderboard._sendWaiting() : null));
    return leaderboard;
  }

  final Map<String, String> _ids;
  final ProgressStorage _storage;

  @override
  bool has(Puzzle puzzle) => _ids.containsKey(puzzle.id);

  @override
  Future<void> submit(Puzzle puzzle, int score) async {
    if (!has(puzzle)) return;
    await _wait(puzzle.id, score);
    if (await _signedIn()) await _sendWaiting();
  }

  @override
  Future<bool> show(Puzzle puzzle) async {
    final id = _ids[puzzle.id];
    if (id == null) return false;
    try {
      if (!await _signedIn()) {
        await GameAuth.signIn(); // the player asked for it
        if (!await _signedIn()) return false;
      }
      await _sendWaiting();
      await Leaderboards.showLeaderboards(androidLeaderboardID: id);
      return true;
    } on PlatformException catch (e) {
      debugPrint('Play Games: ${e.code} ${e.message}');
      return false;
    }
  }

  /// Keeps the best unsent score of a picture.
  Future<void> _wait(String puzzleId, int score) async {
    final key = _waitingKey(puzzleId);
    if (score > (int.tryParse(_storage.read(key) ?? '') ?? 0)) await _storage.write(key, '$score');
  }

  Future<void> _sendWaiting() async {
    for (final MapEntry(key: puzzleId, value: boardId) in _ids.entries) {
      final key = _waitingKey(puzzleId);
      final score = int.tryParse(_storage.read(key) ?? '');
      if (score == null) continue;
      try {
        await Leaderboards.submitScore(score: Score(androidLeaderboardID: boardId, value: score));
        await _storage.remove(key);
      } on PlatformException catch (e) {
        debugPrint('Play Games: score for $puzzleId not sent (${e.code}), will retry');
        return;
      }
    }
  }

  /// Whether a player is signed in; false when Play Games doesn't answer.
  static Future<bool> _signedIn() async {
    try {
      return await GameAuth.isSignedIn.timeout(const Duration(seconds: 5), onTimeout: () => false);
    } on Object {
      return false;
    }
  }

  static String _waitingKey(String puzzleId) => 'leaderboard_waiting_v1/$puzzleId';
}
