import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/vforce/vforce_dart.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('VforceDart Edge Cases', () {
    test('mean on empty list returns NaN', () {
      final empty = Float64List(0);
      check(VforceDart.mean(x: empty, n: 0)).isNaN;
    });

    test('variance on empty or single element list', () {
      final empty = Float64List(0);
      check(VforceDart.variance(x: empty, n: 0, sample: true)).isNaN;

      final single = Float64List.fromList([42.0]);
      check(VforceDart.variance(x: single, n: 1, sample: true)).isNaN;
      check(VforceDart.variance(x: single, n: 1, sample: false)).equals(0.0);
    });

    test('variance avoids sum-of-squares overflow on huge values', () {
      final huge = Float64List.fromList(
        List<double>.generate(20, (i) => i.isEven ? 0.0 : 6e153),
      );
      final popVar = VforceDart.variance(
        x: huge,
        n: huge.length,
        sample: false,
      );
      check(popVar.isFinite).isTrue;
      check(popVar).isCloseTo(9e306, 1e294);
    });

    test('convolve and correlate with invalid/short filter', () {
      final signal = Float64List.fromList([1.0, 2.0]);
      final filter = Float64List.fromList([1.0, 2.0, 3.0]);
      final out = Float64List(0);
      VforceDart.convolve(
        signal: signal,
        filter: filter,
        output: out,
        resultLength: 0,
      );
      check(out.length).equals(0);
    });

    test('convolve and correlate handle aliased signal and filter views', () {
      final signal = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final filter = Float64List.fromList([1.0, 2.0, 3.0]);
      final convOut = Float64List.sublistView(signal, 1, 3);
      VforceDart.convolve(
        signal: signal,
        filter: filter,
        output: convOut,
        resultLength: 2,
      );
      check(convOut[0]).isCloseTo(10.0, 1e-10);
      check(convOut[1]).isCloseTo(16.0, 1e-10);

      final signal2 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final corrOut = Float64List.sublistView(signal2, 1, 3);
      VforceDart.correlate(
        signal: signal2,
        filter: filter,
        output: corrOut,
        resultLength: 2,
      );
      check(corrOut[0]).isCloseTo(14.0, 1e-10);
      check(corrOut[1]).isCloseTo(20.0, 1e-10);

      final filterBuf = Float64List.fromList([1.0, 2.0, 3.0]);
      final filterOut = Float64List.sublistView(filterBuf, 0, 1);
      VforceDart.convolve(
        signal: Float64List.fromList([1.0, 2.0, 3.0]),
        filter: filterBuf,
        output: filterOut,
        resultLength: 1,
      );
      check(filterOut[0]).isCloseTo(10.0, 1e-10);

      final filterBuf2 = Float64List.fromList([1.0, 2.0, 3.0]);
      final filterOut2 = Float64List.sublistView(filterBuf2, 0, 1);
      VforceDart.correlate(
        signal: Float64List.fromList([1.0, 2.0, 3.0]),
        filter: filterBuf2,
        output: filterOut2,
        resultLength: 1,
      );
      check(filterOut2[0]).isCloseTo(14.0, 1e-10);
    });

    test('mean and variance avoid overflow on extreme finite inputs', () {
      final maxPair = Float64List.fromList([1e308, 1e308]);
      check(VforceDart.mean(x: maxPair, n: 2)).isCloseTo(1e308, 1e294);
      check(VforceDart.variance(x: maxPair, n: 2, sample: true)).equals(0.0);
      check(VforceDart.variance(x: maxPair, n: 2, sample: false)).equals(0.0);

      final symmetricMax = Float64List.fromList([-1e308, 1e308]);
      check(VforceDart.mean(x: symmetricMax, n: 2)).equals(0.0);

      final spread = Float64List.fromList([-1e155, 1e155]);
      final sampleVar = VforceDart.variance(x: spread, n: 2, sample: true);
      check(sampleVar).equals(double.infinity);
    });
  });
}
