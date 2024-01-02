import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The continuous uniform distribution between the bounds [a] and [b]. The
/// distribution describes an experiment where there is an arbitrary outcome
/// that lies between certain bounds.
///
/// See https://en.wikipedia.org/wiki/Continuous_uniform_distribution.
class UniformDistribution extends ContinuousDistribution {
  /// A uniform distribution between [a] and [b].
  const UniformDistribution(this.a, this.b)
      : assert(double.negativeInfinity < a && a < b && b < double.infinity,
            '-∞ < a < b < ∞');

  /// A standard uniform distribution between 0 and 1.
  const UniformDistribution.standard() : this(0, 1);

  /// Minimum value of the distribution.
  final double a;

  /// Maximum value of the distribution.
  final double b;

  @override
  double get lowerBound => a;

  @override
  double get upperBound => b;

  @override
  double get mean => (a + b) / 2;

  @override
  double get median => mean;

  @override
  double get mode => double.nan; // any value in the range

  @override
  double get variance => pow(b - a, 2) / 12;

  @override
  double get skewness => 0;

  @override
  double get kurtosisExcess => -6 / 5;

  @override
  double probability(double x) => a <= x && x <= b ? 1 / (b - a) : 0;

  @override
  double cumulativeProbability(double x) => x <= a
      ? 0
      : x <= b
          ? (x - a) / (b - a)
          : 1;

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return a + p * (b - a);
  }

  @override
  double sample({Random? random}) =>
      a + (b - a) * ((random ?? _random).nextDouble());

  @override
  bool operator ==(Object other) =>
      other is UniformDistribution && a == other.a && b == other.b;

  @override
  int get hashCode => Object.hash(UniformDistribution, a, b);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(a, name: 'a')
    ..addValue(b, name: 'b');
}

final _random = Random();
