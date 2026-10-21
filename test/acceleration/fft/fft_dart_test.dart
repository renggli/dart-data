import 'package:checks/checks.dart';
import 'package:data/src/acceleration/fft/fft_dart.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('FftDart Edge Cases', () {
    test('fft on length 0 and 1 is a no-op', () {
      final b0 = Float64ComplexList(0);
      FftDart.fft(buffer: b0, inverse: false);
      check(b0.length).equals(0);

      final b1 = Float64ComplexList(1);
      b1[0] = const Complex(5.0, 7.0);
      FftDart.fft(buffer: b1, inverse: false);
      check(b1[0].a).equals(5.0);
      check(b1[0].b).equals(7.0);
    });

    test('fft throws on non-power-of-two length', () {
      final b3 = Float64ComplexList(3);
      check(() => FftDart.fft(buffer: b3, inverse: false))
          .throws<ArgumentError>();
    });

    test('fft2 throws on invalid dimensions', () {
      final b8 = Float64ComplexList(8);
      check(() => FftDart.fft2(buffer: b8, rows: 3, cols: 2, inverse: false))
          .throws<ArgumentError>();
      check(() => FftDart.fft2(buffer: b8, rows: 2, cols: 3, inverse: false))
          .throws<ArgumentError>();
      check(() => FftDart.fft2(buffer: b8, rows: 4, cols: 4, inverse: false))
          .throws<ArgumentError>();
    });
  });
}
