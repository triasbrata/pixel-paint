import 'audio/background_music.dart';
import 'audio/sound_effects.dart';
import 'game/leaderboard.dart';
import 'game/progress_store.dart';
import 'models/puzzle.dart';
import 'ui/ui_sprites.dart';

/// Everything the game needs, loaded before the first frame.
class GameData {
  const GameData({
    required this.puzzles,
    required this.store,
    required this.sprites,
    this.music,
    this.sounds,
    this.leaderboard = const NoLeaderboard(),
  });

  final List<Puzzle> puzzles;
  final ProgressStore store;
  final UiSprites sprites;
  final MusicController? music;
  final SoundEffects? sounds;
  final Leaderboard leaderboard;
}
