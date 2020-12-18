import 'dart:math';

import 'package:meta/meta.dart';

@immutable
abstract class Distribution<T extends num> {
  const Distribution();

  /// Returns the lower bound of the distribution.
  T get min;

  /// Returns the upper bound of the distribution.
  T get max;

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
  /// [p].
  T inverseCumulativeProbability(num p);

  /// The Survival Function (SF), or Complementary cumulative distribution
  /// function.
  ///
  /// Returns the probability of a random variable to be larger than [x].
  double survival(T x) => 1.0 - cumulativeProbability(x);

  /// Inverse Survival Function (ISF).
  ///
  /// Returns the value of `x` for which the survival probably density is [p].
  T inverseSurvival(num p) => inverseCumulativeProbability(1.0 - p);

  /// Returns a random value within the distribution.
  T sample({Random? random});
}
