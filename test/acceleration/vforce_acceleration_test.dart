import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

void main() {
  group('vForce and vDSP Vector Operations Parity and Modes', () {
    final originalMode = AccelerationManager.mode;

    tearDown(() {
      AccelerationManager.mode = originalMode;
    });

    test('isVForceAvailable reports platform status', () {
      if (AccelerationManager.isNativeAvailable) {
        check(AccelerationManager.isVForceAvailable).isTrue();
      }
    });

    test(
      'elementwise transcendentals parity (sin, cos, exp, log, sqrt, pow)',
      () {
        const n = 128;
        final input = Float64List(n);
        final exponents = Float64List(n);
        for (var i = 0; i < n; i++) {
          input[i] = 0.1 + i * 0.05;
          exponents[i] = 1.5;
        }

        AccelerationManager.mode = AccelerationMode.dart;
        final dartSin = AccelerationManager.vsin(input);
        final dartCos = AccelerationManager.vcos(input);
        final dartExp = AccelerationManager.vexp(input);
        final dartLog = AccelerationManager.vlog(input);
        final dartSqrt = AccelerationManager.vsqrt(input);
        final dartPow = AccelerationManager.vpow(input, exponents);

        if (AccelerationManager.isVForceAvailable) {
          AccelerationManager.mode = AccelerationMode.accelerated;
          final nativeSin = AccelerationManager.vsin(input);
          final nativeCos = AccelerationManager.vcos(input);
          final nativeExp = AccelerationManager.vexp(input);
          final nativeLog = AccelerationManager.vlog(input);
          final nativeSqrt = AccelerationManager.vsqrt(input);
          final nativePow = AccelerationManager.vpow(input, exponents);

          for (var i = 0; i < n; i++) {
            check(nativeSin[i]).isCloseTo(dartSin[i], 1e-12);
            check(nativeCos[i]).isCloseTo(dartCos[i], 1e-12);
            check(nativeExp[i]).isCloseTo(dartExp[i], 1e-10);
            check(nativeLog[i]).isCloseTo(dartLog[i], 1e-12);
            check(nativeSqrt[i]).isCloseTo(dartSqrt[i], 1e-12);
            check(nativePow[i]).isCloseTo(dartPow[i], 1e-10);
          }
        }
      },
    );

    test('vector reductions parity (sum, mean, variance)', () {
      const n = 256;
      final x = Float64List(n);
      for (var i = 0; i < n; i++) {
        x[i] = (i + 1) * 0.25;
      }

      AccelerationManager.mode = AccelerationMode.dart;
      final dartSum = AccelerationManager.sum(x);
      final dartMean = AccelerationManager.mean(x);
      final dartVar = AccelerationManager.variance(x, sample: true);

      if (AccelerationManager.isVdspAvailable) {
        AccelerationManager.mode = AccelerationMode.accelerated;
        final nativeSum = AccelerationManager.sum(x);
        final nativeMean = AccelerationManager.mean(x);
        final nativeVar = AccelerationManager.variance(x, sample: true);

        check(nativeSum).isCloseTo(dartSum, 1e-8);
        check(nativeMean).isCloseTo(dartMean, 1e-8);
        check(nativeVar).isCloseTo(dartVar, 1e-6);
      }
    });

    test('AccelerationMode.accelerated throws if unavailable', () {
      if (!AccelerationManager.isVForceAvailable) {
        AccelerationManager.mode = AccelerationMode.accelerated;
        check(() => AccelerationManager.vsin(Float64List(10)))
            .throws<StateError>();
      }
    });
  });
}
