import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Vforce Vector Math & Reductions', () {
    accelerationTest('transcendental functions elementwise and in-place', () {
      final input = Float64List.fromList([0.0, math.pi / 2, math.pi]);
      final output = Float64List(3);
      final res = Vforce.vsin(input: input, output: output);
      check(res).identicalTo(output);
      check(output[0]).isCloseTo(0.0, 1e-9);
      check(output[1]).isCloseTo(1.0, 1e-9);

      // In-place
      Vforce.vcos(input: input, output: input);
      check(input[0]).isCloseTo(1.0, 1e-9);
      check(input[1]).isCloseTo(0.0, 1e-9);
    });

    accelerationTest('vexp, vlog, vsqrt, vpow', () {
      final vals = Float64List.fromList([1.0, 4.0, 9.0]);
      final sqrtVals = Vforce.vsqrt(input: vals);
      check(sqrtVals[0]).isCloseTo(1.0, 1e-9);
      check(sqrtVals[1]).isCloseTo(2.0, 1e-9);
      check(sqrtVals[2]).isCloseTo(3.0, 1e-9);

      final expVals = Vforce.vexp(input: Float64List.fromList([0.0, 1.0]));
      check(expVals[0]).isCloseTo(1.0, 1e-9);
      check(expVals[1]).isCloseTo(math.e, 1e-9);

      final logVals = Vforce.vlog(input: expVals);
      check(logVals[0]).isCloseTo(0.0, 1e-9);
      check(logVals[1]).isCloseTo(1.0, 1e-9);

      final powVals = Vforce.vpow(
        base: Float64List.fromList([2.0, 3.0]),
        exponent: Float64List.fromList([3.0, 2.0]),
      );
      check(powVals[0]).isCloseTo(8.0, 1e-9);
      check(powVals[1]).isCloseTo(9.0, 1e-9);
    });

    accelerationTest('sum, mean, and variance reductions', () {
      final data = Float64List.fromList([
        2.0,
        4.0,
        4.0,
        4.0,
        5.0,
        5.0,
        7.0,
        9.0,
      ]);
      check(Vforce.sum(x: data)).isCloseTo(40.0, 1e-9);
      check(Vforce.mean(x: data)).isCloseTo(5.0, 1e-9);
      check(Vforce.variance(x: data, sample: true))
          .isCloseTo(4.5714285714, 1e-7);
      check(Vforce.variance(x: data, sample: false)).isCloseTo(4.0, 1e-7);
    });

    accelerationTest('1D convolution and cross-correlation', () {
      final signal = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final filter = Float64List.fromList([0.5, 0.5]);

      final conv = Vforce.convolve(signal: signal, filter: filter);
      check(conv.length).equals(3);
      check(conv[0]).isCloseTo(1.5, 1e-9);
      check(conv[1]).isCloseTo(2.5, 1e-9);
      check(conv[2]).isCloseTo(3.5, 1e-9);

      final corr = Vforce.correlate(signal: signal, filter: filter);
      check(corr.length).equals(3);
      check(corr[0]).isCloseTo(1.5, 1e-9);
      check(corr[1]).isCloseTo(2.5, 1e-9);
      check(corr[2]).isCloseTo(3.5, 1e-9);
    });
  });
}
