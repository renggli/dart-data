import 'dart:math';

import 'package:more/feature.dart';
import 'package:more/printer.dart';

import '../discrete.dart';
import '../errors.dart';

/// The Geometric distribution is a discrete probability distribution which models
/// the number of failures before the first success in a sequence of independent
/// Bernoulli trials with success probability [p].
///
/// See https://en.wikipedia.org/wiki/Geometric_distribution.
///
/// ```dart
/// final distribution = GeometricDistribution(0.5);
/// print(distribution.mean);  // 1.0
/// ```
class GeometricDistribution extends DiscreteDistribution {
  /// A geometric distribution with parameter [p].
  const GeometricDistribution(this.p) : assert(0 < p && p <= 1, '0 < p <= 1');

  /// Success probability of each trial (0..1].
  final double p;

  @override
  int get lowerBound => 0;

  @override
  int get upperBound => maxSafeInteger;

  @override
  double get mean => (1 - p) / p;

  @override
  double get median =>
      p == 1 ? 0.0 : (-1 / (log(1 - p) / ln2)).ceilToDouble() - 1;

  @override
  double get mode => 0.0;

  @override
  double get variance => (1 - p) / (p * p);

  @override
  double get skewness => p == 1 ? double.nan : (2 - p) / sqrt(1 - p);

  @override
  double get kurtosisExcess => p == 1 ? double.nan : 6 + (p * p) / (1 - p);

  @override
  double probability(int k) {
    if (k < 0) return 0;
    if (p == 1) return k == 0 ? 1 : 0;
    return exp(k * log(1 - p)) * p;
  }

  @override
  double cumulativeProbability(int k) {
    if (k < 0) return 0;
    if (p == 1) return 1;
    return 1 - pow(1 - p, k + 1).toDouble();
  }

  @override
  int inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    if (this.p == 1) return 0;
    if (p == 0) return 0;
    if (p == 1) return upperBound;
    return (log(1 - p) / log(1 - this.p)).ceil() - 1;
  }

  @override
  int sample({Random? random}) {
    if (p == 1) return 0;
    final u = (random ?? _random).nextDouble();
    if (u == 0) return 0;
    return (log(u) / log(1 - p)).floor();
  }

  @override
  bool operator ==(Object other) =>
      other is GeometricDistribution && p == other.p;

  @override
  int get hashCode => Object.hash(GeometricDistribution, p);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(p, name: 'p');
}

final _random = Random();
