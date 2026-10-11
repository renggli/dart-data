import 'dart:math';

import 'package:checks/checks.dart';
import 'package:data/src/stats/distributions/multivariate/multivariate_normal.dart';
import 'package:test/test.dart';

void main() {
  group('MultivariateDistribution', () {
    test('samples generates lazy iterable', () {
      final dist = MultivariateNormalDistribution.standard(3);
      final sequence = dist.samples(random: Random(42)).take(5).toList();

      check(sequence.length).equals(5);
      for (final vec in sequence) {
        check(vec.length).equals(3);
      }
    });
  });
}
