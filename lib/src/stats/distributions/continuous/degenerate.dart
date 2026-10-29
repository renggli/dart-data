import 'dart:math';

import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The Degenerate distribution, a continuous probability distribution that is
/// certain to take the value [k].
///
/// See https://en.wikipedia.org/wiki/Degenerate_distribution.
///
/// ```dart
/// final distribution = DegenerateDistribution(10);
/// print(distribution.probability(10));  // 1.0
/// print(distribution.probability(5));  // 0.0
/// ```
class DegenerateDistribution extends ContinuousDistribution {
  /// A degenerate distribution with parameter [k].
  new([this.k = 0]) {
    if (!k.isFinite) {
      throw ArgumentError.value(k, 'k', 'Parameter k must be finite');
    }
  }

  /// A standard degenerate distribution with $k = 0$.
  const new standard() : this._(0.0);

  const new _(this.k);

  /// The parameter k.
  final double k;

  @override
  double get lowerBound => k;

  @override
  double get upperBound => k;

  @override
  double get mean => k;

  @override
  double get median => k;

  @override
  double get mode => k;

  @override
  double get standardDeviation => 0;

  @override
  double get variance => 0;

  @override
  double get skewness => double.nan;

  @override
  double get excessKurtosis => double.nan;

  @override
  double probability(double x) => x.isNaN ? double.nan : (x != k ? 0 : 1);

  @override
  double cumulativeProbability(double x) =>
      x.isNaN ? double.nan : (x < k ? 0 : 1);

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return k;
  }

  @override
  double sample({Random? random}) => k;

  @override
  Iterable<double> samples({Random? random}) => repeat(k);

  @override
  bool operator ==(Object other) =>
      other is DegenerateDistribution && k == other.k;

  @override
  int get hashCode => Object.hash(DegenerateDistribution, k);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(k, name: 'k');
}
