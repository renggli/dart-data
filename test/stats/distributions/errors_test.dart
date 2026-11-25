import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('InvalidProbability', () {
    test('constructs with probability and optional name', () {
      final error = InvalidProbability(1.5, 'p');
      check(error.probability).equals(1.5);
      check(error.name).equals('p');
      check(error.message).equals('Invalid probability');
    });

    test('check accepts boundary and interior probabilities', () {
      InvalidProbability.check(0);
      InvalidProbability.check(0.0);
      InvalidProbability.check(0.5);
      InvalidProbability.check(1);
      InvalidProbability.check(1.0);
    });

    test('check rejects out-of-range and NaN probabilities', () {
      check(() => InvalidProbability.check(-0.01)).throws<InvalidProbability>();
      check(() => InvalidProbability.check(1.01)).throws<InvalidProbability>();
      check(() => InvalidProbability.check(double.nan))
          .throws<InvalidProbability>();
      check(() => InvalidProbability.check(double.infinity))
          .throws<InvalidProbability>();
      check(() => InvalidProbability.check(double.negativeInfinity))
          .throws<InvalidProbability>();
    });
  });
}
