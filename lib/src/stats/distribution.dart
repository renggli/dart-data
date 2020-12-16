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
  double probabilityDistribution(T x);

  /// The Cumulative Distribution Function (CDF).
  ///
  /// Returns the cumulative probability at [x], or the probability of a random
  /// variable to be less than or equal to [x].
  double cumulativeDistribution(T x);

  /// The Inverted Cumulative Distribution Function (INV), or quantile function.
  ///
  /// Returns the value of `x` for which the cumulative probability density is
  /// [p].
  T inverseCumulativeDistribution(double p);

  /// Survival Function (SF), or Complementary cumulative distribution function.
  double survival(T x) => 1.0 - cumulativeDistribution(x);

  /// Inverse Survival Function (ISF).
  T inverseSurvival(double p) => throw UnimplementedError();

  /// Returns a random value within the distribution.
  T sample({Random? random});
}
