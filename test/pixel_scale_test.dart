import 'dart:ui';

import 'package:color_by_number/src/ui/pixel_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int device(double w, double h, double dpr) => PixelScale.forScreen(Size(w, h), dpr).devicePixels;

  test('an art pixel is a whole, even number of device pixels, about 3-4 dp', () {
    expect(device(411, 731, 2.625), 8, reason: 'phone: 3.05 dp');
    expect(device(1280, 800, 2), 8, reason: 'tablet: 4 dp');
    expect(device(1280, 800, 2) % 2, 0);
  });

  test('rounding to whole pixels never makes it bigger than 4 dp', () {
    // Xiaomi Pad 8: 440 dpi. 4 dp would be 11 device pixels; 12 is too big.
    final pad = PixelScale.forScreen(const Size(1163.6, 776.7), 2.75);
    expect(pad.devicePixels, 10);
    expect(pad.unit, lessThanOrEqualTo(4));
  });

  test('short landscape windows get smaller pixels, so the book still fits', () {
    expect(device(960, 640, 2), 6);
    expect(device(960, 640, 1), 3, reason: 'odd sizes are fine on low-density screens');
  });
}
