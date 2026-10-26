import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Fft Transforms', () {
    accelerationTest('1D FFT / IFFT in-place roundtrip (powers of 2)', () {
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

    accelerationTest('1D FFT / IFFT in-place roundtrip (odd/prime sizes)', () {
      for (final n in [3, 5, 7, 13]) {
        final buffer = Float64ComplexList(n);
        for (var i = 0; i < n; i++) {
          buffer[i] = Complex(i.toDouble(), (n - i).toDouble());
        }
        final orig = Float64List.fromList(buffer.data);

        Fft.fft(buffer: buffer);
        Fft.fft(buffer: buffer, inverse: true);

        for (var i = 0; i < n; i++) {
          check(buffer[i].a).isCloseTo(orig[2 * i], 1e-10);
          check(buffer[i].b).isCloseTo(orig[2 * i + 1], 1e-10);
        }
      }
    }, isSupported: Fft.isAvailable);

    accelerationTest('2D FFT / IFFT in-place roundtrip (power of 2)', () {
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

    accelerationTest(
      '2D FFT / IFFT in-place roundtrip (arbitrary dimensions)',
      () {
        const rows = 3;
        const cols = 5;
        final buffer = Float64ComplexList(rows * cols);
        for (var i = 0; i < rows * cols; i++) {
          buffer[i] = Complex(i.toDouble(), (rows * cols - i).toDouble());
        }
        final orig = Float64List.fromList(buffer.data);

        Fft.fft2(buffer: buffer, rows: rows, cols: cols);
        Fft.fft2(buffer: buffer, rows: rows, cols: cols, inverse: true);

        for (var i = 0; i < rows * cols; i++) {
          check(buffer[i].a).isCloseTo(orig[2 * i], 1e-10);
          check(buffer[i].b).isCloseTo(orig[2 * i + 1], 1e-10);
        }
      },
      isSupported: Fft.isAvailable,
    );

    accelerationTest('1D and 2D FFT on odd-offset Float64ComplexList views and small powers of 2', () {
      for (final n in [2, 4, 8]) {
        final raw = Float64List(2 * n + 1);
        for (var i = 0; i < n; i++) {
          raw[1 + 2 * i] = (i + 1).toDouble();
          raw[1 + 2 * i + 1] = -(i + 1).toDouble();
        }
        final oddSlice = Float64List.sublistView(raw, 1, 1 + 2 * n);
        final buffer = Float64ComplexList.fromData(oddSlice);
        final orig = Float64List.fromList(oddSlice);

        Fft.fft(buffer: buffer);
        Fft.fft(buffer: buffer, inverse: true);

        for (var i = 0; i < n; i++) {
          check(buffer[i].a).isCloseTo(orig[2 * i], 1e-10);
          check(buffer[i].b).isCloseTo(orig[2 * i + 1], 1e-10);
        }
      }
    }, isSupported: Fft.isAvailable);
  });
}
