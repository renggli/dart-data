import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('FFT Acceleration', () {
    test('isFftAvailable reports platform status', () {
      if (AccelerationManager.isBlasAvailable) {
        check(AccelerationManager.isFftAvailable).isTrue();
      }
    });

    accelerationTest('1D FFT and IFFT roundtrip', () {
      final input = List.generate(
        128,
        (i) => Complex(
          math.sin(2 * math.pi * i / 16),
          math.cos(2 * math.pi * i / 32),
        ),
      );

      final result = AccelerationManager.fft(input);
      check(result.length).equals(input.length);

      final reconstructed = AccelerationManager.ifft(result);
      for (var i = 0; i < input.length; i++) {
        check(reconstructed[i].a).isCloseTo(input[i].a, 1e-9);
        check(reconstructed[i].b).isCloseTo(input[i].b, 1e-9);
      }
    }, isSupported: AccelerationManager.isFftAvailable);

    accelerationTest('2D FFT and IFFT roundtrip', () {
      final matrix = List.generate(
        16,
        (r) => List.generate(
          16,
          (c) => Complex((r + 1).toDouble() * (c + 1), (r - c).toDouble()),
        ),
      );

      final result = AccelerationManager.fft2(matrix);
      check(result.length).equals(matrix.length);

      final reconstructed = AccelerationManager.ifft2(result);
      for (var r = 0; r < matrix.length; r++) {
        for (var c = 0; c < matrix[r].length; c++) {
          check(reconstructed[r][c].a).isCloseTo(matrix[r][c].a, 1e-8);
          check(reconstructed[r][c].b).isCloseTo(matrix[r][c].b, 1e-8);
        }
      }
    }, isSupported: AccelerationManager.isFftAvailable);

    accelerationTest('2D FFT rectangular matrix roundtrip', () {
      for (final (rows, cols) in [(8, 16), (16, 8)]) {
        final matrix = List.generate(
          rows,
          (r) => List.generate(
            cols,
            (c) => Complex((r + 1).toDouble(), (c + 1).toDouble()),
          ),
        );

        final result = AccelerationManager.fft2(matrix);
        check(result.length).equals(rows);

        final reconstructed = AccelerationManager.ifft2(result);
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            check(reconstructed[r][c].a).isCloseTo(matrix[r][c].a, 1e-8);
            check(reconstructed[r][c].b).isCloseTo(matrix[r][c].b, 1e-8);
          }
        }
      }
    }, isSupported: AccelerationManager.isFftAvailable);

    accelerationTest('2D FFT extreme aspect roundtrip', () {
      for (final (rows, cols) in [(1, 16), (16, 1)]) {
        final matrix = List.generate(
          rows,
          (r) => List.generate(
            cols,
            (c) => Complex((r + 1).toDouble(), (c + 1).toDouble()),
          ),
        );

        final result = AccelerationManager.fft2(matrix);
        final reconstructed = AccelerationManager.ifft2(result);
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            check(reconstructed[r][c].a).isCloseTo(matrix[r][c].a, 1e-8);
            check(reconstructed[r][c].b).isCloseTo(matrix[r][c].b, 1e-8);
          }
        }
      }
    }, isSupported: AccelerationManager.isFftAvailable);

    accelerationTest('rfft and irfft roundtrip', () {
      final realSignal = List.generate(
        64,
        (i) =>
            math.cos(2 * math.pi * i / 8) + 0.5 * math.sin(2 * math.pi * i / 4),
      );

      final rfft = AccelerationManager.rfft(realSignal);
      final reconstructed = AccelerationManager.irfft(rfft, realSignal.length);

      check(reconstructed.length).equals(realSignal.length);
      for (var i = 0; i < realSignal.length; i++) {
        check(reconstructed[i]).isCloseTo(realSignal[i], 1e-9);
      }
    }, isSupported: AccelerationManager.isFftAvailable);
  });
}
