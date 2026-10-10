import 'package:color_by_number/src/audio/sound_effects.dart';
import 'package:color_by_number/src/game/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bank implements SoundBank {
  final played = <String>[];

  @override
  Future<void> play(String name, {double volume = 1}) async => played.add(name);
}

void main() {
  late _Bank bank;
  late DateTime time;
  late SoundEffects sounds;

  setUp(() {
    bank = _Bank();
    time = DateTime(2026);
    sounds = SoundEffects(MemoryStorage(), bank: bank, now: () => time);
  });

  void wait(int ms) => time = time.add(Duration(milliseconds: ms));

  test('a fast drag plays the paint sound as a rhythm, not every cell', () {
    for (var i = 0; i < 20; i++) {
      sounds.paint();
      wait(20); // a cell every 20 ms
    }
    expect(bank.played.where((s) => s == 'place').length, inInclusiveRange(3, 4), reason: 'about one per 110 ms');
  });

  test('a burst of combo levels sparkles once, even right after a paint', () {
    sounds.paint();
    for (var i = 0; i < 6; i++) {
      sounds.comboUp();
      wait(10);
    }
    expect(bank.played, ['place', 'magic']);
    wait(300);
    sounds.comboUp();
    expect(bank.played, ['place', 'magic', 'magic']);
  });

  test('different sounds keep a small gap, but the finish fanfare always plays', () {
    sounds.paint();
    sounds.mistake();
    expect(bank.played, ['place'], reason: 'too close to the last sound');
    sounds.finish();
    expect(bank.played, ['place', 'clear']);
  });

  test('a combo milestone always gets its wow, but not twice in a row', () {
    sounds.paint();
    sounds.wow();
    expect(bank.played, ['place', 'wow'], reason: 'right after a paint, like the finish');
    wait(500);
    sounds.wow();
    expect(bank.played, ['place', 'wow'], reason: 'within 1.5 s of the last one');
    wait(1000);
    sounds.wow();
    expect(bank.played, ['place', 'wow', 'wow']);
  });

  test('switched off, nothing plays', () {
    sounds.toggle();
    sounds.paint();
    sounds.finish();
    expect(bank.played, isEmpty);
  });
}
