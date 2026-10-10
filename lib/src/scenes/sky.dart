import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../ui/pixel_game.dart';
import '../ui/ui_sprites.dart';

/// The pastel sky behind every screen: a stepped gradient, the sun, clouds
/// drifting by, a hot air balloon, now and then a flock of birds, and pixel
/// hills with flowers along the bottom.
///
/// The far things are drawn at half the UI's pixel size, so they read as
/// distant.
class SkyBackdrop extends Component with HasGameReference<PixelGame> {
  SkyBackdrop() : super(priority: -100);

  static const _top = Color(0xFFA9DCF8);
  static const _bottom = Color(0xFFF8E4F2);
  static const _hillBack = Color(0xFFC3EBB1);
  static const _hillFront = Color(0xFFA5DD93);
  static const _hillEdge = Color(0xFF86C77A);
  static const _flowers = [Color(0xFFFFFFFF), Color(0xFFFFB7D5), Color(0xFFFFE27A)];

  /// (cloud index, height as a share of the sky, drift in art px/s, offset).
  static const _clouds = [
    (5, 0.08, 2.0, 0.1),
    (3, 0.22, 3.5, 0.55),
    (1, 0.14, 5.0, 0.8),
    (4, 0.34, 2.6, 0.3),
    (0, 0.28, 6.0, 0.05),
    (2, 0.42, 4.2, 0.7),
  ];

  Picture? _ground;
  Size? _groundFor;

  @override
  void render(Canvas canvas) {
    final size = Size(game.size.x, game.size.y);
    final s = game.scale;
    final half = s.half;
    _gradient(canvas, size, s.unit);

    final sprites = game.sprites;
    final sun = sprites['sun'];
    Pix.sprite(canvas, sun, Rect.fromLTWH(0, 0, sun.width.toDouble(), sun.height.toDouble()),
        s.snapRect(Rect.fromLTWH(size.width * 0.3, size.height * 0.06, sun.width * half, sun.height * half)));

    final clouds = sprites.clouds;
    for (final (i, y, speed, offset) in _clouds) {
      final cloud = clouds[i];
      final w = cloud.width * half, h = cloud.height * half;
      final span = size.width + w;
      final x = (offset * span + game.time * speed * half) % span - w;
      Pix.sprite(canvas, cloud, Rect.fromLTWH(0, 0, cloud.width.toDouble(), cloud.height.toDouble()),
          s.snapRect(Rect.fromLTWH(x, size.height * y, w, h)));
    }

    final balloon = sprites['balloon'];
    final bw = balloon.width * half * 2, bh = balloon.height * half * 2;
    final bx = size.width * 0.82 + math.sin(game.time * 0.15) * size.width * 0.05;
    final by = size.height * 0.18 + math.sin(game.time * 0.9) * s.unit * 2;
    Pix.sprite(canvas, balloon, Rect.fromLTWH(0, 0, balloon.width.toDouble(), balloon.height.toDouble()),
        s.snapRect(Rect.fromLTWH(bx, by, bw, bh)));

    // A flock crosses every 14 s.
    final t = game.time % 14;
    if (t < 9) {
      final birds = sprites[(game.time ~/ 14).isEven ? 'birds1' : 'birds2'];
      final x = -birds.width * half * 2 + t / 9 * (size.width + birds.width * half * 4);
      final y = size.height * 0.12 + math.sin(t * 2) * s.unit;
      Pix.sprite(canvas, birds, Rect.fromLTWH(0, 0, birds.width.toDouble(), birds.height.toDouble()),
          s.snapRect(Rect.fromLTWH(x, y, birds.width * half * 2, birds.height * half * 2)));
    }

    if (_groundFor != size || _ground == null) {
      _ground = _recordGround(size, s.unit);
      _groundFor = size;
    }
    canvas.drawPicture(_ground!);
  }

  /// Bands of color a few art pixels tall, like a palette-limited sky.
  void _gradient(Canvas canvas, Size size, double unit) {
    const bands = 14;
    final h = size.height / bands;
    final paint = Paint();
    for (var i = 0; i < bands; i++) {
      paint.color = Color.lerp(_top, _bottom, i / (bands - 1))!;
      canvas.drawRect(Rect.fromLTWH(0, (i * h / unit).floor() * unit, size.width, h + unit), paint);
    }
  }

  /// Two rolling hills drawn column by column in art pixels, with flowers.
  Picture _recordGround(Size size, double unit) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final cols = (size.width / unit).ceil() + 1;
    final base = size.height;
    double hill(int x, double height, double wave, double phase) =>
        height + math.sin(x / wave + phase) * height * 0.25 + math.sin(x / (wave * 0.37) + phase * 2) * height * 0.08;

    void layer(double height, double wave, double phase, Color fill, {bool flowers = false}) {
      final paint = Paint()..color = fill;
      final edge = Paint()..color = _hillEdge;
      final random = math.Random(phase.round());
      for (var x = 0; x < cols; x++) {
        final top = (base / unit - hill(x, height, wave, phase)).floorToDouble() * unit;
        canvas.drawRect(Rect.fromLTRB(x * unit, top, (x + 1) * unit, base), paint);
        canvas.drawRect(Rect.fromLTWH(x * unit, top, unit, unit), edge);
        if (flowers && random.nextDouble() < 0.12) {
          final fy = top + unit * (2 + random.nextInt(6));
          canvas.drawRect(Rect.fromLTWH(x * unit, fy, unit, unit),
              Paint()..color = _flowers[random.nextInt(_flowers.length)]);
        }
      }
    }

    final h = size.height / unit;
    layer(h * 0.13, 22, 1, _hillBack);
    layer(h * 0.08, 15, 4, _hillFront, flowers: true);
    return recorder.endRecording();
  }
}
