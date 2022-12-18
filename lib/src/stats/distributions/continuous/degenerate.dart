import 'dart:math';

import 'package:more/collection.dart';
import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The Degenerate distribution, a continuous probability distribution that is
/// certain to take the value [k].
///
/// See https://en.wikipedia.org/wiki/Degenerate_distribution.
class DegenerateDistribution extends ContinuousDistribution {
  /// A degenerate distribution with parameter [k].
  const DegenerateDistribution([this.k = 0]);

  /// The parameter k.
  final double k;

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
  double get kurtosisExcess => double.nan;

  @override
  double probability(double x) => x != k ? 0 : 1;

  @override
  double cumulativeProbability(double x) => x < k ? 0 : 1;

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
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
