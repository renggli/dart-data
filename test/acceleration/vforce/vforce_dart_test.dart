import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/vforce/vforce_dart.dart';
import 'package:test/test.dart';

void main() {
  group('VforceDart Edge Cases', () {
    test('mean on empty list returns NaN', () {
      final empty = Float64List(0);
      check(VforceDart.mean(x: empty, n: 0)).isNaN();
    });

    test('variance on empty or single element list', () {
      final empty = Float64List(0);
      check(VforceDart.variance(x: empty, n: 0, sample: true)).isNaN();

      final single = Float64List.fromList([42.0]);
      check(VforceDart.variance(x: single, n: 1, sample: true)).isNaN();
      check(VforceDart.variance(x: single, n: 1, sample: false)).equals(0.0);
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
  });
}
