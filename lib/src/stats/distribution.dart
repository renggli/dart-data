import 'dart:math';

import 'package:meta/meta.dart';
import 'package:more/more.dart';

import 'distributions/errors.dart';

/// Abstract interface of all distributions.
@immutable
abstract class Distribution<T> with ToStringPrinter {
  const Distribution();

  /// Returns the domain of the distribution.
  Interval<T> get support => Interval<T>.all();

  /// Returns the lower boundary of the distribution.
  T get lowerBound;

  /// Returns the upper boundary of the distribution.
  T get upperBound;

  /// Returns the mean value of the distribution.
  ///
  /// See https://en.wikipedia.org/wiki/Expected_value.
  double get mean;

  /// Returns the median value of the distribution.
  ///
  /// See https://en.wikipedia.org/wiki/Median.
  double get median;

  /// Returns the mode, a value that appears most commonly in the set of values.
  ///
  /// See https://en.wikipedia.org/wiki/Mode_(statistics).
  double get mode;

  /// Returns the expected variance.
  ///
  /// See https://en.wikipedia.org/wiki/Variance.
  double get variance;

  /// Returns the expected standard deviation.
  ///
  /// See https://en.wikipedia.org/wiki/Standard_deviation.
  double get standardDeviation => sqrt(variance);

  /// Returns the skewness of the distribution.
  ///
  /// See https://en.wikipedia.org/wiki/Skewness.
  double get skewness;

  /// Returns the excess kurtosis.
  ///
  /// See https://en.wikipedia.org/wiki/Kurtosis#Excess_kurtosis.
  double get kurtosisExcess;

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
  double survival(T x) => 1 - cumulativeProbability(x);

  /// Inverse Survival Function (ISF).
  ///
  /// Returns the value of `x` for which the survival probably density is
  /// [p]. Throws [InvalidProbability], if [p] is out of range.
  T inverseSurvival(num p) {
    InvalidProbability.check(p);
    return inverseCumulativeProbability(1 - p);
  }

  /// Returns a single sample of a random value within the distribution.
  T sample({Random? random});

  /// Returns an infinite source of random samples within the distribution.
  Iterable<T> samples({Random? random}) sync* {
    for (;;) {
      yield sample(random: random);
    }
  }
}
