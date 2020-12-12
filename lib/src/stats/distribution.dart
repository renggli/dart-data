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
  T get median;

  /// Returns the mode of the distribution.
  double get mode;

  /// Returns the expected variance.
  double get variance;

  /// Returns the expected standard deviation.
  double get standardDeviation => sqrt(variance);

  /// The Probability Mass Function (PMF).
  ///
  /// Returns the probability of the distribution at [x].
  num pdf(T x);

  /// The Cumulative Distribution Function (CDF).
  ///
  /// Returns the cumulative probability at [x], or the probability of a random
  /// variable to be less than or equal to [x].
  num cdf(T x);

  /// The Inverted Cumulative Distribution Function (INV).
  ///
  /// Returns the value of `x` for which the cumulative probability density is
  /// [p].
  T inv(double p);

  /// Returns a random value within the distribution.
  T sample({Random? random});
}
