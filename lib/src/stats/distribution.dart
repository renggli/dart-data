import 'dart:math';

import 'package:data/src/stats/distributions/errors.dart';
import 'package:meta/meta.dart';

import 'distributions/continuous/uniform.dart';

@immutable
abstract class Distribution<T extends num> {
  const Distribution();

  /// Returns the lower bound of the distribution.
  T get lowerBound;

  /// Returns true, if the lower bound is open.
  bool get isLowerBoundOpen;

  /// Returns the upper bound of the distribution.
  T get upperBound;

  /// Returns true, if the upper bound is open.
  bool get isUpperBoundOpen;

  /// Returns the mean value of the distribution.
  double get mean;

  /// Returns the median value of the distribution.
  double get median;

  /// Returns the expected variance.
  double get variance;

  /// Returns the expected standard deviation.
  double get standardDeviation => sqrt(variance);

  /// The Probability Density/Mass Function (PDF/PMF).
  ///
  /// Returns the probability of the distribution at [x].
  double probability(T x);

  /// The Cumulative Distribution Function (CDF).
  ///
  /// Returns the cumulative probability at [x], or the probability of a random
  /// variable to be less than or equal to [x].
  double cumulativeProbability(T x);

  /// The Inverse Cumulative Distribution Function (PPT), or quantile function.
  ///
  /// Returns the value of `x` for which the cumulative probability density is
  /// [p]. Throws [InvalidProbability], if [p] is out of range.
  T inverseCumulativeProbability(num p);

  /// The Survival Function (SF), or Complementary cumulative distribution
  /// function.
  ///
  /// Returns the probability of a random variable to be larger than [x].
  double survival(T x) => 1.0 - cumulativeProbability(x);

  /// Inverse Survival Function (ISF).
  ///
  /// Returns the value of `x` for which the survival probably density is
  /// [p]. Throws [InvalidProbability], if [p] is out of range.
  T inverseSurvival(num p) {
    InvalidProbability.check(p);
    return inverseCumulativeProbability(1.0 - p);
  }

  /// Returns a single sample of a random value within the distribution.
  T sample({Random? random}) {
    const uniform = UniformDistribution(0, 1);
    final probability = uniform.sample(random: random);
    return inverseCumulativeProbability(probability);
  }

  /// Returns an infinite source of random samples within the distribution.
  Iterable<T> samples({Random? random}) sync* {
    for (;;) {
      yield sample(random: random);
    }
  }
}
