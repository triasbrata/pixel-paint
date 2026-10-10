import 'dart:typed_data';
import 'dart:ui';

import 'package:color_by_number/src/data/puzzle_loader.dart';
import 'package:color_by_number/src/models/color_names.dart';
import 'package:color_by_number/src/models/difficulty.dart';
import 'package:color_by_number/src/models/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('Puzzle.fromRgba', () {
    test('trims transparent borders and numbers every distinct color', () {
      final p = tinyPuzzle();
      expect(p.width, 2);
      expect(p.height, 3);
      expect(p.palette, hasLength(3));
      expect(p.paintableCount, 6);
      // Same pixel color → same number.
      expect(p.cells[1], p.cells[3]); // both red
      expect(p.cells[0], p.cells[4]); // both black
      expect(p.cells.toSet(), {1, 2, 3});
    });

    test('keeps transparent pixels inside the picture as empty cells', () {
      final p = puzzleFromRows(['r.r', 'rrr'], {'r': red});
      expect(p.cells, [1, 0, 1, 1, 1, 1]);
      expect(p.paintableCount, 5);
    });

    test('orders grays first, then groups similar hues next to each other', () {
      final p = puzzleFromRows(
        ['abcde'],
        {'a': 0xFF2E7D32, 'b': 0xFFFFFFFF, 'c': 0xFFE53935, 'd': 0xFF81C784, 'e': 0xFF000000},
      );
      final names = p.palette.map((e) => e.name).toList();
      expect(names.take(2), ['Black', 'White']);
      expect(names.skip(2), ['Red', 'Dark Green', 'Light Green']);
      expect([for (final e in p.palette) e.number], [1, 2, 3, 4, 5]);
    });

    test('rejects a picture with no opaque pixels', () {
      expect(
        () => Puzzle.fromRgba(id: 'x', name: 'x', width: 2, height: 2, rgba: Uint8List(16)),
        throwsArgumentError,
      );
    });

    test('fingerprint changes when the picture changes', () {
      final a = puzzleFromRows(['rg'], {'r': red, 'g': green});
      final b = puzzleFromRows(['gr'], {'r': red, 'g': green});
      expect(a.fingerprint, puzzleFromRows(['rg'], {'r': red, 'g': green}).fingerprint);
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('unpainted shade is a gray that keeps dark colors darker', () {
      final p = puzzleFromRows(['kw'], {'k': black, 'w': 0xFFFFFFFF});
      final dark = p.palette.first.shade, light = p.palette.last.shade;
      expect(dark.r, dark.g);
      expect(dark.r, lessThan(light.r));
      expect(dark.r, greaterThan(0.5), reason: 'numbers must stay readable');
    });
  });

  test('difficulty takes the harder of color count and size', () {
    Difficulty d(int colors, int cells) => Difficulty.classify(colorCount: colors, cellCount: cells);
    expect(d(5, 200), Difficulty.easy);
    expect(d(6, 200), Difficulty.medium);
    expect(d(14, 200), Difficulty.hard);
    expect(d(15, 200), Difficulty.expert);
    expect(d(3, 32 * 32), Difficulty.easy);
    expect(d(3, 40 * 40), Difficulty.medium);
    expect(d(9, 60 * 60), Difficulty.hard);
    expect(d(3, 100 * 100), Difficulty.expert);
  });

  test('color names', () {
    expect(colorName(const Color(0xFFE53935)), 'Red');
    expect(colorName(const Color(0xFF000000)), 'Black');
    expect(colorName(const Color(0xFFFFFFFF)), 'White');
    expect(colorName(const Color(0xFF9E9E9E)), 'Gray');
    expect(colorName(const Color(0xFF795548)), 'Brown');
    expect(colorName(const Color(0xFF8D4A3A)), 'Brown');
    expect(colorName(const Color(0xFFB71C1C)), 'Dark Red');
    expect(colorName(const Color(0xFF90CAF9)), 'Light Blue');
    expect(colorName(const Color(0xFF0D47A1)), 'Dark Blue');
    expect(colorName(const Color(0xFFFDD835)), 'Yellow');
    expect(colorName(const Color(0xFFF8BBD0)), 'Pink');
  });

  test('titleFromId', () {
    expect(titleFromId('blue_gems'), 'Blue Gems');
    expect(titleFromId('lemon'), 'Lemon');
    expect(titleFromId('viking-helmet'), 'Viking Helmet');
  });
}
