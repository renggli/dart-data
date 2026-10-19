import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('vForce and vDSP Vector Operations', () {
    test('isVForceAvailable reports platform status', () {
      check(AccelerationManager.isVForceAvailable).isA<bool>();
    });

    accelerationTest(
      'elementwise transcendentals (sin, cos, exp, log, sqrt, pow)',
      () {
        const n = 128;
        final input = Float64List(n);
        final exponents = Float64List(n);
        for (var i = 0; i < n; i++) {
          input[i] = 0.1 + i * 0.05;
          exponents[i] = 1.5;
        }

        final sinRes = AccelerationManager.vsin(input);
        final cosRes = AccelerationManager.vcos(input);
        final expRes = AccelerationManager.vexp(input);
        final logRes = AccelerationManager.vlog(input);
        final sqrtRes = AccelerationManager.vsqrt(input);
        final powRes = AccelerationManager.vpow(input, exponents);

        for (var i = 0; i < n; i++) {
          check(sinRes[i]).isCloseTo(math.sin(input[i]), 1e-12);
          check(cosRes[i]).isCloseTo(math.cos(input[i]), 1e-12);
          check(expRes[i]).isCloseTo(math.exp(input[i]), 1e-10);
          check(logRes[i]).isCloseTo(math.log(input[i]), 1e-12);
          check(sqrtRes[i]).isCloseTo(math.sqrt(input[i]), 1e-12);
          check(powRes[i])
              .isCloseTo(math.pow(input[i], exponents[i]).toDouble(), 1e-10);
        }
      },
      isSupported: AccelerationManager.isVForceAvailable,
    );

    accelerationTest('vector reductions (sum, mean, variance)', () {
      const n = 256;
      final x = Float64List(n);
      for (var i = 0; i < n; i++) {
        x[i] = (i + 1) * 0.25;
      }

      final sum = AccelerationManager.sum(x);
      final mean = AccelerationManager.mean(x);
      final variance = AccelerationManager.variance(x, sample: true);

      check(sum).isCloseTo(8224.0, 1e-8);
      check(mean).isCloseTo(32.125, 1e-8);
      check(variance).isCloseTo(342.666666666667, 1e-6);
    }, isSupported: AccelerationManager.isVdspAvailable);

    accelerationTest('variance numerical stability with large offset', () {
      const n = 128;
      final x = Float64List(n);
      for (var i = 0; i < n; i++) {
        x[i] = 1e9 + i;
      }

      final variance = AccelerationManager.variance(x, sample: true);
      check(variance).isCloseTo(1376.0, 1e-4);
    }, isSupported: AccelerationManager.isVdspAvailable);

    accelerationTest('convolve and correlate', () {
      final signal = Float64List.fromList([
        for (var i = 0; i < 100; i++) (i + 1).toDouble(),
      ]);
      final filter = Float64List.fromList([1.0, 0.5, -0.5, 2.0, -1.0]);

      final conv = AccelerationManager.convolve(signal, filter);
      final corr = AccelerationManager.correlate(signal, filter);

      check(conv.length).equals(signal.length - filter.length + 1);
      check(corr.length).equals(signal.length - filter.length + 1);

      check(conv[0]).isCloseTo(8.5, 1e-9);
      check(corr[0]).isCloseTo(3.5, 1e-9);
    }, isSupported: AccelerationManager.isVdspAvailable);
  });
}
