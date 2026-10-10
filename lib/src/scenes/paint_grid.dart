import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontFeature;

import '../game/paint_tool.dart';
import '../game/puzzle_progress.dart';
import '../ui/pixel_text.dart';
import '../ui/ui_sprites.dart';
import 'paint_book_game.dart';

/// One paint action on the grid, for scoring and effects.
class PaintEvent {
  const PaintEvent({
    required this.tool,
    required this.cells,
    required this.mistake,
    required this.cellCenter,
    required this.cellSize,
    required this.at,
  });

  final PaintTool tool;

  /// Cells that just got their right color; empty for a [mistake].
  final List<int> cells;

  /// The cell got a wrong color.
  final bool mistake;

  /// Where a cell is, in the game's coordinates.
  final Offset Function(int index) cellCenter;

  /// On-screen size of one cell.
  final double cellSize;

  /// Where the pointer was, in the game's coordinates.
  final Offset at;
}

/// The zoomable grid the player paints on.
///
/// One finger (or the left mouse button) paints with [tool]; two fingers
/// pinch-zoom and pan; the mouse wheel / trackpad zooms and right-drag pans.
/// It gets raw pointer events (see [PaintBookGame.onRawPointer]) because
/// painting and pinching need every finger, not recognized gestures.
class PaintGrid extends PositionComponent with HasGameReference<PaintBookGame> {
  PaintGrid({
    required this.progress,
    required this.selectedNumber,
    this.onPaint,
    this.onStrokeStart,
    this.onStrokeUndone,
  });

  final PuzzleProgress progress;
  int Function() selectedNumber;
  PaintTool tool = PaintTool.pencil;
  void Function(PaintEvent)? onPaint;
  void Function()? onStrokeStart;
  void Function()? onStrokeUndone;

  static const _padding = 6.0; // art pixels

  /// On-screen cell size when zoomed all the way in, whatever the grid size.
  static const _maxCellSize = 48.0;

  /// Cell size "Find a cell" zooms to, big enough to read the number.
  static const _findCellSize = 32.0;

  /// Below this on-screen cell size numbers are unreadable.
  static const minNumberCell = 12.0;

  /// Below this grid lines would swamp the picture.
  static const minGridCell = 6.0;

  /// A second finger landing this soon after the first means the player was
  /// starting a pinch, so whatever the first finger painted is undone.
  static const _pinchGrace = Duration(milliseconds: 250);

  double _zoom = 1;

  /// Top-left of the grid in local coordinates; null keeps it centered.
  Offset? _origin;

  final _pointers = <int, Offset>{};
  var _gesture = _Gesture.none;
  Offset _lastPaint = Offset.zero;
  int _lastStrokeCell = -1;
  Duration _strokeStart = Duration.zero;
  final _strokeUndo = <int, int>{};
  Offset _anchorGridPoint = Offset.zero;
  double _anchorZoom = 1;
  double _anchorSpan = 0;

  int _findFrom = 0;
  int? _found;
  double _foundTime = 0;

  Picture? _picture;
  bool _dirty = true;
  int _drawnSelected = -1;

  int get _cols => progress.puzzle.width;
  int get _rows => progress.puzzle.height;
  double get _pad => _padding * game.scale.unit;

  double get fitCell => math.max(
        1.0,
        math.min((size.x - 2 * _pad) / _cols, (size.y - 2 * _pad) / _rows),
      );
  double get cell => fitCell * _zoom;
  double get maxZoom => math.max(6.0, _maxCellSize / fitCell);
  double get zoom => _zoom;
  bool get canZoomIn => _zoom < maxZoom;
  bool get canZoomOut => _zoom > 1;

  Offset get gridOrigin {
    final c = cell;
    return _clamp(_origin ?? Offset((size.x - _cols * c) / 2, (size.y - _rows * c) / 2), c);
  }

  /// Centers an axis that fits, otherwise keeps the grid's edge from leaving
  /// a gap bigger than the padding.
  Offset _clamp(Offset o, double c) {
    double axis(double v, double grid, double view) =>
        grid + 2 * _pad <= view ? (view - grid) / 2 : v.clamp(view - grid - _pad, _pad);
    return Offset(axis(o.dx, _cols * c, size.x), axis(o.dy, _rows * c, size.y));
  }

  Offset _toGrid(Offset local) => (local - gridOrigin) / cell;

  /// Where cell [index] is, in the grid's coordinates.
  Offset cellCenter(int index) => gridOrigin + Offset((index % _cols + 0.5) * cell, (index ~/ _cols + 0.5) * cell);

  /// The cells on screen, in cell units.
  Rect get visibleCells => Rect.fromPoints(_toGrid(Offset.zero), _toGrid(Offset(size.x, size.y)))
      .intersect(Rect.fromLTWH(0, 0, _cols.toDouble(), _rows.toDouble()));

  bool get zoomedIn => visibleCells.width < _cols - 0.5 || visibleCells.height < _rows - 0.5;

  void _zoomTo(double zoom, {required Offset gridPoint, required Offset at}) {
    final z = zoom.clamp(1.0, maxZoom);
    final c = fitCell * z;
    _zoom = z;
    _origin = _clamp(at - gridPoint * c, c);
    _dirty = true;
  }

  void centerOn(Offset gridPoint) => _zoomTo(_zoom, gridPoint: gridPoint, at: Offset(size.x / 2, size.y / 2));

  void resetView() {
    _zoom = 1;
    _origin = null;
    _dirty = true;
  }

  void zoomStep(double factor) {
    final center = Offset(size.x / 2, size.y / 2);
    _zoomTo(_zoom * factor, gridPoint: _toGrid(center), at: center);
  }

  /// Centers the view on the next cell still waiting for the selected color.
  void findCell() {
    final cells = progress.puzzle.cells;
    final number = selectedNumber();
    for (var k = 0; k < cells.length; k++) {
      final i = (_findFrom + k) % cells.length;
      if (cells[i] != number || progress.paintedAt(i) == number) continue;
      _findFrom = i + 1;
      _found = i;
      _foundTime = 0;
      final z = math.max(_zoom, math.min(maxZoom, _findCellSize / fitCell));
      _zoomTo(z, gridPoint: Offset(i % _cols + 0.5, i ~/ _cols + 0.5), at: Offset(size.x / 2, size.y / 2));
      return;
    }
  }

  @override
  void onMount() {
    super.onMount();
    progress.addListener(_markDirty);
  }

  @override
  void onRemove() {
    progress.removeListener(_markDirty);
    _picture?.dispose();
    super.onRemove();
  }

  void _markDirty() => _dirty = true;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _dirty = true;
  }

  /// The screen calls this after giving the grid a new size.
  void resized() {
    _origin = null;
    _zoom = _zoom.clamp(1.0, maxZoom);
    _dirty = true;
  }

  // --- Painting ---------------------------------------------------------------

  void _paintAt(Offset local) {
    final g = _toGrid(local);
    final x = g.dx.floor(), y = g.dy.floor();
    if (x < 0 || y < 0 || x >= _cols || y >= _rows) return;
    final index = y * _cols + x;
    if (index == _lastStrokeCell) return;
    _lastStrokeCell = index;
    final number = selectedNumber();

    switch (tool) {
      case PaintTool.pencil:
        final previous = progress.paint(index, number);
        if (previous == null) return;
        _strokeUndo.putIfAbsent(index, () => previous);
        _report(local, [index]);
      case PaintTool.fill:
        final changed = progress.fill(index, number);
        if (changed.isEmpty) return;
        changed.forEach((i, previous) => _strokeUndo.putIfAbsent(i, () => previous));
        _report(local, changed.keys.toList());
    }
  }

  void _report(Offset at, List<int> cells) {
    final onPaint = this.onPaint;
    if (onPaint == null) return;
    final mistake = progress.paintedAt(cells.first) != progress.puzzle.cells[cells.first];
    final origin = gridOrigin + absolutePosition.toOffset(), c = cell, cols = _cols;
    onPaint(PaintEvent(
      tool: tool,
      cells: mistake ? const [] : cells,
      mistake: mistake,
      cellCenter: (i) => origin + Offset((i % cols + 0.5) * c, (i ~/ cols + 0.5) * c),
      cellSize: c,
      at: at + absolutePosition.toOffset(),
    ));
  }

  void _paintLine(Offset from, Offset to) {
    final steps = math.max(1, ((to - from).distance / (cell / 3)).ceil());
    for (var s = 1; s <= steps; s++) {
      _paintAt(Offset.lerp(from, to, s / steps)!);
    }
  }

  // --- Pointers ---------------------------------------------------------------

  /// Whether a pointer going down at [point] (game coordinates) is ours.
  bool owns(Offset point) => toRect().contains(point);

  void handlePointer(PointerEvent e) {
    final local = e.localPosition - absolutePosition.toOffset();
    switch (e) {
      case PointerDownEvent():
        _down(e, local);
      case PointerMoveEvent():
        _move(e, local);
      case PointerUpEvent() || PointerCancelEvent():
        _end(e);
      case PointerScrollEvent():
        _zoomTo(_zoom * math.exp(-e.scrollDelta.dy / 300), gridPoint: _toGrid(local), at: local);
      case PointerPanZoomStartEvent():
        _anchorGridPoint = _toGrid(local);
        _anchorZoom = _zoom;
      case PointerPanZoomUpdateEvent():
        _zoomTo(_anchorZoom * e.scale, gridPoint: _anchorGridPoint, at: local + e.pan);
      default:
        break;
    }
  }

  void _down(PointerDownEvent e, Offset local) {
    _pointers[e.pointer] = local;
    _found = null;
    final secondaryMouse = e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryMouseButton;
    if (_pointers.length == 1 && !secondaryMouse) {
      _gesture = _Gesture.paint;
      _strokeUndo.clear();
      _strokeStart = e.timeStamp;
      _lastPaint = local;
      _lastStrokeCell = -1;
      onStrokeStart?.call();
      _paintAt(local);
      return;
    }
    if (_gesture == _Gesture.paint && e.timeStamp - _strokeStart < _pinchGrace) {
      progress.revert(_strokeUndo);
      onStrokeUndone?.call();
    }
    _strokeUndo.clear();
    _startTransform();
  }

  void _move(PointerMoveEvent e, Offset local) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = local;
    switch (_gesture) {
      case _Gesture.paint:
        _paintLine(_lastPaint, local);
        _lastPaint = local;
      case _Gesture.transform:
        _updateTransform();
      case _Gesture.none:
        break;
    }
  }

  void _end(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) {
      _gesture = _Gesture.none;
    } else if (_gesture == _Gesture.transform) {
      _startTransform();
    }
  }

  Offset get _focal => _pointers.values.reduce((a, b) => a + b) / _pointers.length.toDouble();

  double get _span {
    if (_pointers.length < 2) return 0;
    final [a, b, ...] = _pointers.values.toList();
    return (a - b).distance;
  }

  void _startTransform() {
    _gesture = _Gesture.transform;
    _anchorGridPoint = _toGrid(_focal);
    _anchorZoom = _zoom;
    _anchorSpan = _span;
  }

  void _updateTransform() {
    final span = _span;
    final z = _anchorSpan > 0 && span > 0 ? _anchorZoom * span / _anchorSpan : _anchorZoom;
    _zoomTo(z, gridPoint: _anchorGridPoint, at: _focal);
  }

  // --- Drawing ------------------------------------------------------------------

  static const _highlight = Color(0xC4FFF2A8);
  static const _gridLine = Color(0x2A3F2832);
  static const _mistake = Color(0xFFE5484D);

  @override
  void update(double dt) {
    if (_found != null) _foundTime += dt;
    final selected = selectedNumber();
    if (selected != _drawnSelected) {
      _drawnSelected = selected;
      _dirty = true;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.clipRect(size.toRect());
    if (_dirty || _picture == null) {
      _picture?.dispose();
      _picture = _record();
      _dirty = false;
    }
    canvas.drawPicture(_picture!);
    _renderFound(canvas);
    canvas.restore();
  }

  Picture _record() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final puzzle = progress.puzzle;
    final c = cell;
    final origin = gridOrigin;
    final selected = _drawnSelected;
    final done = progress.isComplete;
    final showNumbers = !done && c >= minNumberCell;
    final showGrid = !done && c >= minGridCell;
    final highlighted = [for (final e in puzzle.palette) Color.alphaBlend(_highlight, e.shade)];
    final dpr = game.scale.devicePixelRatio;
    final hair = 1 / dpr;

    final fill = Paint()..isAntiAlias = false;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hair
      ..color = _gridLine;
    final border = math.max(2.0, (c * dpr * 0.08).roundToDouble()) / dpr;
    final labels = _Labels(c, dpr);

    final x0 = math.max(0, (-origin.dx / c).floor());
    final y0 = math.max(0, (-origin.dy / c).floor());
    final x1 = math.min(puzzle.width, ((size.x - origin.dx) / c).ceil());
    final y1 = math.min(puzzle.height, ((size.y - origin.dy) / c).ceil());

    Color? fillAt(int i) {
      final target = puzzle.cells[i];
      if (target == 0) return null;
      if (progress.paintedAt(i) == target) return puzzle.entry(target).color;
      return target == selected ? highlighted[target - 1] : puzzle.entry(target).shade;
    }

    double snap(double v) => (v * dpr).roundToDouble() / dpr;

    for (var y = y0; y < y1; y++) {
      final top = snap(origin.dy + y * c), bottom = snap(origin.dy + (y + 1) * c);
      var runStart = x0;
      Color? runColor;
      for (var x = x0; x <= x1; x++) {
        final color = x < x1 ? fillAt(y * puzzle.width + x) : null;
        if (x < x1 && color == runColor) continue;
        if (runColor != null) {
          canvas.drawRect(
            Rect.fromLTRB(snap(origin.dx + runStart * c), top, snap(origin.dx + x * c), bottom),
            fill..color = runColor,
          );
        }
        runStart = x;
        runColor = color;
      }

      for (var x = x0; x < x1; x++) {
        final i = y * puzzle.width + x;
        final target = puzzle.cells[i];
        final painted = progress.paintedAt(i);
        if (target == 0 || painted == target) continue;
        if (painted == 0 && !showGrid && !showNumbers) continue;
        final rect = Rect.fromLTRB(snap(origin.dx + x * c), top, snap(origin.dx + (x + 1) * c), bottom);
        var light = false;
        if (painted != 0) {
          final wrong = puzzle.entry(painted).color;
          canvas.drawRect(rect, fill..color = wrong.withValues(alpha: 0.6));
          // A pixel-art frame: four bars, no anti-aliasing.
          final f = fill..color = _mistake;
          canvas
            ..drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, border), f)
            ..drawRect(Rect.fromLTWH(rect.left, rect.bottom - border, rect.width, border), f)
            ..drawRect(Rect.fromLTWH(rect.left, rect.top, border, rect.height), f)
            ..drawRect(Rect.fromLTWH(rect.right - border, rect.top, border, rect.height), f);
          light = wrong.computeLuminance() < 0.25;
        } else if (showGrid) {
          canvas.drawRect(rect.deflate(hair / 2), line);
        }
        if (showNumbers) labels.draw(canvas, rect, target, light: light);
      }
    }
    labels.dispose();
    return recorder.endRecording();
  }

  /// Corner brackets bouncing around the cell "Find a cell" found.
  void _renderFound(Canvas canvas) {
    final f = _found;
    if (f == null || progress.paintedAt(f) == progress.puzzle.cells[f]) return;
    final s = game.scale;
    final bounce = (math.sin(_foundTime * 8) + 1) * s.half;
    final center = cellCenter(f);
    final side = cell + 6 * s.half + bounce * 2;
    Pix.nine(canvas, game.sprites.selectors, UiSprites.selector,
        s.snapRect(Rect.fromCenter(center: center, width: side, height: side)), UiSprites.selectorInsets, s.half);
  }

  // Exposed for tests and the screen.
  int? get found => _found;
}

enum _Gesture { none, paint, transform }

/// Each number laid out once per recording, at whole device pixels per font
/// pixel so the digits stay crisp.
class _Labels {
  _Labels(this.cell, this.dpr);

  final double cell;
  final double dpr;
  final _cache = <int, TextPainter>{};

  void draw(Canvas canvas, Rect rect, int number, {required bool light}) {
    final key = light ? -number : number;
    final painter = _cache.putIfAbsent(key, () {
      final digits = '$number'.length;
      final fontPx = math.max(1, (cell * dpr / (digits == 1 ? 10 : 14)).floor()) / dpr;
      return TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            fontFamily: 'PohSans',
            fontSize: 11 * fontPx,
            height: 1,
            fontWeight: FontWeight.w700,
            color: light ? PixelInk.cream : PixelInk.outline,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      )..layout();
    });
    final at = rect.center - Offset(painter.width / 2, painter.height / 2);
    painter.paint(canvas, Offset((at.dx * dpr).roundToDouble() / dpr, (at.dy * dpr).roundToDouble() / dpr));
  }

  void dispose() {
    for (final p in _cache.values) {
      p.dispose();
    }
  }
}
