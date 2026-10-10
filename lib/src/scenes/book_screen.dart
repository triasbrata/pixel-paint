import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../game/puzzle_progress.dart';
import '../game/score_keeper.dart';
import '../models/difficulty.dart';
import '../models/puzzle.dart';
import '../ui/pixel_button.dart';
import '../ui/pixel_scale.dart';
import '../ui/pixel_text.dart';
import '../ui/ui_sprites.dart';
import 'mascot.dart';
import 'paint_book_game.dart';

/// The home screen: an open book of pictures. Bookmarks pick the difficulty;
/// tap a picture to paint it, flip pages with the arrows or a swipe.
///
/// Wide screens get the two-page spread; narrow ones one page, with the
/// book's frame at half the pixel size so two columns of pictures fit.
class BookScreen extends Screen with TapCallbacks, DragCallbacks {
  static const tabs = Difficulty.values;
  static const _flagColors = {
    Difficulty.easy: UiSprites.flagGreen,
    Difficulty.medium: UiSprites.flagBlue,
    Difficulty.hard: UiSprites.flagOrange,
    Difficulty.expert: UiSprites.flagRed,
  };

  late final PixelButton _prev = PixelButton(icon: IconRef.left, onTap: () => flip(-1));
  late final PixelButton _next = PixelButton(icon: IconRef.right, onTap: () => flip(1));
  late final PixelButton _music = PixelButton(icon: IconRef.note, onTap: _toggleMusic);
  late final PixelButton _sounds = PixelButton(icon: IconRef.speaker, onTap: _toggleSounds);
  late final Slime _slime = Slime(greetings: const ['Hi!', 'Pick one!', 'Yay!']);

  // Layout, in logical pixels.
  Rect _book = Rect.zero;
  Rect _ribbon = Rect.zero;
  bool _twoPages = false;
  double _bu = 1; // the book's pixel size
  final _pages = <Rect>[];
  final _flags = <(Rect, Difficulty)>[];
  int _perPage = 1;

  /// Page-turn animation: starts at ±1 and eases to 0.
  double _turn = 0;
  double _drag = 0;

  List<Puzzle> get _puzzles => [for (final p in game.data.puzzles) if (p.difficulty == game.bookTab) p];
  int get _pagesShown => _twoPages ? 2 : 1;
  int get spreads => math.max(1, (_puzzles.length / (_perPage * _pagesShown)).ceil());

  /// Each row of the open spread's lists, its picture at the left (for taps
  /// and tests).
  final slots = <(Rect, PuzzleProgress)>[];

  /// Where each bookmark is.
  List<(Rect, Difficulty)> get flags => _flags;

  @override
  Future<void> onLoad() async {
    final music = game.data.music;
    if (music != null) {
      _music.icon = music.enabled ? IconRef.note : IconRef.noteOff;
      add(_music);
    }
    if (game.data.sounds case final sounds?) {
      _sounds.icon = sounds.enabled ? IconRef.speaker : IconRef.speakerOff;
      add(_sounds);
    }
    addAll([_prev, _next, _slime]);
  }

  void _toggleMusic() {
    final music = game.data.music!..toggle();
    _music.icon = music.enabled ? IconRef.note : IconRef.noteOff;
  }

  void _toggleSounds() {
    final sounds = game.data.sounds!..toggle();
    _sounds.icon = sounds.enabled ? IconRef.speaker : IconRef.speakerOff;
  }

  void selectTab(Difficulty tab) {
    if (tab == game.bookTab) return;
    game.bookTab = tab;
    game.bookSpread = 0;
    _turn = 0.6;
    layout();
  }

  void flip(int by) {
    final next = (game.bookSpread + by).clamp(0, spreads - 1);
    if (next == game.bookSpread) return;
    game.bookSpread = next;
    _turn = by.sign.toDouble();
    layout();
  }

  @override
  void layout() {
    final s = game.scale, u = s.unit;
    final w = size.x, h = size.y;
    final narrow = w / u < 200;
    _bu = narrow ? s.half : u;
    _twoPages = !narrow && w > h * 1.15;

    // Title ribbon, music and sound switches.
    final titleLevel = narrow ? TextLevel.large : TextLevel.title;
    final titleSize = game.text.measure('Pixel Paint', titleLevel);
    final ribbonW = titleSize.width + 36 * u;
    _ribbon = s.snapRect(narrow
        ? Rect.fromLTWH(4 * u, 4 * u, ribbonW, 20 * u)
        : Rect.fromCenter(center: Offset(w / 2, 14 * u), width: ribbonW, height: 20 * u));
    var x = w - 4 * u;
    for (final button in [_sounds, _music]) {
      if (!button.isMounted && button.parent == null) continue;
      x -= 16 * u;
      button
        ..position = Vector2(s.snap(x), s.snap(6 * u))
        ..size = Vector2.all(16 * u);
      x -= 2 * u;
    }

    // The book, with room for the bookmarks on its right and the page
    // arrows under it.
    final flagRoom = 22 * _bu;
    var book = Rect.fromLTRB(4 * u, 28 * u, w - 4 * u - flagRoom, h - 22 * u);
    if (_twoPages && book.width > book.height * 2.3) {
      book = Rect.fromCenter(center: book.center, width: book.height * 2.3, height: book.height);
    }
    _book = s.snapRect(book);
    // Content stays well inside each page's dotted border: the border sits
    // about 16 px from the cover's outer edge, 11 from the top, 17 from the
    // bottom and 7 from the spine's middle; add a margin on top of that.
    final b = _bu;
    final top = _book.top + 18 * b, bottom = _book.bottom - 24 * b;
    _pages.clear();
    if (_twoPages) {
      final stretch = (_book.width - (31 + 47 + 32) * b) / 2;
      final spine = _book.left + 31 * b + stretch + 23.5 * b;
      _pages
        ..add(Rect.fromLTRB(_book.left + 24 * b, top, spine - 15 * b, bottom))
        ..add(Rect.fromLTRB(spine + 15 * b, top, _book.right - 24 * b, bottom));
    } else {
      // One page: the spine's middle is the book's left edge.
      _pages.add(Rect.fromLTRB(_book.left + 15 * b, top, _book.right - 24 * b, bottom));
    }

    // Bookmarks along the right edge, tucked under the cover.
    _flags.clear();
    for (final (i, tab) in tabs.indexed) {
      final out = tab == game.bookTab;
      final src = UiSprites.flag(_flagColors[tab]!, out: out);
      _flags.add((
        s.snapRect(Rect.fromLTWH(_book.right - 8 * b, _book.top + (16 + i * 21) * b, src.width * b, src.height * b)),
        tab,
      ));
    }

    // A list a page, one picture a row with its name, best score and
    // progress beside it: as many rows as fit, 2 to 4.
    final page = _pages.first;
    final header = 22 * u, gap = 5 * u;
    final roomH = page.height - header;
    _perPage = ((roomH + gap) / (40 * u + gap)).floor().clamp(2, 4);
    final rowH = math.min(56 * u, (roomH - gap * (_perPage - 1)) / _perPage).floorToDouble();
    game.bookSpread = game.bookSpread.clamp(0, spreads - 1);

    slots.clear();
    final puzzles = _puzzles;
    final first = game.bookSpread * _perPage * _pagesShown;
    for (final (p, pageRect) in _pages.indexed) {
      final start = first + p * _perPage;
      final shown = math.max(0, math.min(_perPage, puzzles.length - start));
      for (var k = 0; k < shown; k++) {
        final rect = Rect.fromLTWH(pageRect.left, pageRect.top + header + k * (rowH + gap), pageRect.width, rowH);
        slots.add((s.snapRect(rect), game.data.store.of(puzzles[start + k])));
      }
    }

    // Page arrows and the slime.
    final arrowsY = _book.bottom + 3 * u;
    final many = spreads > 1;
    _prev
      ..position = Vector2(s.snap(_book.center.dx - 34 * u), s.snap(arrowsY))
      ..size = Vector2.all(16 * u)
      ..visible = many
      ..enabled = game.bookSpread > 0;
    _next
      ..position = Vector2(s.snap(_book.center.dx + 18 * u), s.snap(arrowsY))
      ..size = Vector2.all(16 * u)
      ..visible = many
      ..enabled = game.bookSpread < spreads - 1;
    // The slime's body sits in the left part of its frame.
    _slime
      ..size = _slime.frameSize
      ..position = Vector2(s.snap(-6 * u), s.snap(h - _slime.frameSize.y - u));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_turn != 0) {
      final step = dt * 5;
      _turn = _turn.abs() <= step ? 0 : _turn - step * _turn.sign;
    }
  }

  // --- Input -----------------------------------------------------------------

  @override
  void onTapUp(TapUpEvent event) {
    final p = event.localPosition.toOffset();
    for (final (rect, tab) in _flags) {
      if (rect.contains(p)) {
        game.sounds.click();
        selectTab(tab);
        return;
      }
    }
    for (final (rect, progress) in slots) {
      if (rect.inflate(game.scale.unit * 2).contains(p)) {
        game.sounds.click();
        game.openPuzzle(progress.puzzle);
        return;
      }
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _drag = 0;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => _drag += event.localDelta.x;

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_drag.abs() > 30 * game.scale.unit) flip(_drag < 0 ? 1 : -1);
  }

  // --- Drawing ---------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    final s = game.scale, u = s.unit, sp = game.sprites;

    for (final (rect, tab) in _flags) {
      Pix.sprite(canvas, sp.marks, UiSprites.flag(_flagColors[tab]!, out: tab == game.bookTab), rect);
    }
    if (_twoPages) {
      Pix.slices(canvas, sp.book, UiSprites.bookRect, _book, const [31, 96, 143, 208], const [31, 112], _bu);
    } else {
      // One page: the right half of the spread, spine on the left.
      Pix.slices(canvas, sp.book, const Rect.fromLTWH(120, 0, 120, 144), _book, const [23, 88], const [31, 112], _bu);
    }

    Pix.nine(canvas, sp.ribbons, UiSprites.ribbon, _ribbon, UiSprites.ribbonInsets, u);
    game.text.draw(canvas, 'Pixel Paint', _ribbon.center - Offset(0, 2 * u),
        level: _ribbon.width < 110 * u ? TextLevel.large : TextLevel.title, anchor: TextAnchor.center);

    // The pages turn: content slides and fades in.
    final shift = _turn * 24 * u;
    final fade = 1 - _turn.abs().clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(s.snap(shift), 0);
    _header(canvas, fade);
    for (final (rect, progress) in slots) {
      _slot(canvas, rect, progress, fade);
    }
    canvas.restore();

    if (spreads > 1) {
      game.text.draw(canvas, '${game.bookSpread + 1}/$spreads', Offset(_book.center.dx, _book.bottom + 11 * u),
          level: TextLevel.normal, anchor: TextAnchor.center);
    }
  }

  void _header(Canvas canvas, double opacity) {
    final u = game.scale.unit;
    final page = _pages.first;
    final tab = game.bookTab;
    game.text.draw(canvas, tab.label, Offset(page.left, page.top + 2 * u),
        level: TextLevel.large, color: PixelInk.darkBrown, outline: null, opacity: opacity);
    final progresses = [for (final p in _puzzles) game.data.store.of(p)];
    final done = progresses.where((p) => p.isComplete).length;
    final right = (_twoPages ? _pages.last : page).right;
    final count = game.text.draw(canvas, '$done/${progresses.length}', Offset(right, page.top + 4 * u),
        level: TextLevel.normal, color: PixelInk.darkBrown, outline: null, anchor: TextAnchor.centerRight, opacity: opacity);
    Pix.sprite(canvas, game.sprites.icons, IconRef.checkSmall.rect,
        game.scale.snapRect(Rect.fromLTWH(count.left - 9 * u, count.center.dy - 4 * u, 8 * u, 8 * u)));
    game.text.draw(canvas, tab.description, Offset(page.left, page.top + 12 * u),
        level: TextLevel.small, color: PixelInk.brown, outline: null, opacity: opacity);
  }

  /// One row: the picture in its container, then its name, the best score
  /// (a star) and how far it is (done, a progress bar, or new).
  void _slot(Canvas canvas, Rect row, PuzzleProgress progress, double opacity) {
    final s = game.scale, u = s.unit, sp = game.sprites;
    final paint = opacity < 1 ? (Paint()..color = Color.fromRGBO(0, 0, 0, opacity)) : null;
    if (paint != null) canvas.saveLayer(row.inflate(4 * u), paint);
    final thumb = Rect.fromLTWH(row.left, row.top, row.height, row.height);
    Pix.nine(canvas, sp.frames, UiSprites.container, thumb, UiSprites.containerInsets, u);
    game.thumbnails.draw(canvas, progress, thumb.deflate(4 * u), s);

    final x = thumb.right + 5 * u, textW = row.right - x;
    final best = game.data.store.bestOf(progress.puzzle);
    final lineH = 10 * u;
    var mid = row.center.dy - ((best > 0 ? 3 : 2) - 1) * lineH / 2;
    final icon = 16 * s.half;
    Rect iconAt(double y) => s.snapRect(Rect.fromLTWH(x, y - icon / 2, icon, icon));
    void text(String t, double dx, double y, Color color) => game.text.draw(canvas, t, Offset(x + dx, y),
        level: TextLevel.normal, color: color, outline: null, anchor: TextAnchor.centerLeft);

    text(_fit(progress.puzzle.name, textW), 0, mid, PixelInk.darkBrown);
    mid += lineH;
    if (best > 0) {
      Pix.sprite(canvas, sp.icons, IconRef.star.rect, iconAt(mid));
      text(formatScore(best), icon + u, mid, PixelInk.brown);
      mid += lineH;
    }
    if (progress.isComplete) {
      Pix.sprite(canvas, sp.icons, IconRef.checkSmall.rect, iconAt(mid));
      text('Done', icon + u, mid, PixelInk.green);
    } else if (progress.isStarted) {
      final percent = '${(progress.fraction * 100).floor()}%';
      final barW = math.max(12 * u, math.min(44 * u, textW - game.text.measure(percent, TextLevel.normal).width - 3 * u));
      final bar = s.snapRect(Rect.fromLTWH(x, mid - 2 * u, barW, 4 * u));
      Pix.nine(canvas, sp.bars, UiSprites.barTrack, bar, UiSprites.barInsets, s.half);
      final fill = Rect.fromLTRB(bar.left + s.half * 2, bar.top + s.half,
          bar.left + s.half * 2 + (bar.width - s.half * 4) * progress.fraction, bar.bottom - s.half);
      canvas.drawRect(s.snapRect(fill), Paint()..color = const Color(0xFF6BCB5B));
      text(percent, barW + 2 * u, mid, PixelInk.brown);
    } else {
      text('New', 0, mid, PixelInk.brown);
    }
    if (paint != null) canvas.restore();
  }

  String _fit(String text, double width) {
    if (game.text.measure(text, TextLevel.normal, outline: false).width <= width) return text;
    var t = text;
    while (t.length > 3 && game.text.measure('$t..', TextLevel.normal, outline: false).width > width) {
      t = t.substring(0, t.length - 1);
    }
    return '${t.trimRight()}..';
  }
}
