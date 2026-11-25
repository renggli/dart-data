import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

class _GenericDiscrete extends DiscreteDistribution {
  const new(this.min, this.max);

  final int min;
  final int max;

  @override
  int get lowerBound => min;

  @override
  bool get isLowerBoundOpen => false;

  @override
  int get upperBound => max;

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => 0.5 * min + 0.5 * max;

  @override
  double get median => mean;

  @override
  double get mode => double.nan;

  @override
  double get variance {
    final count = (max - min + 1).toDouble();
    return (count * count - 1.0) / 12.0;
  }

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => -1.2;

  @override
  double probability(int k) => k < min || k > max ? 0.0 : 1.0 / (max - min + 1);

  @override
  int sample({math.Random? random}) => min;
}

class _UnboundedDiscrete extends DiscreteDistribution {
  const new();

  @override
  double get mean => double.nan;

  @override
  double get median => 0.0;

  @override
  double get mode => 0.0;

  @override
  double get variance => double.infinity;

  @override
  double get skewness => double.nan;

  @override
  double get excessKurtosis => double.nan;

  @override
  double cumulativeProbability(int k) =>
      k < 0 ? 0.0 : 1.0 - math.pow(0.5, k + 1);

  @override
  int sample({math.Random? random}) => 0;
}

class _LargeRangeDiscrete extends DiscreteDistribution {
  const new();

  @override
  int get lowerBound => 0;

  @override
  int get upperBound => 1000000;

  @override
  double get mean => 500000.0;

  @override
  double get median => 500000.0;

  @override
  double get mode => 500000.0;

  @override
  double get variance => double.infinity;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => 0.0;

  @override
  double cumulativeProbability(int k) {
    if (k < 0) return 0.0;
    if (k >= 1000000) return 1.0;
    return (k + 1) / 1000001.0;
  }

  @override
  int sample({math.Random? random}) => 0;
}

class _NegativeLargeRangeDiscrete extends DiscreteDistribution {
  const new();

  @override
  int get lowerBound => -1000000;

  @override
  int get upperBound => -1;

  @override
  double get mean => double.nan;

  @override
  double get median => -500000.5;

  @override
  double get mode => double.nan;

  @override
  double get variance => double.infinity;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => 0.0;

  @override
  double cumulativeProbability(int k) {
    if (k < -1000000) return 0.0;
    if (k >= -1) return 1.0;
    return (k + 1000001) / 1000000.0;
  }

  @override
  int sample({math.Random? random}) => -1;
}

class _ShiftedBoundsDiscrete extends DiscreteDistribution {
  const new(this.min, this.max);

  final int min;
  final int max;

  @override
  int get lowerBound => min;

  @override
  bool get isLowerBoundOpen => false;

  @override
  int get upperBound => max;

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => double.nan;

  @override
  double get median => mean;

  @override
  double get mode => double.nan;

  @override
  double get variance => double.nan;

  @override
  double get skewness => 0.0;

  @override
  double get excessKurtosis => 0.0;

  @override
  double cumulativeProbability(int k) {
    if (k < min) return 0.0;
    if (k >= max) return 1.0;
    return (k - min + 1) / (max - min + 1);
  }

  @override
  int sample({math.Random? random}) => min;
}

void main() {
  group('DiscreteDistribution defaults and bounds', () {
    test('defaults bounds to safeMin and safeMax', () {
      const dist = _UnboundedDiscrete();
      check(dist.lowerBound).equals(DataType.integer.safeMin);
      check(dist.isLowerBoundOpen).isTrue;
      check(dist.upperBound).equals(DataType.integer.safeMax);
      check(dist.isUpperBoundOpen).isTrue;
      check(dist.probability(-1)).equals(0.0);
      check(dist.probability(0)).equals(0.5);
      check(dist.probability(1)).equals(0.25);
    });

    test('computes default cumulativeProbability from probability sum', () {
      const dist = _GenericDiscrete(1, 5);
      check(dist.cumulativeProbability(0)).equals(0.0);
      check(dist.cumulativeProbability(3)).isCloseTo(0.6, 1e-12);
      check(dist.cumulativeProbability(5)).equals(1.0);
      check(dist.cumulativeProbability(6)).equals(1.0);
    });
  });

  group('DiscreteDistribution inverseCumulativeProbability', () {
    test('brackets and resolves small and negative-crossing supports', () {
      const dist = _GenericDiscrete(-2, 2);
      check(dist.inverseCumulativeProbability(0.0)).equals(-2);
      check(dist.inverseCumulativeProbability(0.2)).equals(-2);
      check(dist.inverseCumulativeProbability(0.5)).equals(0);
      check(dist.inverseCumulativeProbability(0.9)).equals(2);
      check(dist.inverseCumulativeProbability(1.0)).equals(2);
    });

    test('uses open upperBound and shifted-bound fallbacks', () {
      const unbounded = _UnboundedDiscrete();
      check(unbounded.inverseCumulativeProbability(0.5)).equals(0);
      check(unbounded.inverseCumulativeProbability(0.875)).equals(2);
      check(unbounded.inverseCumulativeProbability(1.0))
          .equals(DataType.integer.safeMax);

      const positiveOnly = _ShiftedBoundsDiscrete(5, 10);
      check(positiveOnly.inverseCumulativeProbability(0.5)).equals(7);
      check(positiveOnly.inverseCumulativeProbability(1.0)).equals(10);

      const negativeOnly = _ShiftedBoundsDiscrete(-10, -5);
      check(negativeOnly.inverseCumulativeProbability(0.5)).equals(-8);
      check(negativeOnly.inverseCumulativeProbability(1.0)).equals(-5);
    });

    test(
      'exponentially steps across large ranges when variance is infinite',
      () {
        const large = _LargeRangeDiscrete();
        check(large.inverseCumulativeProbability(0.75)).equals(750000);
        check(large.inverseCumulativeProbability(0.1)).equals(100000);

        const negLarge = _NegativeLargeRangeDiscrete();
        check(negLarge.inverseCumulativeProbability(0.1)).equals(-900001);
        check(negLarge.inverseSurvival(0.25)).equals(-250001);
      },
    );
  });

  group('DiscreteDistribution inverseSurvival', () {
    test('handles closed and open upper bounds and tail searches', () {
      const closed = _GenericDiscrete(-2, 2);
      check(closed.inverseSurvival(0.8)).equals(-2);
      check(closed.inverseSurvival(0.2)).equals(1);
      check(closed.inverseSurvival(0.0)).equals(2);
      check(() => closed.inverseSurvival(-0.1)).throws<InvalidProbability>();

      const unbounded = _UnboundedDiscrete();
      check(unbounded.inverseSurvival(0.0)).equals(DataType.integer.safeMax);
      check(unbounded.inverseSurvival(0.25)).equals(1);

      const positiveOnly = _ShiftedBoundsDiscrete(5, 10);
      check(positiveOnly.inverseSurvival(0.25)).equals(9);

      const negativeOnly = _ShiftedBoundsDiscrete(-10, -5);
      check(negativeOnly.inverseSurvival(0.25)).equals(-6);

      const large = _LargeRangeDiscrete();
      check(large.inverseSurvival(0.1)).equals(900000);
    });
  });
}
