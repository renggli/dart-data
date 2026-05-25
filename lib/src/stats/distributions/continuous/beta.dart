import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../continuous.dart';
import '../errors.dart';
import 'gamma.dart';

/// The Beta distribution is a family of continuous probability distributions
/// parameterized by two positive shape parameters, denoted by alpha (α) and
/// beta (β).
///
/// See https://en.wikipedia.org/wiki/Beta_distribution.
///
/// ```dart
/// final distribution = BetaDistribution(2, 5);
/// print(distribution.mean);  // 0.2857142857142857
/// ```
class BetaDistribution extends ContinuousDistribution {
  /// A beta distribution with parameters [alpha] α and [beta] β.
  const BetaDistribution(this.alpha, this.beta)
    : assert(alpha > 0, 'alpha > 0'),
      assert(beta > 0, 'beta > 0');

  /// The alpha parameter α.
  final double alpha;

  /// The beta parameter β.
  final double beta;

  @override
  double get lowerBound => 0.0;

  @override
  double get upperBound => 1.0;

  @override
  double get mean => alpha / (alpha + beta);

  @override
  double get median => inverseCumulativeProbability(0.5);

  @override
  double get mode =>
      alpha > 1 && beta > 1 ? (alpha - 1) / (alpha + beta - 2) : double.nan;

  @override
  double get variance =>
      (alpha * beta) / (pow(alpha + beta, 2) * (alpha + beta + 1));

  @override
  double get skewness =>
      (2 * (beta - alpha) * sqrt(alpha + beta + 1)) /
      ((alpha + beta + 2) * sqrt(alpha * beta));

  @override
  double get kurtosisExcess =>
      6 *
      (pow(alpha - beta, 2) * (alpha + beta + 1) -
          alpha * beta * (alpha + beta + 2)) /
      (alpha * beta * (alpha + beta + 2) * (alpha + beta + 3));

  @override
  double probability(double x) {
    if (x < 0 || x > 1) {
      return 0;
    } else if (x == 0) {
      return alpha < 1 ? double.infinity : (alpha == 1 ? 1 / beta : 0);
    } else if (x == 1) {
      return beta < 1 ? double.infinity : (beta == 1 ? 1 / alpha : 0);
    } else {
      return exp(
        (alpha - 1) * log(x) + (beta - 1) * log(1 - x) - betaLn(alpha, beta),
      );
    }
  }

  @override
  double cumulativeProbability(double x) => x <= 0
      ? 0
      : x >= 1
      ? 1
      : ibeta(x, alpha, beta);

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return ibetaInv(p, alpha, beta);
  }

  @override
  double sample({Random? random}) {
    final g1 = GammaDistribution(alpha, 1);
    final g2 = GammaDistribution(beta, 1);
    final y1 = g1.sample(random: random);
    final y2 = g2.sample(random: random);
    final sum = y1 + y2;
    if (sum == 0) return 0;
    return y1 / sum;
  }

  @override
  bool operator ==(Object other) =>
      other is BetaDistribution && alpha == other.alpha && beta == other.beta;

  @override
  int get hashCode => Object.hash(BetaDistribution, alpha, beta);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(alpha, name: 'alpha')
    ..addValue(beta, name: 'beta');
}
