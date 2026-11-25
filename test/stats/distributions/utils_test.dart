import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/stats/distributions/utils.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('defaultRandom', () {
    test('returns finite unit doubles', () {
      for (var i = 0; i < 10; i++) {
        final value = defaultRandom.nextDouble();
        check(value).isGreaterOrEqual(0.0);
        check(value).isLessThan(1.0);
      }
    });
  });

  group('expm1', () {
    test('handles special values and small arguments accurately', () {
      check(expm1(double.nan).isNaN).isTrue;
      check(expm1(0.0)).equals(0.0);
      check(expm1(-0.0)).equals(0.0);
      check(expm1(double.infinity)).equals(double.infinity);
      check(expm1(double.negativeInfinity)).equals(-1.0);
      check(expm1(1e-12)).isCloseTo(1e-12, 1e-24);
      check(expm1(-1e-12)).isCloseTo(-1e-12, 1e-24);
      check(expm1(1.0)).isCloseTo(math.e - 1.0, 1e-15);
      check(expm1(-1.0)).isCloseTo(1.0 / math.e - 1.0, 1e-15);
    });
  });

  group('nextOpenUnit', () {
    test('skips exact zeros and returns values in (0, 1)', () {
      final value = nextOpenUnit(_ZeroThenValueRandom(const [0.0, 0.0, 0.25]));
      check(value).equals(0.25);

      final rng = math.Random(42);
      for (var i = 0; i < 50; i++) {
        final u = nextOpenUnit(rng);
        check(u).isGreaterThan(0.0);
        check(u).isLessThan(1.0);
      }
    });
  });

  group('welfordSampleStats', () {
    test('computes count, mean, and unbiased variance in one pass', () {
      final single = welfordSampleStats(const [42]);
      check(single.count).equals(1);
      check(single.mean).equals(42.0);
      check(single.variance).equals(0.0);

      final stats = welfordSampleStats(const [
        2.0,
        4.0,
        4.0,
        4.0,
        5.0,
        5.0,
        7.0,
        9.0,
      ]);
      check(stats.count).equals(8);
      check(stats.mean).equals(5.0);
      check(stats.variance).isCloseTo(32.0 / 7.0, 1e-12);
    });

    test('validates finiteness, custom predicate, and minimum count', () {
      check(() => welfordSampleStats(const [])).throws<ArgumentError>();
      check(() => welfordSampleStats(const [1.0], minCount: 2))
          .throws<ArgumentError>();
      check(() => welfordSampleStats(const [1.0, double.nan]))
          .throws<ArgumentError>();
      check(() => welfordSampleStats(const [1.0, double.infinity]))
          .throws<ArgumentError>();
      check(
        () => welfordSampleStats(
          const [1.0, -1.0],
          isValid: (v) => v > 0.0,
          invalidMessage: 'Samples must be positive',
        ),
      ).throws<ArgumentError>();
    });
  });
}

class _ZeroThenValueRandom implements math.Random {
  new(this._values);

  final List<double> _values;
  var _index = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => _values[_index++];

  @override
  int nextInt(int max) => 0;
}
