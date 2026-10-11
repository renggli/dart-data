import 'dart:math';

import 'package:meta/meta.dart';
import 'package:more/printer.dart' show ToStringPrinter;

import 'distributions/errors.dart';

/// Abstract base class representing a probability distribution over [T].
///
/// Conceptually, a probability distribution describes all possible outcomes of
/// a random process and how likely each outcome is (such as rolling dice or
/// measuring natural variations in a population). Formally, this formalizes a
/// probability space $(\Omega, \mathcal{F}, P)$ and random variable
/// $X: \Omega \to \mathbb{R}$ with support, density, and cumulative
/// distribution functions.
@immutable
abstract class Distribution<T extends num> with ToStringPrinter {
  /// Abstract constant constructor for subclassing [Distribution].
  const new();

  /// Returns the lower bound of the distribution.
  T get lowerBound;

  /// Returns true if the lower bound is open (exclusive).
  bool get isLowerBoundOpen;

  /// Returns the upper bound of the distribution.
  T get upperBound;

  /// Returns true if the upper bound is open (exclusive).
  bool get isUpperBoundOpen;

  /// Returns the expected value / mean of the distribution.
  double get mean;

  /// Returns the median of the distribution.
  double get median;

  /// Returns the mode of the distribution.
  double get mode;

  /// Returns the variance of the distribution.
  double get variance;

  /// Returns the standard deviation of the distribution.
  double get standardDeviation => sqrt(variance);

  /// Returns the skewness of the distribution.
  double get skewness;

  /// Returns the excess kurtosis of the distribution.
  double get excessKurtosis;

  /// Returns the probability density (PDF) or probability mass (PMF) at [x].
  double probability(T x);

  /// Returns the cumulative distribution function (CDF) at [x], i.e.,
  /// $P(X \le x)$.
  double cumulativeProbability(T x);

  /// Returns the quantile (percent-point function / inverse CDF) for
  /// [probability].
  T inverseCumulativeProbability(num probability);

  /// Returns the survival function $S(x) = P(X > x) = 1 - F(x)$.
  double survival(T x) => 1.0 - cumulativeProbability(x);

  /// Returns the inverse survival function for [probability].
  T inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    return inverseCumulativeProbability(1.0 - probability);
  }

  /// Draws a single pseudo-random sample from the distribution.
  T sample({Random? random});

  /// Generates an infinite sequence of pseudo-random samples from the
  /// distribution.
  Iterable<T> samples({Random? random}) sync* {
    for (;;) {
      yield sample(random: random);
    }
  }
}
