import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../game/progress_store.dart';

/// Plays and pauses one looping track; swapped for a fake in tests.
abstract interface class MusicPlayer {
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
}

class AssetMusicPlayer implements MusicPlayer {
  AssetMusicPlayer(this.asset, {this.volume = 0.35});

  /// Path under `assets/`, e.g. `music/paint_party.mp3`.
  final String asset;
  final double volume;
  AudioPlayer? _player;

  // Background music is optional: follow the iOS silent switch and let the
  // player's own music or podcast keep playing alongside it.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.music,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  Future<AudioPlayer> _ensurePlayer() async {
    if (_player case final player?) return player;
    final player = AudioPlayer(playerId: 'background_music');
    await player.setAudioContext(_context);
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(volume);
    await player.setSource(AssetSource(asset));
    return _player = player;
  }

  @override
  Future<void> play() async => (await _ensurePlayer()).resume();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> dispose() async => _player?.dispose();
}

/// Whether background music is on (saved), and keeping the player in sync
/// with that and with the app being in the foreground.
class MusicController extends ChangeNotifier {
  MusicController(this._player, this._storage) : _enabled = _storage.read(_key) != 'off';

  static const _key = 'settings/music';

  final MusicPlayer _player;
  final ProgressStorage _storage;
  bool _enabled;
  bool _foreground = true;

  /// Browsers refuse to start audio before the first tap or click.
  bool _unlocked = !kIsWeb;

  bool get enabled => _enabled;

  void toggle() {
    _enabled = !_enabled;
    _storage.write(_key, _enabled ? 'on' : 'off');
    notifyListeners();
    _sync();
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _sync();
  }

  /// Call on any pointer down; starts the music on the web once allowed.
  void userInteracted() {
    if (_unlocked) return;
    _unlocked = true;
    _sync();
  }

  Future<void> start() => _sync();

  Future<void> _sync() async {
    if (!_unlocked) return;
    try {
      if (_enabled && _foreground) {
        await _player.play();
      } else {
        await _player.pause();
      }
    } catch (e) {
      // Music is a nice-to-have; never let a missing codec or audio device
      // break the game.
      debugPrint('Background music unavailable: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
