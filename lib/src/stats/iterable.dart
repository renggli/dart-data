import 'dart:math';

extension IterableNumExtension on Iterable<num> {
  /// Returns the sum of this [Iterable].
  ///
  /// Example: `[-1, 2.5].sum()` returns `1.5`.
  ///
  double sum() {
    var sum = 0.0;
    for (final value in this) {
      sum += value;
    }
    return sum;
  }

  /// Returns the product of this [Iterable].
  ///
  /// Example: `[-2.0, 2.5].product()` returns `-5`.
  ///
  double product() {
    var product = 1.0;
    for (final value in this) {
      product *= value;
    }
    return product;
  }

  /// Returns the average of this [Iterable], see [arithmeticMean] for details.
  double average() => arithmeticMean();

  /// Returns the arithmetic mean (or average) of this [Iterable], or
  /// [double.nan] if the iterable is empty.
  ///
  /// For details, see https://en.wikipedia.org/wiki/Arithmetic_mean.`
  ///
  /// Example: `[5, 2].arithmeticMean()` returns `3.5`.
  ///
  double arithmeticMean() {
    var count = 0, sum = 0.0;
    for (final value in this) {
      count++;
      sum += value;
    }
    return count == 0 ? double.nan : sum / count;
  }

  /// Returns the geometric mean of this [Iterable], or [double.nan] if the
  /// iterable is empty.
  ///
  /// For details, see https://en.wikipedia.org/wiki/Geometric_mean.
  ///
  /// Example: `[2, 8].geometricMean()` returns `4.0`.
  ///
  double geometricMean() {
    var count = 0, sum = 0.0;
    for (final value in this) {
      count++;
      sum += log(value);
    }
    return count == 0 ? double.nan : exp(sum / count);
  }

  /// Returns the harmonic mean of this [Iterable], or [double.nan] if the
  /// sum of the iterable is 0.
  ///
  /// For details, see https://en.wikipedia.org/wiki/Harmonic_mean.average
  ///
  /// Example: `[2, 3].harmonicMean()` returns `2.4`.
  ///
  double harmonicMean() {
    var count = 0, sum = 0.0;
    for (final value in this) {
      count++;
      sum += 1 / value;
    }
    return sum == 0.0 ? double.nan : count / sum;
  }

  /// Returns the (population) variance of this [Iterable], or [double.nan] if
  /// the iterable contains less than 2 (1 for population variance) values.
  ///
  /// For details, see https://en.wikipedia.org/wiki/Variance.
  ///
  /// Example: `[2, 5].variance()` returns `4.5`.
  ///
  double variance({bool population = false}) {
    var count = 0, mean = 0.0, m2 = 0.0;
    for (final value in this) {
      count++;
      final delta = value - mean;
      mean += delta / count;
      final delta2 = value - mean;
      m2 += delta * delta2;
    }
    final divisor = population ? count : count - 1;
    return divisor < 1 ? double.nan : m2 / divisor;
  }

  /// Returns the square root of the (population) variance of this [Iterable],
  /// or [double.nan] if the iterable contains less than 2 (1 for population
  /// variance) values.
  ///
  /// For details, see https://en.wikipedia.org/wiki/Standard_deviation.
  ///
  /// Example: `[2, 5].standardDeviation()` returns `2.1213...`.
  ///
  double standardDeviation({bool population = false}) =>
      sqrt(variance(population: population));
}

extension IterableIntExtension on Iterable<int> {
  /// Returns the sum of this [Iterable].
  ///
  /// Example: `[-1, 3].sum()` returns `2`.
  ///
  int sum() {
    var sum = 0;
    for (final value in this) {
      sum += value;
    }
    return sum;
  }

  /// Returns the product of this [Iterable].
  ///
  /// Example: `[-2, 3].product()` returns `-6`.
  ///
  int product() {
    var product = 1;
    for (final value in this) {
      product *= value;
    }
    return product;
  }
}
