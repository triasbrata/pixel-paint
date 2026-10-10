import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/background_music.dart';
import 'audio/sound_effects.dart';
import 'data/puzzle_loader.dart';
import 'game/play_games_leaderboard.dart';
import 'game/progress_store.dart';
import 'game_data.dart';
import 'scenes/paint_book_game.dart';
import 'ui/ui_sprites.dart';

export 'game_data.dart';

Future<GameData> loadGameData() async {
  final (puzzles, storage, sprites) = await (
    loadBundledPuzzles(),
    SharedPrefsStorage.open(),
    UiSprites.load(),
  ).wait;
  return GameData(
    puzzles: puzzles,
    store: ProgressStore(storage),
    sprites: sprites,
    music: MusicController(AssetMusicPlayer('music/paint_party.mp3'), storage),
    sounds: SoundEffects(storage),
    leaderboard: await PlayGamesLeaderboard.load(storage),
  );
}

/// Loads everything, then runs the game. The whole UI is the Flame game; this
/// widget only hosts it, feeds it raw pointers (painting needs every finger)
/// and follows the app's lifecycle.
class PixelPaintApp extends StatefulWidget {
  const PixelPaintApp({super.key, this.load = loadGameData});

  final Future<GameData> Function() load;

  @override
  State<PixelPaintApp> createState() => _PixelPaintAppState();
}

class _PixelPaintAppState extends State<PixelPaintApp> {
  late final Future<GameData> _data = widget.load();
  late final AppLifecycleListener _lifecycle;
  GameData? _loaded;
  PaintBookGame? _game;

  @override
  void initState() {
    super.initState();
    _data.then((data) {
      if (mounted) setState(() => _loaded = data);
      data.music?.start();
    }, onError: (_) {});
    _lifecycle = AppLifecycleListener(
      // Save right away when the app is backgrounded; it may never come back.
      onInactive: () => _loaded?.store.flush(),
      onHide: () => _loaded?.music?.setForeground(false),
      onShow: () => _loaded?.music?.setForeground(true),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _loaded?.music?.dispose();
    super.dispose();
  }

  void _pointer(PointerEvent event) {
    if (event is PointerDownEvent) _loaded?.music?.userInteracted();
    _game?.onRawPointer(event);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel Paint',
      debugShowCheckedModeBanner: false,
      color: const Color(0xFFCFEFFF),
      home: FutureBuilder<GameData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ColoredBox(
              color: const Color(0xFFCFEFFF),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load the game:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'PohSans', fontSize: 22),
                  ),
                ),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) return const ColoredBox(color: Color(0xFFCFEFFF));
          // The sky's top color shows behind the status bar; the game stays
          // clear of it (and of side cutouts) but runs to the bottom edge,
          // under the gesture bar. Pointers are read inside the safe area so
          // they match the game's coordinates.
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !(_game?.back() ?? false)) SystemNavigator.pop();
            },
            child: ColoredBox(
              color: const Color(0xFFA9DCF8),
              child: SafeArea(
                bottom: false,
                child: Listener(
                  onPointerDown: _pointer,
                  onPointerMove: _pointer,
                  onPointerUp: _pointer,
                  onPointerCancel: _pointer,
                  onPointerSignal: _pointer,
                  onPointerPanZoomStart: _pointer,
                  onPointerPanZoomUpdate: _pointer,
                  child: GameWidget(game: _game ??= PaintBookGame(data)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
