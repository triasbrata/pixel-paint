import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Button colors, in the order of the rows of `ui/buttons.png`.
enum UiColor { brown, white, green, blue, orange, red, purple, peach, grey }

/// Button outlines: cut corners, rounded square, pill.
enum UiShape { cut, square, round }

/// The three looks of a button: up, half pressed (hover), pressed.
enum Look { normal, hover, pressed }

/// Icons baked into the buttons of `ui/buttons.png`, by column group.
enum ButtonGlyph {
  pause(0),
  play(1),
  note(2),
  power(3),
  speaker(4),
  alert(5),
  home(6),
  help(7),
  down(8),
  up(9),
  refresh(30);

  const ButtonGlyph(this.column);

  final int column;
}

/// A 16-px icon of `ui/icons.png`, by column and row.
class IconRef {
  const IconRef(this.col, this.row);

  final int col;
  final int row;

  Rect get rect => Rect.fromLTWH(col * 16.0, row * 16.0, 16, 16);

  static const heart = IconRef(0, 0);
  static const star = IconRef(3, 0);
  static const coin = IconRef(6, 0);
  static const crown = IconRef(4, 1);
  static const trophy = IconRef(5, 1);
  static const gift = IconRef(8, 1);
  static const note = IconRef(9, 4);
  static const speaker = IconRef(10, 4);
  static const noteOff = IconRef(11, 4);
  static const speakerOff = IconRef(12, 4);
  static const check = IconRef(1, 6);
  static const checkSmall = IconRef(2, 6);
  static const cross = IconRef(10, 6);
  static const plus = IconRef(4, 2);
  static const minus = IconRef(7, 2);
  static const left = IconRef(7, 11);
  static const right = IconRef(10, 11);
  static const back = IconRef(7, 8);
  static const hand = IconRef(3, 14);
  static const arrow = IconRef(0, 14);
}

/// The pixel art of the UI, loaded once, with the rects of every piece used.
///
/// Rects were measured on the sheets (tool/import_ui_assets.py copies them).
class UiSprites {
  UiSprites._(this._images);

  static const _files = {
    'buttons': 'assets/ui/buttons.png',
    'buttonIcons': 'assets/ui/button_icons.png',
    'icons': 'assets/ui/icons.png',
    'book': 'assets/ui/book.png',
    'marks': 'assets/ui/book_marks.png',
    'ribbons': 'assets/ui/ribbons.png',
    'frames': 'assets/ui/frames.png',
    'bars': 'assets/ui/bars.png',
    'popUp': 'assets/ui/pop_up.png',
    'selectors': 'assets/ui/selectors.png',
    'crosshairs': 'assets/ui/crosshairs.png',
    'click': 'assets/ui/click.png',
    'loading': 'assets/ui/loading.png',
    'tools': 'assets/ui/tools.png',
    'slime': 'assets/sprites/slime.png',
    'sun': 'assets/sprites/sun.png',
    'balloon': 'assets/sprites/balloon.png',
    'birds1': 'assets/sprites/birds1.png',
    'birds2': 'assets/sprites/birds2.png',
    'cloud1': 'assets/sprites/cloud1.png',
    'cloud2': 'assets/sprites/cloud2.png',
    'cloud3': 'assets/sprites/cloud3.png',
    'cloud4': 'assets/sprites/cloud4.png',
    'cloud5': 'assets/sprites/cloud5.png',
    'cloud6': 'assets/sprites/cloud6.png',
  };

  static Future<UiSprites> load([AssetBundle? bundle]) async {
    Future<(String, ui.Image)> one(String name, String path) async {
      final data = await (bundle ?? rootBundle).load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (name, (await codec.getNextFrame()).image);
    }

    final loaded = await Future.wait([for (final MapEntry(:key, :value) in _files.entries) one(key, value)]);
    return UiSprites._({for (final (name, image) in loaded) name: image});
  }

  final Map<String, ui.Image> _images;

  ui.Image operator [](String name) => _images[name]!;

  ui.Image get buttons => this['buttons'];
  ui.Image get buttonIcons => this['buttonIcons'];
  ui.Image get icons => this['icons'];
  ui.Image get book => this['book'];
  ui.Image get marks => this['marks'];
  ui.Image get ribbons => this['ribbons'];
  ui.Image get frames => this['frames'];
  ui.Image get bars => this['bars'];
  ui.Image get popUp => this['popUp'];
  ui.Image get selectors => this['selectors'];
  ui.Image get crosshairs => this['crosshairs'];
  ui.Image get click => this['click'];
  ui.Image get loading => this['loading'];
  ui.Image get tools => this['tools'];
  ui.Image get slime => this['slime'];
  List<ui.Image> get clouds => [for (var i = 1; i <= 6; i++) this['cloud$i']];

  // --- Rects (art pixels) ------------------------------------------------------

  /// A 32x16 label button cell; the art is bottom-aligned so pressing sinks it.
  static Rect wideButton(UiColor color, UiShape shape, Look look) =>
      Rect.fromLTWH(32.0 * look.index, 16.0 * (color.index * 3 + shape.index), 32, 16);

  /// A 16x16 round/square button without a glyph.
  static Rect iconButton(UiColor color, UiShape shape, Look look) =>
      Rect.fromLTWH(96 + 16.0 * look.index, 16.0 * (color.index * 3 + shape.index), 16, 16);

  /// A 16x16 button with one of the baked glyphs.
  static Rect glyphButton(ButtonGlyph glyph, UiColor color, UiShape shape, Look look) =>
      Rect.fromLTWH(144 + 48.0 * glyph.column + 16 * look.index, 16.0 * (color.index * 3 + shape.index), 16, 16);

  /// A glyph alone (no button), from `ui/button_icons.png`; rows are colors,
  /// 1 is dark brown.
  static Rect glyphIcon(ButtonGlyph glyph, {int row = 1}) => Rect.fromLTWH(16.0 * glyph.column, 16.0 * row, 16, 16);

  /// An icon tile: a beveled slot of the frames sheet (rows by color as in
  /// [slot]). Up: raised (28x31); hover: raised and lit; pressed: sunk in
  /// (28x28, drawn three pixels lower).
  static Rect tile(int colorRow, Look look) => switch (look) {
        Look.normal => Rect.fromLTWH(10 + 48.0 * 3, 10 + 48.0 * colorRow, 28, 31),
        Look.hover => Rect.fromLTWH(10 + 48.0 * 7, 10 + 48.0 * colorRow, 28, 31),
        Look.pressed => Rect.fromLTWH(10 + 48.0 * 10, 10 + 48.0 * colorRow, 28, 28),
      };
  static const tileInsets = EdgeInsets.fromLTRB(6, 6, 6, 9);
  static const tileSunkInsets = EdgeInsets.fromLTRB(6, 6, 6, 6);

  /// Height of a raised tile's bottom bevel, in art pixels.
  static const tileBevel = 3.0;

  /// Frame-sheet row of a [UiColor].
  static int tileRow(UiColor color) => switch (color) {
        UiColor.brown || UiColor.peach => 0,
        UiColor.white || UiColor.grey => 1,
        UiColor.green => 2,
        UiColor.blue => 3,
        UiColor.orange => 4,
        UiColor.red => 5,
        UiColor.purple => 6,
      };

  /// Slices of the label buttons: corners stay, the middle stretches.
  static const wideInsets = EdgeInsets.fromLTRB(5, 4, 5, 5);

  /// The open book spread (240x144); x splits 31/96/143/208, y splits 31/112.
  static const bookRect = Rect.fromLTWH(0, 0, 240, 144);

  /// Bookmark flags (sheet order: red, blue, green, orange, peach, brown, white).
  static Rect flag(int color, {required bool out}) =>
      out ? Rect.fromLTWH(162 + 48.0 * color, 53, 28, 18) : Rect.fromLTWH(164 + 48.0 * color, 5, 22, 18);
  static const flagRed = 0, flagBlue = 1, flagGreen = 2, flagOrange = 3, flagPeach = 4, flagBrown = 5, flagWhite = 6;

  /// The flat ribbon banner (64x20); its ends stay, the middle stretches.
  static const ribbon = Rect.fromLTWH(8, 1, 64, 20);
  static const ribbonInsets = EdgeInsets.fromLTRB(16, 4, 16, 5);

  /// Parchment panel with a dotted border (32x32).
  static const parchment = Rect.fromLTWH(1064, 104, 32, 32);
  static const parchmentInsets = EdgeInsets.all(8);

  /// The item container (26x26): peach paper in a thin rim with studded
  /// corners, flat (no bevel), for things that are shown rather than pressed.
  static const container = Rect.fromLTWH(1067, 11, 26, 26);
  static const containerInsets = EdgeInsets.all(5);

  /// Beveled slots, 28x31, rows by color (0 brown, 1 white, 2 green, 3 blue,
  /// 4 orange, 5 red, 6 purple).
  static Rect slot(int colorRow) => Rect.fromLTWH(10, 10 + 48.0 * colorRow, 28, 31);
  static const slotInsets = EdgeInsets.fromLTRB(6, 6, 6, 8);

  /// The dark empty capsule used as a bar track (12x6).
  static const barTrack = Rect.fromLTWH(82, 33, 12, 6);
  static const barInsets = EdgeInsets.fromLTRB(3, 2, 3, 2);

  /// Speech bubble with a tail (22x26), for [Pix.slices]: the columns either
  /// side of the tail stretch and the tail (columns 9-12) keeps its shape in
  /// the middle; the rows between the top corners and the bottom curve stretch.
  static const bubble = Rect.fromLTWH(61, 13, 22, 26);
  static const bubbleXs = [5.0, 9.0, 13.0, 17.0];
  static const bubbleYs = [5.0, 17.0];

  /// Corner brackets that frame the selected swatch (27x29).
  static const selector = Rect.fromLTWH(107, 10, 27, 29);
  static const selectorInsets = EdgeInsets.fromLTRB(9, 10, 9, 10);

  /// The crosshair used for "find a cell".
  static const crosshair = Rect.fromLTWH(0, 0, 16, 16);

  /// Click sparkle: 4 frames of 16x16.
  static Rect clickFrame(int i) => Rect.fromLTWH(16.0 * i, 0, 16, 16);

  /// Loading dial: 16 frames of 16x16 in the first row.
  static Rect loadingFrame(int i) => Rect.fromLTWH(16.0 * (i % 16), 0, 16, 16);

  static const pencil = Rect.fromLTWH(0, 0, 16, 16);
  static const bucket = Rect.fromLTWH(16, 0, 16, 16);

  /// Slime frames: 44x28, rows idle (6), walk (6), attack (6), hurt (4).
  static const slimeFrame = Size(44, 28);
  static const slimeFrames = {'idle': 6, 'walk': 6, 'attack': 6, 'hurt': 4};
  static Rect slimeRect(String row, int frame) => Rect.fromLTWH(
        44.0 * frame,
        28.0 * const ['idle', 'walk', 'attack', 'hurt'].indexOf(row),
        44,
        28,
      );
}

/// Unsmoothed drawing of sheet pieces.
abstract final class Pix {
  static final paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  /// Draws [src] of [image] into [dst].
  static void sprite(Canvas canvas, ui.Image image, Rect src, Rect dst, {Paint? using}) =>
      canvas.drawImageRect(image, src, dst, using ?? paint);

  /// Nine-slice: the [insets] (art pixels) of [src] keep their size at [unit]
  /// logical px per art px; edges stretch along, the middle both ways.
  static void nine(Canvas canvas, ui.Image image, Rect src, Rect dst, EdgeInsets insets, double unit,
      {Paint? using}) {
    final p = using ?? paint;
    final sx = [src.left, src.left + insets.left, src.right - insets.right, src.right];
    final sy = [src.top, src.top + insets.top, src.bottom - insets.bottom, src.bottom];
    final dx = [dst.left, dst.left + insets.left * unit, dst.right - insets.right * unit, dst.right];
    final dy = [dst.top, dst.top + insets.top * unit, dst.bottom - insets.bottom * unit, dst.bottom];
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        if (sx[c + 1] <= sx[c] || sy[r + 1] <= sy[r] || dx[c + 1] <= dx[c] || dy[r + 1] <= dy[r]) continue;
        canvas.drawImageRect(
          image,
          Rect.fromLTRB(sx[c], sy[r], sx[c + 1], sy[r + 1]),
          Rect.fromLTRB(dx[c], dy[r], dx[c + 1], dy[r + 1]),
          p,
        );
      }
    }
  }

  /// Nine-slice with several stretch zones: [xs] / [ys] are the split lines
  /// (art pixels, inside [src]); even-numbered zones keep their size, odd ones
  /// share the leftover space. Used for the two-page book.
  static void slices(Canvas canvas, ui.Image image, Rect src, Rect dst, List<double> xs, List<double> ys,
      double unit) {
    List<(double, double, double, double)> zones(double s0, double s1, List<double> cuts, double d0, double d1) {
      final edges = [s0, ...cuts.map((c) => s0 + c), s1];
      final fixed = [for (var i = 0; i < edges.length - 1; i += 2) edges[i + 1] - edges[i]].fold(0.0, (a, b) => a + b);
      final stretchCount = (edges.length - 1) ~/ 2;
      final stretch = stretchCount == 0 ? 0.0 : ((d1 - d0) - fixed * unit) / stretchCount;
      final out = <(double, double, double, double)>[];
      var d = d0;
      for (var i = 0; i < edges.length - 1; i++) {
        final len = i.isEven ? (edges[i + 1] - edges[i]) * unit : stretch;
        out.add((edges[i], edges[i + 1], d, d + len));
        d += len;
      }
      return out;
    }

    for (final (sy0, sy1, dy0, dy1) in zones(src.top, src.bottom, ys, dst.top, dst.bottom)) {
      for (final (sx0, sx1, dx0, dx1) in zones(src.left, src.right, xs, dst.left, dst.right)) {
        if (dx1 <= dx0 || dy1 <= dy0) continue;
        canvas.drawImageRect(image, Rect.fromLTRB(sx0, sy0, sx1, sy1), Rect.fromLTRB(dx0, dy0, dx1, dy1), paint);
      }
    }
  }
}
