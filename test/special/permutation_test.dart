import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('permutation', () {
    test('permutation and permutationLn', () {
      check(permutation(5, 2)).equals(20.0);
      check(permutation(10, 3)).equals(720.0);
      check(permutation(20, 3)).equals(6840.0);
      check(permutation(50, 10)).isCloseTo(3.7276043023296e16, 1e10);
      check(permutation(200, 2)).equals(39800.0);
      check(permutation(5, 0)).equals(1.0);
      check(permutation(5, 6)).equals(0.0);
      check(permutation(5, -1)).equals(0.0);
      check(permutation(double.nan, 2)).isNaN;
      check(permutation(5, double.nan)).isNaN;
      check(permutation(double.infinity, 2)).equals(double.infinity);
      check(permutation(double.infinity, double.infinity)).isNaN;
      check(permutationLn(5, 2)).isCloseTo(math.log(20.0), 1e-6);
    });
  });
}
