import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../ui/pixel_game.dart';
import '../ui/pixel_scale.dart';
import '../ui/pixel_text.dart';
import '../ui/ui_sprites.dart';

/// The slime that keeps the player company: it bobs, hops and cheers when a
/// combo climbs or a picture is done, flinches at a wrong color, says hi when
/// tapped, and scoots out of the way when the coloring page asks it to.
class Slime extends PositionComponent with TapCallbacks, HasGameReference<PixelGame> {
  Slime({this.greetings = const ['Hi!', 'Paint!', ':)']});

  final List<String> greetings;

  static const _fps = 8.0;
  static const _hopTime = 0.42;

  String _row = 'idle';
  double _rowTime = 0;
  int _hopsLeft = 0;
  double _hopT = -1;
  String? _speech;
  double _speechLeft = 0;
  int _greeting = 0;

  static const _moveTime = 0.28;

  Vector2 _from = Vector2.zero(), _to = Vector2.zero();
  double _moveT = -1;

  /// Size of the drawn frame for the current pixel scale.
  Vector2 get frameSize => Vector2(UiSprites.slimeFrame.width, UiSprites.slimeFrame.height) * game.scale.unit;

  /// Where the slime's body is in its frame (the rest is clear), in units.
  static const bodyInFrame = Rect.fromLTWH(6, 10, 26, 14);

  /// The body in this component's coordinates.
  Rect get body {
    final u = game.scale.unit;
    return Rect.fromLTWH(bodyInFrame.left * u, bodyInFrame.top * u, bodyInFrame.width * u, bodyInFrame.height * u);
  }

  bool get moving => _moveT >= 0;

  /// What the slime is saying right now, if anything.
  String? get speech => _speech;

  /// Scoots to [target] (its top-left) in a quick hop.
  void moveTo(Vector2 target) {
    _from = position.clone();
    _to = target.clone();
    _moveT = 0;
    _play('walk');
    hop();
  }

  /// Puts the slime at [target] at once.
  void place(Vector2 target) {
    _moveT = -1;
    position = target.clone();
  }

  @override
  bool containsLocalPoint(Vector2 point) => body.contains(point.toOffset());

  void hop([int times = 1]) {
    _hopsLeft = math.max(_hopsLeft, times);
    if (_hopT < 0) _hopT = 0;
  }

  void cheer([String? text]) {
    hop(2);
    if (text != null) say(text);
  }

  void oops() {
    _play('hurt');
    say('Oops!', seconds: 1.0);
  }

  void say(String text, {double seconds = 1.6}) {
    _speech = text;
    _speechLeft = seconds;
  }

  void _play(String row) {
    _row = row;
    _rowTime = 0;
  }

  @override
  void onTapUp(TapUpEvent event) {
    hop();
    say(greetings[_greeting++ % greetings.length]);
  }

  @override
  void update(double dt) {
    if (_moveT >= 0) {
      _moveT = math.min(_moveTime, _moveT + dt);
      final t = _moveT / _moveTime;
      position = _from + (_to - _from) * (1 - math.pow(1 - t, 3).toDouble());
      if (_moveT >= _moveTime) _moveT = -1;
    }
    _rowTime += dt;
    final frames = UiSprites.slimeFrames[_row]!;
    if (_row != 'idle' && _rowTime * _fps >= frames) _play('idle');
    if (_hopT >= 0) {
      _hopT += dt;
      if (_hopT >= _hopTime) {
        _hopsLeft--;
        _hopT = _hopsLeft > 0 ? 0 : -1;
      }
    }
    if (_speechLeft > 0) {
      _speechLeft -= dt;
      if (_speechLeft <= 0) _speech = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final s = game.scale;
    final u = s.unit;
    final frames = UiSprites.slimeFrames[_row]!;
    final frame = (_rowTime * _fps).floor() % frames;
    final lift = _hopT >= 0 ? math.sin(math.pi * _hopT / _hopTime) * 10 * u : 0.0;
    final w = UiSprites.slimeFrame.width * u, h = UiSprites.slimeFrame.height * u;
    final dst = s.snapRect(Rect.fromLTWH((size.x - w) / 2, size.y - h - lift, w, h));
    Pix.sprite(canvas, game.sprites.slime, UiSprites.slimeRect(_row, frame), dst);

    if (_speech case final text?) {
      final label = game.text.measure(text, TextLevel.normal, outline: false);
      // 14 fixed columns (corners and tail) and two equal stretches of whole pixels.
      final stretch = math.max(4.0, ((label.width - 4 * u) / (2 * u)).ceilToDouble());
      final bw = (14 + 2 * stretch) * u;
      final bh = 26 * u;
      // The bubble's tail points at the slime's head.
      final bubble = s.snapRect(Rect.fromLTWH(dst.center.dx - bw / 2 + 4 * u, dst.top - bh + 8 * u, bw, bh));
      Pix.slices(canvas, game.sprites.popUp, UiSprites.bubble, bubble, UiSprites.bubbleXs, UiSprites.bubbleYs, u);
      game.text.draw(canvas, text, bubble.center - Offset(0, 3 * u),
          color: PixelInk.outline, outline: null, anchor: TextAnchor.center);
    }
  }
}
