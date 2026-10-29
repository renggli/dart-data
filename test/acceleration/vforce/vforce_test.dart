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

      final emptyFilter = Float64List(0);
      check(Vforce.convolve(signal: signal, filter: emptyFilter)).isEmpty();
      check(Vforce.correlate(signal: signal, filter: emptyFilter)).isEmpty();

      final providedOut = Float64List(5);
      final emptyConv = Vforce.convolve(
        signal: signal,
        filter: emptyFilter,
        output: providedOut,
      );
      check(emptyConv).identicalTo(providedOut);
      final emptyCorr = Vforce.correlate(
        signal: signal,
        filter: emptyFilter,
        output: providedOut,
      );
      check(emptyCorr).identicalTo(providedOut);
    });

    accelerationTest('convolve and correlate with memory aliasing', () {
      // Signal length 4, filter length 3. Result length = 4 - 3 + 1 = 2.
      // Aliasing output in buffer:
      final buffer = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final filter = Float64List.fromList([1.0, 2.0, 3.0]);
      // Convolve:
      // n=0: signal[0]*filter[2] + signal[1]*filter[1] + signal[2]*filter[0] = 1*3 + 2*2 + 3*1 = 10
      // n=1: signal[1]*filter[2] + signal[2]*filter[1] + signal[3]*filter[0] = 2*3 + 3*2 + 4*1 = 16
      // If output aliases signal, buffer[0] becomes 10. When n=1 is calculated, if not using a copy,
      // signal[0] is not read, but what if output is offset?
      // With output at sublistView(buffer, 1):
      final subOut = Float64List.sublistView(buffer, 1, 3);
      // n=0 writes to buffer[1]!
      // n=0: signal[0]*3 + signal[1]*2 + signal[2]*1 = 1*3 + 2*2 + 3*1 = 10. Writes to buffer[1] = 10.
      // n=1: signal[1]*3 + signal[2]*2 + signal[3]*1. If buffer[1] was clobbered to 10,
      // then 10*3 + 3*2 + 4*1 = 40 (wrong!) instead of 2*3 + 3*2 + 4*1 = 16.
      final resConv = Vforce.convolve(
        signal: buffer,
        filter: filter,
        output: subOut,
      );
      check(resConv).identicalTo(subOut);
      check(subOut[0]).isCloseTo(10.0, 1e-9);
      check(subOut[1]).isCloseTo(16.0, 1e-9);
    });

    test('validates buffer lengths', () {
      final input = Float64List.fromList([1.0, 2.0, 3.0]);
      final tooSmall = Float64List(2);
      check(() => Vforce.vsin(input: input, output: tooSmall))
          .throws<RangeError>();
      check(() => Vforce.vcos(input: input, output: tooSmall))
          .throws<RangeError>();
      check(() => Vforce.vexp(input: input, output: tooSmall))
          .throws<RangeError>();
      check(() => Vforce.vlog(input: input, output: tooSmall))
          .throws<RangeError>();
      check(() => Vforce.vsqrt(input: input, output: tooSmall))
          .throws<RangeError>();

      final expMismatch = Float64List.fromList([1.0, 2.0]);
      check(() => Vforce.vpow(base: input, exponent: expMismatch))
          .throws<ArgumentError>();
      check(() => Vforce.vpow(base: input, exponent: input, output: tooSmall))
          .throws<RangeError>();

      final filter = Float64List.fromList([0.5, 0.5]);
      // result length is 3 - 2 + 1 = 2
      final convTooSmall = Float64List(1);
      check(
        () => Vforce.convolve(
          signal: input,
          filter: filter,
          output: convTooSmall,
        ),
      ).throws<RangeError>();
      check(
        () => Vforce.correlate(
          signal: input,
          filter: filter,
          output: convTooSmall,
        ),
      ).throws<RangeError>();
    });
  });
}
