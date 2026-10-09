import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../continuous.dart';
import '../errors.dart';
import 'gamma.dart';

/// The Beta distribution over interval $[0, 1]$.
///
/// See https://en.wikipedia.org/wiki/Beta_distribution.
class BetaDistribution extends ContinuousDistribution {
  /// A Beta distribution with shape parameters [alpha] $\alpha$ and [beta] $\beta$.
  const new(this.alpha, this.beta)
    : assert(alpha > 0, 'α > 0'),
      assert(beta > 0, 'β > 0');

  /// Fits a beta distribution to [samples] in $(0, 1)$ using method of moments.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      if (x <= 0 || x >= 1) {
        throw ArgumentError.value(x, 'samples', 'Samples must be in (0, 1)');
      }
      count++;
      sum += x;
    }
    if (count < 2) {
      throw ArgumentError.value(
        samples,
        'samples',
        'At least 2 samples required',
      );
    }
    final mean = sum / count;
    var sumSqDiff = 0.0;
    for (final x in samples) {
      final diff = x - mean;
      sumSqDiff += diff * diff;
    }
    final variance = sumSqDiff / (count - 1);
    final factor = (mean * (1.0 - mean) / variance) - 1.0;
    final a = mean * factor;
    final b = (1.0 - mean) * factor;
    return BetaDistribution(a > 0 ? a : 1.0, b > 0 ? b : 1.0);
  }

  /// Shape parameter $\alpha$.
  final double alpha;

  /// Shape parameter $\beta$.
  final double beta;

  @override
  double get lowerBound => 0.0;

  @override
  bool get isLowerBoundOpen => false;

  @override
  double get upperBound => 1.0;

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => alpha / (alpha + beta);

  @override
  double get median => alpha == beta ? 0.5 : double.nan;

  @override
  double get mode => (alpha > 1.0 && beta > 1.0)
      ? (alpha - 1.0) / (alpha + beta - 2.0)
      : double.nan;

  @override
  double get variance =>
      (alpha * beta) / ((alpha + beta) * (alpha + beta) * (alpha + beta + 1.0));

  @override
  double get skewness =>
      (2.0 * (beta - alpha) * sqrt(alpha + beta + 1.0)) /
      ((alpha + beta + 2.0) * sqrt(alpha * beta));

  @override
  double get excessKurtosis {
    final ab = alpha * beta;
    final apb = alpha + beta;
    final num =
        6.0 *
        ((alpha - beta) * (alpha - beta) * (apb + 1.0) - ab * (apb + 2.0));
    final den = ab * (apb + 2.0) * (apb + 3.0);
    return num / den;
  }

  @override
  double probability(double x) {
    if (x < 0.0 || x > 1.0) return 0.0;
    if (x == 0.0) {
      return alpha == 1.0 ? beta : (alpha < 1.0 ? double.infinity : 0.0);
    }
    if (x == 1.0) {
      return beta == 1.0 ? alpha : (beta < 1.0 ? double.infinity : 0.0);
    }
    return exp(
      (alpha - 1.0) * log(x) +
          (beta - 1.0) * log(1.0 - x) -
          betaLn(alpha, beta),
    );
  }

  @override
  double cumulativeProbability(double x) {
    if (x <= 0.0) return 0.0;
    if (x >= 1.0) return 1.0;
    return ibeta(x, alpha, beta);
  }

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return ibetaInv(p, alpha, beta);
  }

  @override
  double sample({Random? random}) {
    final x = GammaDistribution.shape(alpha).sample(random: random);
    final y = GammaDistribution.shape(beta).sample(random: random);
    return x / (x + y);
  }

  @override
  bool operator ==(Object other) =>
      other is BetaDistribution && alpha == other.alpha && beta == other.beta;

  @override
  int get hashCode => Object.hash(BetaDistribution, alpha, beta);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(alpha, name: 'α')
    ..addValue(beta, name: 'β');
}
