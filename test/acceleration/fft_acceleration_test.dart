import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('FFT Acceleration Parity and Modes', () {
    final originalMode = AccelerationManager.mode;

    tearDown(() {
      AccelerationManager.mode = originalMode;
    });

    test('isFftAvailable reports platform status', () {
      if (AccelerationManager.isNativeAvailable) {
        check(AccelerationManager.isFftAvailable).isTrue();
      }
    });

    test('1D FFT parity between native acceleration and pure Dart', () {
      final input = List.generate(
        128,
        (i) => Complex(
          math.sin(2 * math.pi * i / 16),
          math.cos(2 * math.pi * i / 32),
        ),
      );

      AccelerationManager.mode = AccelerationMode.dart;
      final dartResult = AccelerationManager.fft(input);

      if (AccelerationManager.isFftAvailable) {
        AccelerationManager.mode = AccelerationMode.accelerated;
        final nativeResult = AccelerationManager.fft(input);

        check(nativeResult.length).equals(dartResult.length);
        for (var i = 0; i < dartResult.length; i++) {
          check(nativeResult[i].a).isCloseTo(dartResult[i].a, 1e-9);
          check(nativeResult[i].b).isCloseTo(dartResult[i].b, 1e-9);
        }

        // Test IFFT roundtrip parity
        final dartInverse = AccelerationManager.ifft(dartResult);
        final nativeInverse = AccelerationManager.ifft(nativeResult);
        for (var i = 0; i < input.length; i++) {
          check(nativeInverse[i].a).isCloseTo(dartInverse[i].a, 1e-9);
          check(nativeInverse[i].b).isCloseTo(dartInverse[i].b, 1e-9);
          check(nativeInverse[i].a).isCloseTo(input[i].a, 1e-9);
          check(nativeInverse[i].b).isCloseTo(input[i].b, 1e-9);
        }
      }
    });

    test('2D FFT parity between native acceleration and pure Dart', () {
      final matrix = List.generate(
        16,
        (r) => List.generate(
          16,
          (c) => Complex((r + 1).toDouble() * (c + 1), (r - c).toDouble()),
        ),
      );

      AccelerationManager.mode = AccelerationMode.dart;
      final dartResult = AccelerationManager.fft2(matrix);

      if (AccelerationManager.isFftAvailable) {
        AccelerationManager.mode = AccelerationMode.accelerated;
        final nativeResult = AccelerationManager.fft2(matrix);

        check(nativeResult.length).equals(dartResult.length);
        for (var r = 0; r < dartResult.length; r++) {
          for (var c = 0; c < dartResult[r].length; c++) {
            check(nativeResult[r][c].a).isCloseTo(dartResult[r][c].a, 1e-8);
            check(nativeResult[r][c].b).isCloseTo(dartResult[r][c].b, 1e-8);
          }
        }

        final dartInverse = AccelerationManager.ifft2(dartResult);
        final nativeInverse = AccelerationManager.ifft2(nativeResult);
        for (var r = 0; r < matrix.length; r++) {
          for (var c = 0; c < matrix[r].length; c++) {
            check(dartInverse[r][c].a).isCloseTo(matrix[r][c].a, 1e-8);
            check(dartInverse[r][c].b).isCloseTo(matrix[r][c].b, 1e-8);
            check(nativeInverse[r][c].a).isCloseTo(matrix[r][c].a, 1e-8);
            check(nativeInverse[r][c].b).isCloseTo(matrix[r][c].b, 1e-8);
          }
        }
      }
    });

    test('2D FFT rectangular matrix parity (8x16 and 16x8)', () {
      for (final (rows, cols) in [(8, 16), (16, 8)]) {
        final matrix = List.generate(
          rows,
          (r) => List.generate(
            cols,
            (c) => Complex((r + 1).toDouble(), (c + 1).toDouble()),
          ),
        );

        AccelerationManager.mode = AccelerationMode.dart;
        final dartResult = AccelerationManager.fft2(matrix);

        if (AccelerationManager.isFftAvailable) {
          AccelerationManager.mode = AccelerationMode.accelerated;
          final nativeResult = AccelerationManager.fft2(matrix);

          check(nativeResult.length).equals(dartResult.length);
          for (var r = 0; r < dartResult.length; r++) {
            for (var c = 0; c < dartResult[r].length; c++) {
              check(nativeResult[r][c].a).isCloseTo(dartResult[r][c].a, 1e-8);
              check(nativeResult[r][c].b).isCloseTo(dartResult[r][c].b, 1e-8);
            }
          }

          final dartInverse = AccelerationManager.ifft2(dartResult);
          final nativeInverse = AccelerationManager.ifft2(nativeResult);
          for (var r = 0; r < rows; r++) {
            for (var c = 0; c < cols; c++) {
              check(nativeInverse[r][c].a).isCloseTo(dartInverse[r][c].a, 1e-8);
              check(nativeInverse[r][c].b).isCloseTo(dartInverse[r][c].b, 1e-8);
            }
          }
        }
      }
    });

    test('2D FFT extreme aspect (1x16 and 16x1) parity', () {
      for (final (rows, cols) in [(1, 16), (16, 1)]) {
        final matrix = List.generate(
          rows,
          (r) => List.generate(
            cols,
            (c) => Complex((r + 1).toDouble(), (c + 1).toDouble()),
          ),
        );

        AccelerationManager.mode = AccelerationMode.dart;
        final dartResult = AccelerationManager.fft2(matrix);

        if (AccelerationManager.isFftAvailable) {
          AccelerationManager.mode = AccelerationMode.accelerated;
          final nativeResult = AccelerationManager.fft2(matrix);

          final dartInverse = AccelerationManager.ifft2(dartResult);
          final nativeInverse = AccelerationManager.ifft2(nativeResult);
          for (var r = 0; r < rows; r++) {
            for (var c = 0; c < cols; c++) {
              check(nativeInverse[r][c].a).isCloseTo(dartInverse[r][c].a, 1e-8);
              check(nativeInverse[r][c].b).isCloseTo(dartInverse[r][c].b, 1e-8);
            }
          }
        }
      }
    });

    test('rfft and irfft parity', () {
      final realSignal = List.generate(
        64,
        (i) =>
            math.cos(2 * math.pi * i / 8) + 0.5 * math.sin(2 * math.pi * i / 4),
      );

      AccelerationManager.mode = AccelerationMode.dart;
      final dartRfft = AccelerationManager.rfft(realSignal);
      final dartIrfft = AccelerationManager.irfft(dartRfft, realSignal.length);

      if (AccelerationManager.isFftAvailable) {
        AccelerationManager.mode = AccelerationMode.accelerated;
        final nativeRfft = AccelerationManager.rfft(realSignal);
        final nativeIrfft = AccelerationManager.irfft(
          nativeRfft,
          realSignal.length,
        );

        check(nativeRfft.length).equals(dartRfft.length);
        for (var i = 0; i < dartRfft.length; i++) {
          check(nativeRfft[i].a).isCloseTo(dartRfft[i].a, 1e-9);
          check(nativeRfft[i].b).isCloseTo(dartRfft[i].b, 1e-9);
        }

        check(nativeIrfft.length).equals(dartIrfft.length);
        for (var i = 0; i < realSignal.length; i++) {
          check(nativeIrfft[i]).isCloseTo(realSignal[i], 1e-9);
        }
      }
    });

    test('AccelerationMode.accelerated throws if unavailable', () {
      if (!AccelerationManager.isFftAvailable) {
        AccelerationManager.mode = AccelerationMode.accelerated;
        check(() => AccelerationManager.fft([Complex.one, Complex.zero]))
            .throws<StateError>();
      }
    });
  });
}
