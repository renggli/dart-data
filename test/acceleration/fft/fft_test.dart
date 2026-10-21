import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Fft Transforms', () {
    accelerationTest('1D FFT / IFFT in-place roundtrip', () {
      final buffer = Float64ComplexList(8);
      for (var i = 0; i < 8; i++) {
        buffer[i] = Complex(i.toDouble(), (8 - i).toDouble());
      }
      final orig = Float64List.fromList(buffer.data);

      Fft.fft(buffer: buffer);
      Fft.fft(buffer: buffer, inverse: true);

      for (var i = 0; i < 8; i++) {
        check(buffer[i].a).isCloseTo(orig[2 * i], 1e-10);
        check(buffer[i].b).isCloseTo(orig[2 * i + 1], 1e-10);
      }
    }, isSupported: Fft.isAvailable);

    accelerationTest('2D FFT / IFFT in-place roundtrip', () {
      final buffer = Float64ComplexList(16); // 4x4
      for (var i = 0; i < 16; i++) {
        buffer[i] = Complex(i.toDouble(), 0.0);
      }
      final orig = Float64List.fromList(buffer.data);

      Fft.fft2(buffer: buffer, rows: 4, cols: 4);
      Fft.fft2(buffer: buffer, rows: 4, cols: 4, inverse: true);

      for (var i = 0; i < 16; i++) {
        check(buffer[i].a).isCloseTo(orig[2 * i], 1e-10);
      }
    }, isSupported: Fft.isAvailable);
  });
}
