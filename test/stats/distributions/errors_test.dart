import 'package:checks/checks.dart';
import 'package:data/src/stats/distributions/errors.dart';
import 'package:test/test.dart';

void main() {
  group('InvalidProbability', () {
    test('check accepts valid probabilities [0, 1]', () {
      InvalidProbability.check(0.0);
      InvalidProbability.check(0.5);
      InvalidProbability.check(1.0);
      InvalidProbability.check(0);
      InvalidProbability.check(1);
    });

    test('check throws on out-of-range probabilities', () {
      check(() => InvalidProbability.check(-0.01))
          .throws<InvalidProbability>()
          .has((e) => e.probability, 'probability')
          .equals(-0.01);
      check(() => InvalidProbability.check(1.01))
          .throws<InvalidProbability>()
          .has((e) => e.probability, 'probability')
          .equals(1.01);
    });

    test('constructor properties', () {
      final err = InvalidProbability(2.5, 'p');
      check(err.probability).equals(2.5);
      check(err.name).equals('p');
      check(err.message).equals('Invalid probability');
    });
  });
}
