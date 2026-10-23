import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/fft/fft_dart.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('FftDart 1D', () {
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

    test('fft on non-power-of-two length computes DFT and inverts', () {
      final b3 = Float64ComplexList(3);
      b3[0] = const Complex(1.0, 0.0);
      b3[1] = const Complex(2.0, 0.0);
      b3[2] = const Complex(3.0, 0.0);

      FftDart.fft(buffer: b3, inverse: false);
      // X_0 = 1 + 2 + 3 = 6
      check((b3[0].a - 6.0).abs() < 1e-10).isTrue();
      check(b3[0].b.abs() < 1e-10).isTrue();
      // X_1 = -1.5 + sqrt(3)/2 * i
      check((b3[1].a - (-1.5)).abs() < 1e-10).isTrue();
      check((b3[1].b - (math.sqrt(3) / 2)).abs() < 1e-10).isTrue();

      // Invert back
      FftDart.fft(buffer: b3, inverse: true);
      check((b3[0].a - 1.0).abs() < 1e-10).isTrue();
      check(b3[0].b.abs() < 1e-10).isTrue();
      check((b3[1].a - 2.0).abs() < 1e-10).isTrue();
      check(b3[1].b.abs() < 1e-10).isTrue();
      check((b3[2].a - 3.0).abs() < 1e-10).isTrue();
      check(b3[2].b.abs() < 1e-10).isTrue();
    });
  });

  group('FftDart 2D', () {
    test('fft2 throws on buffer length mismatch', () {
      final b8 = Float64ComplexList(8);
      check(() => FftDart.fft2(buffer: b8, rows: 3, cols: 3, inverse: false))
          .throws<ArgumentError>();
      check(() => FftDart.fft2(buffer: b8, rows: 4, cols: 4, inverse: false))
          .throws<ArgumentError>();
    });

    test('fft2 on arbitrary dimensions computes 2D DFT and inverts', () {
      final b6 = Float64ComplexList(6); // 2 rows x 3 cols
      for (var i = 0; i < 6; i++) {
        b6[i] = Complex(i.toDouble(), (6 - i).toDouble());
      }
      final orig = Float64List.fromList(b6.data);

      FftDart.fft2(buffer: b6, rows: 2, cols: 3, inverse: false);
      FftDart.fft2(buffer: b6, rows: 2, cols: 3, inverse: true);

      for (var i = 0; i < 6; i++) {
        check(b6[i].a).isCloseTo(orig[2 * i], 1e-10);
        check(b6[i].b).isCloseTo(orig[2 * i + 1], 1e-10);
      }
    });
  });
}
