import 'dart:convert';

import 'package:color_by_number/src/game/leaderboard.dart';
import 'package:color_by_number/src/game/play_games_leaderboard.dart';
import 'package:color_by_number/src/game/progress_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Serves one config file as the leaderboard asset.
class _ConfigBundle extends CachingAssetBundle {
  _ConfigBundle(this.config);

  final Object config;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(jsonEncode(config)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only pictures in the config get an online board', () async {
    final leaderboard = await PlayGamesLeaderboard.load(
      MemoryStorage(),
      bundle: _ConfigBundle({
        'app_id': '123456789012',
        'leaderboards': {'tiny': 'CgkIexample'},
      }),
    );
    expect(leaderboard, isA<PlayGamesLeaderboard>());
    expect(leaderboard.has(tinyPuzzle()), isTrue);
    expect(leaderboard.has(regionsPuzzle()), isFalse);
  });

  test('without configured boards there is no online leaderboard', () async {
    final empty = await PlayGamesLeaderboard.load(
      MemoryStorage(),
      bundle: _ConfigBundle({'app_id': '', 'leaderboards': {}}),
    );
    expect(empty, isA<NoLeaderboard>());
  });

  test('a score finished while signed out waits for the next sign-in', () async {
    final storage = MemoryStorage();
    final leaderboard = PlayGamesLeaderboard({'tiny': 'CgkIexample'}, storage);
    await leaderboard.submit(tinyPuzzle(), 500);
    await leaderboard.submit(tinyPuzzle(), 300);
    expect(storage.values['leaderboard_waiting_v1/tiny'], '500', reason: 'the better one is kept');
  });
}
