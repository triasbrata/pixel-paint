import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../game/progress_store.dart';

/// The game's short sounds.
abstract interface class Sounds {
  void click();

  /// One cell painted with the Pencil.
  void paint();

  /// A Fill landed.
  void fill();
  void comboUp();

  /// A high combo (every fifth multiplier): the slime's "wow!".
  void wow();
  void mistake();
  void finish();
}

/// No sound: tests, and when nothing could be loaded.
class SilentSounds implements Sounds {
  const SilentSounds();

  @override
  void click() {}
  @override
  void paint() {}
  @override
  void fill() {}
  @override
  void comboUp() {}
  @override
  void wow() {}
  @override
  void mistake() {}
  @override
  void finish() {}
}

/// Plays a named sound from `assets/sfx/<name>.wav`.
abstract interface class SoundBank {
  Future<void> play(String name, {double volume});
}

/// The owner's Path of Hero sounds, switched on and off on their own (the
/// choice is saved), next to the music's switch.
///
/// Fast play triggers a sound for every cell; each sound has a minimum gap,
/// and any two sounds are a little apart, so a quick drag or a burst of
/// combo levels reads as a rhythm instead of choking the audio.
class SoundEffects extends ChangeNotifier implements Sounds {
  SoundEffects(this._storage, {SoundBank? bank, DateTime Function()? now})
      : _bank = bank ?? PlayerSoundBank(),
        _now = now ?? clock.now {
    _enabled = _storage.read(_key) != 'off';
    if (_bank case final PlayerSoundBank players) unawaited(players.warmUp(_sounds.keys));
  }

  static const _key = 'settings/sfx';

  /// (file, volume, minimum gap since the same sound).
  static const _sounds = {
    'click': (0.5, Duration(milliseconds: 60)),
    'place': (0.35, Duration(milliseconds: 110)),
    'kill': (0.5, Duration(milliseconds: 120)),
    'magic': (0.45, Duration(milliseconds: 300)),
    'wow': (0.7, Duration(milliseconds: 1500)),
    'error': (0.4, Duration(milliseconds: 150)),
    'clear': (0.6, Duration(milliseconds: 800)),
  };

  /// Minimum gap between any two sounds.
  static const _anyGap = Duration(milliseconds: 40);

  final ProgressStorage _storage;
  final SoundBank _bank;
  final DateTime Function() _now;
  late bool _enabled;
  final _last = <String, DateTime>{};
  DateTime? _lastAny;

  bool get enabled => _enabled;

  void toggle() {
    _enabled = !_enabled;
    _storage.write(_key, _enabled ? 'on' : 'off');
    notifyListeners();
    if (_enabled) click();
  }

  @override
  void click() => _play('click');
  @override
  void paint() => _play('place');
  @override
  void fill() => _play('kill');
  // A level-up lands on the same tap as its paint sound: it skips the
  // any-gap (its own gap still keeps a burst of levels to one sparkle).
  @override
  void comboUp() => _play('magic', always: true);
  @override
  void wow() => _play('wow', always: true);
  @override
  void mistake() => _play('error');
  @override
  void finish() => _play('clear', always: true);

  void _play(String name, {bool always = false}) {
    if (!_enabled) return;
    final (volume, gap) = _sounds[name]!;
    final now = _now();
    final last = _last[name];
    if (last != null && now.difference(last) < gap) return;
    if (!always && _lastAny != null && now.difference(_lastAny!) < _anyGap) return;
    _last[name] = now;
    _lastAny = now;
    _bank.play(name, volume: volume).catchError((Object e) => debugPrint('Sound $name: $e'));
  }
}

/// A few low-latency players per sound, made once up front and used in
/// turn, so playing never has to create (and load) a player mid-game.
class PlayerSoundBank implements SoundBank {
  PlayerSoundBank({this.voices = 3});

  /// How many copies of one sound may overlap.
  final int voices;

  // Like the music: never take audio focus, follow the iOS silent switch.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  final _channels = <String, Future<List<AudioPlayer>>>{};
  final _next = <String, int>{};

  /// Loads [names] now, so the first play of each is instant too.
  Future<void> warmUp(Iterable<String> names) async {
    try {
      await Future.wait(names.map(_players));
    } on Object catch (e) {
      debugPrint('Sounds not loaded: $e');
    }
  }

  Future<List<AudioPlayer>> _players(String name) => _channels[name] ??= Future.wait([
        for (var i = 0; i < voices; i++) _player(name),
      ]);

  static Future<AudioPlayer> _player(String name) async {
    final player = AudioPlayer();
    await player.setAudioContext(_context);
    await player.setPlayerMode(PlayerMode.lowLatency);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource('sfx/$name.wav'));
    return player;
  }

  @override
  Future<void> play(String name, {double volume = 1}) async {
    final players = await _players(name);
    final i = _next[name] = ((_next[name] ?? -1) + 1) % players.length;
    final player = players[i];
    await player.stop();
    await player.setVolume(volume);
    await player.resume();
  }
}
