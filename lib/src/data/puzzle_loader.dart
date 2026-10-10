import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../models/puzzle.dart';

const puzzleAssetDir = 'assets/puzzles/';

/// Loads every PNG under [puzzleAssetDir] as a puzzle, easiest first.
Future<List<Puzzle>> loadBundledPuzzles([AssetBundle? bundle]) async {
  bundle ??= rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final paths = manifest
      .listAssets()
      .where((p) => p.startsWith(puzzleAssetDir) && p.toLowerCase().endsWith('.png'))
      .toList();

  final puzzles = await Future.wait(paths.map((p) => loadPuzzleAsset(p, bundle)));
  puzzles.sort((a, b) {
    final byDifficulty = a.difficulty.index.compareTo(b.difficulty.index);
    if (byDifficulty != 0) return byDifficulty;
    final byColors = a.palette.length.compareTo(b.palette.length);
    return byColors != 0 ? byColors : a.name.compareTo(b.name);
  });
  return puzzles;
}

Future<Puzzle> loadPuzzleAsset(String path, [AssetBundle? bundle]) async {
  final data = await (bundle ?? rootBundle).load(path);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final id = path.substring(puzzleAssetDir.length, path.length - '.png'.length);
    return Puzzle.fromRgba(
      id: id,
      name: titleFromId(id),
      width: image.width,
      height: image.height,
      rgba: bytes!.buffer.asUint8List(),
    );
  } finally {
    image.dispose();
  }
}

/// `blue_gems` → `Blue Gems`.
String titleFromId(String id) => id
    .split(RegExp(r'[_\-\s/]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');
