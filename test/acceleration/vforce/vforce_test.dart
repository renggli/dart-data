import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/scaffolding.dart';

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

      // Shifted overlapping alias: output starts 1 element after input.
      final aliasBuf = Float64List.fromList([0.0, 1.0, 2.0, 3.0]);
      final aliasIn = Float64List.sublistView(aliasBuf, 0, 3);
      final aliasOut = Float64List.sublistView(aliasBuf, 1, 4);
      Vforce.vexp(input: aliasIn, output: aliasOut);
      check(aliasOut[0]).isCloseTo(math.exp(0.0), 1e-9);
      check(aliasOut[1]).isCloseTo(math.exp(1.0), 1e-9);
      check(aliasOut[2]).isCloseTo(math.exp(2.0), 1e-9);

      final sinBuf = Float64List.fromList([0.0, 0.5, 1.0, 1.5]);
      final sinIn = Float64List.sublistView(sinBuf, 0, 3);
      final sinOut = Float64List.sublistView(sinBuf, 1, 4);
      Vforce.vsin(input: sinIn, output: sinOut);
      check(sinOut[0]).isCloseTo(math.sin(0.0), 1e-9);
      check(sinOut[1]).isCloseTo(math.sin(0.5), 1e-9);
      check(sinOut[2]).isCloseTo(math.sin(1.0), 1e-9);

      final cosBuf = Float64List.fromList([0.0, 0.5, 1.0, 1.5]);
      final cosIn = Float64List.sublistView(cosBuf, 0, 3);
      final cosOut = Float64List.sublistView(cosBuf, 1, 4);
      Vforce.vcos(input: cosIn, output: cosOut);
      check(cosOut[0]).isCloseTo(math.cos(0.0), 1e-9);
      check(cosOut[1]).isCloseTo(math.cos(0.5), 1e-9);
      check(cosOut[2]).isCloseTo(math.cos(1.0), 1e-9);

      final logBuf = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final logIn = Float64List.sublistView(logBuf, 0, 3);
      final logOut = Float64List.sublistView(logBuf, 1, 4);
      Vforce.vlog(input: logIn, output: logOut);
      check(logOut[0]).isCloseTo(math.log(1.0), 1e-9);
      check(logOut[1]).isCloseTo(math.log(2.0), 1e-9);
      check(logOut[2]).isCloseTo(math.log(3.0), 1e-9);

      final sqrtBuf = Float64List.fromList([1.0, 4.0, 9.0, 16.0]);
      final sqrtIn = Float64List.sublistView(sqrtBuf, 0, 3);
      final sqrtOut = Float64List.sublistView(sqrtBuf, 1, 4);
      Vforce.vsqrt(input: sqrtIn, output: sqrtOut);
      check(sqrtOut[0]).isCloseTo(1.0, 1e-9);
      check(sqrtOut[1]).isCloseTo(2.0, 1e-9);
      check(sqrtOut[2]).isCloseTo(3.0, 1e-9);

      // Empty inputs are safe no-ops across unary and vpow ops.
      final empty = Float64List(0);
      check(Vforce.vsin(input: empty)).isEmpty;
      check(Vforce.vcos(input: empty)).isEmpty;
      check(Vforce.vexp(input: empty)).isEmpty;
      check(Vforce.vlog(input: empty)).isEmpty;
      check(Vforce.vsqrt(input: empty)).isEmpty;
      check(Vforce.vpow(base: empty, exponent: empty)).isEmpty;
    }, isSupported: Vforce.isAvailable);

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

      // In-place and shifted overlapping alias for vpow
      final powInPlace = Float64List.fromList([2.0, 3.0]);
      Vforce.vpow(
        base: powInPlace,
        exponent: Float64List.fromList([3.0, 2.0]),
        output: powInPlace,
      );
      check(powInPlace[0]).isCloseTo(8.0, 1e-9);
      check(powInPlace[1]).isCloseTo(9.0, 1e-9);

      final powBuf = Float64List.fromList([2.0, 3.0, 4.0, 5.0]);
      final powBase = Float64List.sublistView(powBuf, 0, 3);
      final powExp = Float64List.fromList([2.0, 2.0, 2.0]);
      final powAliasOut = Float64List.sublistView(powBuf, 1, 4);
      Vforce.vpow(base: powBase, exponent: powExp, output: powAliasOut);
      check(powAliasOut[0]).isCloseTo(4.0, 1e-9);
      check(powAliasOut[1]).isCloseTo(9.0, 1e-9);
      check(powAliasOut[2]).isCloseTo(16.0, 1e-9);

      final powExpBuf = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final powExpAlias = Float64List.sublistView(powExpBuf, 0, 3);
      final powExpOut = Float64List.sublistView(powExpBuf, 1, 4);
      Vforce.vpow(
        base: Float64List.fromList([2.0, 2.0, 2.0]),
        exponent: powExpAlias,
        output: powExpOut,
      );
      check(powExpOut[0]).isCloseTo(2.0, 1e-9);
      check(powExpOut[1]).isCloseTo(4.0, 1e-9);
      check(powExpOut[2]).isCloseTo(8.0, 1e-9);
    }, isSupported: Vforce.isAvailable);

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

      // Extreme finite inputs remain finite without overflow
      final maxPair = Float64List.fromList([1e308, 1e308]);
      check(Vforce.mean(x: maxPair)).isCloseTo(1e308, 1e294);
      check(Vforce.variance(x: maxPair, sample: true)).equals(0.0);
      check(Vforce.variance(x: maxPair, sample: false)).equals(0.0);

      final sym = Float64List.fromList([-1e153, 1e153]);
      check(Vforce.mean(x: sym)).equals(0.0);
      check(Vforce.variance(x: sym, sample: false)).isCloseTo(1e306, 1e292);
    }, isSupported: Vforce.isAvailable);

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
      check(Vforce.convolve(signal: signal, filter: emptyFilter)).isEmpty;
      check(Vforce.correlate(signal: signal, filter: emptyFilter)).isEmpty;

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
    }, isSupported: Vforce.isAvailable);

    accelerationTest('convolve and correlate with memory aliasing', () {
      // Signal length 4, filter length 3. Result length = 4 - 3 + 1 = 2.
      // Aliasing output in buffer:
      final buffer = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final filter = Float64List.fromList([1.0, 2.0, 3.0]);
      // Convolve:
      // n=0: signal[0]*filter[2] + signal[1]*filter[1] + signal[2]*filter[0] = 1*3 + 2*2 + 3*1 = 10
      // n=1: signal[1]*filter[2] + signal[2]*filter[1] + signal[3]*filter[0] = 2*3 + 3*2 + 4*1 = 16
      // With output at sublistView(buffer, 1):
      final subOut = Float64List.sublistView(buffer, 1, 3);
      final resConv = Vforce.convolve(
        signal: buffer,
        filter: filter,
        output: subOut,
      );
      check(resConv).identicalTo(subOut);
      check(subOut[0]).isCloseTo(10.0, 1e-9);
      check(subOut[1]).isCloseTo(16.0, 1e-9);

      // Correlate with aliased signal:
      final buffer2 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final subOut2 = Float64List.sublistView(buffer2, 1, 3);
      // n=0: 1*1 + 2*2 + 3*3 = 14
      // n=1: 2*1 + 3*2 + 4*3 = 20
      final resCorr = Vforce.correlate(
        signal: buffer2,
        filter: filter,
        output: subOut2,
      );
      check(resCorr).identicalTo(subOut2);
      check(subOut2[0]).isCloseTo(14.0, 1e-9);
      check(subOut2[1]).isCloseTo(20.0, 1e-9);

      // Aliasing on filter buffer:
      final filterBuf = Float64List.fromList([1.0, 2.0, 3.0]);
      final signalBuf = Float64List.fromList([1.0, 2.0, 3.0]);
      final filterOut = Float64List.sublistView(filterBuf, 0, 1);
      final resFilter = Vforce.convolve(
        signal: signalBuf,
        filter: filterBuf,
        output: filterOut,
      );
      check(resFilter).identicalTo(filterOut);
      check(filterOut[0]).isCloseTo(10.0, 1e-9);

      // Disjoint views inside the same backing buffer work without error.
      final shared = Float64List.fromList([
        1.0,
        2.0,
        3.0,
        4.0,
        0.5,
        0.5,
        0.0,
        0.0,
        0.0,
      ]);
      final sharedSig = Float64List.sublistView(shared, 0, 4);
      final sharedFlt = Float64List.sublistView(shared, 4, 6);
      final sharedOut = Float64List.sublistView(shared, 6, 9);
      Vforce.convolve(signal: sharedSig, filter: sharedFlt, output: sharedOut);
      check(sharedOut[0]).isCloseTo(1.5, 1e-9);
      check(sharedOut[1]).isCloseTo(2.5, 1e-9);
      check(sharedOut[2]).isCloseTo(3.5, 1e-9);
    }, isSupported: Vforce.isAvailable);

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
