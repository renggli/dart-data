import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import '../errors.dart';

/// The Pareto distribution is a power-law probability distribution defined on
/// the interval [xo, infinity) parameterized by scale parameter [xo] and shape
/// parameter [alpha] (α).
///
/// See https://en.wikipedia.org/wiki/Pareto_distribution.
///
/// ```dart
/// final distribution = ParetoDistribution(1, 3);
/// print(distribution.mean);  // 1.5
/// ```
class ParetoDistribution extends ContinuousDistribution {
  /// A Pareto distribution with parameters [xo] and [alpha].
  const ParetoDistribution(this.xo, this.alpha)
    : assert(xo > 0, 'xo > 0'),
      assert(alpha > 0, 'alpha > 0');

  /// The scale parameter xo.
  final double xo;

  /// The shape parameter alpha (α).
  final double alpha;

  @override
  double get lowerBound => xo;

  @override
  double get mean => alpha > 1 ? alpha * xo / (alpha - 1) : double.infinity;

  @override
  double get median => xo * pow(2, 1 / alpha).toDouble();

  @override
  double get mode => xo;

  @override
  double get variance => alpha > 2
      ? alpha * xo * xo / (pow(alpha - 1, 2).toDouble() * (alpha - 2))
      : (alpha > 1 ? double.infinity : double.nan);

  @override
  double get skewness => alpha > 3
      ? 2 * (1 + alpha) / (alpha - 3) * sqrt((alpha - 2) / alpha)
      : double.nan;

  @override
  double get kurtosisExcess => alpha > 4
      ? 6 *
            (pow(alpha, 3).toDouble() +
                pow(alpha, 2).toDouble() -
                6 * alpha -
                2) /
            (alpha * (alpha - 3) * (alpha - 4))
      : double.nan;

  @override
  double probability(double x) => x < xo
      ? 0.0
      : alpha * pow(xo, alpha).toDouble() / pow(x, alpha + 1).toDouble();

  @override
  double cumulativeProbability(double x) =>
      x < xo ? 0.0 : 1.0 - pow(xo / x, alpha).toDouble();

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return xo / pow(1 - p, 1 / alpha).toDouble();
  }

  @override
  double sample({Random? random}) {
    final u = (random ?? _random).nextDouble();
    return xo / pow(u, 1 / alpha).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is ParetoDistribution && xo == other.xo && alpha == other.alpha;

  @override
  int get hashCode => Object.hash(ParetoDistribution, xo, alpha);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(xo, name: 'xo')
    ..addValue(alpha, name: 'alpha');
}

final _random = Random();
