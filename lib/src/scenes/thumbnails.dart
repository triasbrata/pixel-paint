import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../game/puzzle_progress.dart';
import '../ui/pixel_scale.dart';
import '../ui/ui_sprites.dart';

/// Each picture as a tiny image, one pixel per cell: painted cells in their
/// color, the rest in their gray shade. Redrawn only after the picture
/// changes; scaled up without smoothing it stays crisp pixel art.
class Thumbnails {
  final _images = <PuzzleProgress, ui.Image>{};
  final _stale = <PuzzleProgress>{};

  ui.Image of(PuzzleProgress progress) {
    final cached = _images[progress];
    if (cached != null && !_stale.contains(progress)) return cached;
    if (cached == null) progress.addListener(() => _stale.add(progress));
    _stale.remove(progress);
    cached?.dispose();
    return _images[progress] = _render(progress);
  }

  /// Draws [progress] centered in [box], at a whole number of device pixels
  /// per cell when it fits; returns where it went.
  Rect draw(Canvas canvas, PuzzleProgress progress, Rect box, PixelScale scale, {Paint? paint}) {
    final image = of(progress);
    final w = image.width, h = image.height;
    final dpr = scale.devicePixelRatio;
    var cell = math.min(box.width / w, box.height / h);
    final device = (cell * dpr).floorToDouble();
    if (device >= 1) cell = device / dpr;
    final dst = scale.snapRect(Rect.fromCenter(center: box.center, width: w * cell, height: h * cell));
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), dst, paint ?? Pix.paint);
    return dst;
  }

  static ui.Image _render(PuzzleProgress progress) {
    final puzzle = progress.puzzle;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fill = Paint()..isAntiAlias = false;
    Color? colorAt(int i) {
      final target = puzzle.cells[i];
      if (target == 0) return null;
      final entry = puzzle.entry(target);
      return progress.paintedAt(i) == target ? entry.color : entry.shade;
    }

    // Same-color runs as one rect: the big scenes have thousands of cells.
    for (var y = 0; y < puzzle.height; y++) {
      var start = 0;
      Color? run;
      for (var x = 0; x <= puzzle.width; x++) {
        final color = x < puzzle.width ? colorAt(y * puzzle.width + x) : null;
        if (x < puzzle.width && color == run) continue;
        if (run != null) {
          canvas.drawRect(Rect.fromLTWH(start.toDouble(), y.toDouble(), (x - start).toDouble(), 1), fill..color = run);
        }
        start = x;
        run = color;
      }
    }
    return recorder.endRecording().toImageSync(puzzle.width, puzzle.height);
  }
}
