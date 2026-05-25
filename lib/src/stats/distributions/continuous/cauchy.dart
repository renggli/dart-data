import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The Cauchy distribution, also called the Lorentz distribution, is a
/// continuous probability distribution parameterized by location parameter [xo]
/// and scale parameter [gamma] (γ).
///
/// See https://en.wikipedia.org/wiki/Cauchy_distribution.
///
/// ```dart
/// final distribution = CauchyDistribution(0, 1);
/// print(distribution.median);  // 0.0
/// ```
class CauchyDistribution extends ContinuousDistribution {
  /// A Cauchy distribution with parameter [xo] and [gamma].
  const CauchyDistribution([this.xo = 0, this.gamma = 1])
    : assert(gamma > 0, 'gamma > 0');

  /// The location parameter xo.
  final double xo;

  /// The scale parameter gamma (γ).
  final double gamma;

  @override
  double get lowerBound => double.negativeInfinity;

  @override
  double get upperBound => double.infinity;

  @override
  double get mean => double.nan;

  @override
  double get median => xo;

  @override
  double get mode => xo;

  @override
  double get variance => double.nan;

  @override
  double get skewness => double.nan;

  @override
  double get kurtosisExcess => double.nan;

  @override
  double probability(double x) =>
      1 / (pi * gamma * (1 + pow((x - xo) / gamma, 2)));

  @override
  double cumulativeProbability(double x) => atan((x - xo) / gamma) / pi + 0.5;

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    if (p == 0) return double.negativeInfinity;
    if (p == 1) return double.infinity;
    return xo + gamma * tan(pi * (p - 0.5));
  }

  @override
  double sample({Random? random}) {
    final u = (random ?? _random).nextDouble();
    return xo + gamma * tan(pi * (u - 0.5));
  }

  @override
  bool operator ==(Object other) =>
      other is CauchyDistribution && xo == other.xo && gamma == other.gamma;

  @override
  int get hashCode => Object.hash(CauchyDistribution, xo, gamma);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(xo, name: 'xo')
    ..addValue(gamma, name: 'gamma');
}

final _random = Random();
