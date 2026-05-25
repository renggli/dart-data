import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The Laplace distribution is a continuous probability distribution defined by
/// its location [mu] and scale [b] parameters. It is also known as the double
/// exponential distribution.
///
/// See https://en.wikipedia.org/wiki/Laplace_distribution.
///
/// ```dart
/// final distribution = LaplaceDistribution(0, 1);
/// print(distribution.variance);  // 2.0
/// ```
class LaplaceDistribution extends ContinuousDistribution {
  /// A Laplace distribution with parameter [mu] and [b].
  const LaplaceDistribution([this.mu = 0, this.b = 1]) : assert(b > 0, 'b > 0');

  /// The location parameter mu.
  final double mu;

  /// The scale parameter b.
  final double b;

  @override
  double get lowerBound => double.negativeInfinity;

  @override
  double get upperBound => double.infinity;

  @override
  double get mean => mu;

  @override
  double get median => mu;

  @override
  double get mode => mu;

  @override
  double get variance => 2 * b * b;

  @override
  double get skewness => 0;

  @override
  double get kurtosisExcess => 3;

  @override
  double probability(double x) => exp(-(x - mu).abs() / b) / (2 * b);

  @override
  double cumulativeProbability(double x) {
    final diff = x - mu;
    return diff < 0 ? 0.5 * exp(diff / b) : 1 - 0.5 * exp(-diff / b);
  }

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    if (p == 0) return double.negativeInfinity;
    if (p == 1) return double.infinity;
    if (p < 0.5) {
      return mu + b * log(2 * p);
    } else {
      return mu - b * log(2 * (1 - p));
    }
  }

  @override
  double sample({Random? random}) {
    final u = (random ?? _random).nextDouble();
    return inverseCumulativeProbability(u);
  }

  @override
  bool operator ==(Object other) =>
      other is LaplaceDistribution && mu == other.mu && b == other.b;

  @override
  int get hashCode => Object.hash(LaplaceDistribution, mu, b);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(mu, name: 'mu')
    ..addValue(b, name: 'b');
}

final _random = Random();
