import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The Logistic distribution is a continuous probability distribution parameterized
/// by its location [mu] and scale [s] parameters. Its cumulative distribution
/// function is the logistic function.
///
/// See https://en.wikipedia.org/wiki/Logistic_distribution.
///
/// ```dart
/// final distribution = LogisticDistribution(0, 1);
/// print(distribution.mean);  // 0.0
/// ```
class LogisticDistribution extends ContinuousDistribution {
  /// A Logistic distribution with parameter [mu] and [s].
  const LogisticDistribution([this.mu = 0, this.s = 1])
    : assert(s > 0, 's > 0');

  /// The location parameter mu.
  final double mu;

  /// The scale parameter s.
  final double s;

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
  double get variance => pi * pi * s * s / 3;

  @override
  double get skewness => 0;

  @override
  double get kurtosisExcess => 1.2;

  @override
  double probability(double x) {
    final z = (x - mu) / s;
    final ez = exp(-z.abs());
    return ez / (s * pow(1 + ez, 2));
  }

  @override
  double cumulativeProbability(double x) {
    final z = (x - mu) / s;
    return 1 / (1 + exp(-z));
  }

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    if (p == 0) return double.negativeInfinity;
    if (p == 1) return double.infinity;
    return mu + s * log(p / (1 - p));
  }

  @override
  double sample({Random? random}) {
    final u = (random ?? _random).nextDouble();
    return inverseCumulativeProbability(u);
  }

  @override
  bool operator ==(Object other) =>
      other is LogisticDistribution && mu == other.mu && s == other.s;

  @override
  int get hashCode => Object.hash(LogisticDistribution, mu, s);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(mu, name: 'mu')
    ..addValue(s, name: 's');
}

final _random = Random();
