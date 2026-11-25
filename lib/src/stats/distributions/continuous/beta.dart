import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../../../special/utils.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';
import 'gamma.dart';

/// Continuous probability distribution defined on the unit interval
/// `[0.0, 1.0]`.
///
/// Parameterized by two positive shape parameters [alpha] (α > 0) and
/// [beta] (β > 0) that control the probabilities of values closer to 0, 1,
/// or centered in the middle. Commonly used in Bayesian statistics as the
/// conjugate prior for Bernoulli, binomial, and negative binomial
/// distributions.
///
/// See https://en.wikipedia.org/wiki/Beta_distribution.
class BetaDistribution extends ContinuousDistribution {
  /// A Beta distribution with shape parameters [alpha] α and [beta] β.
  new(this.alpha, this.beta) {
    if (!alpha.isFinite || alpha <= 0) {
      throw ArgumentError.value(alpha, 'alpha', 'Must be positive');
    }
    if (!beta.isFinite || beta <= 0) {
      throw ArgumentError.value(beta, 'beta', 'Must be positive');
    }
  }

  /// Fits a beta distribution to [samples] in `(0, 1)` using method of moments.
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(
      samples,
      isValid: (value) => value > 0.0 && value < 1.0,
      invalidMessage: 'Samples must be in (0, 1)',
      minCount: 2,
    );
    if (stats.variance <= 0.0) {
      return BetaDistribution(1.0, 1.0);
    }
    final mean = stats.mean;
    final factor = (mean * (1.0 - mean) / stats.variance) - 1.0;
    if (!factor.isFinite || factor <= 0.0) {
      return BetaDistribution(1.0, 1.0);
    }
    final a = mean * factor;
    final b = (1.0 - mean) * factor;
    return BetaDistribution(a > 0.0 ? a : 1.0, b > 0.0 ? b : 1.0);
  }

  /// Shape parameter α.
  final double alpha;

  /// Shape parameter β.
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
  double get median => alpha == beta ? 0.5 : inverseCumulativeProbability(0.5);

  @override
  double get mode {
    if (alpha > 1.0 && beta > 1.0) {
      return (alpha - 1.0) / (alpha + beta - 2.0);
    }
    if (alpha <= 1.0 && beta > 1.0) return 0.0;
    if (alpha > 1.0 && beta <= 1.0) return 1.0;
    return double.nan;
  }

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
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x > 1.0) return 0.0;
    if (x == 0.0) {
      return alpha == 1.0 ? beta : (alpha < 1.0 ? double.infinity : 0.0);
    }
    if (x == 1.0) {
      return beta == 1.0 ? alpha : (beta < 1.0 ? double.infinity : 0.0);
    }
    return exp(logProbability(x));
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x > 1.0) return double.negativeInfinity;
    if (x == 0.0) {
      if (alpha == 1.0) return log(beta);
      return alpha < 1.0 ? double.infinity : double.negativeInfinity;
    }
    if (x == 1.0) {
      if (beta == 1.0) return log(alpha);
      return beta < 1.0 ? double.infinity : double.negativeInfinity;
    }
    return (alpha - 1.0) * log(x) +
        (beta - 1.0) * log1p(-x) -
        betaLn(alpha, beta);
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 0.0;
    if (x >= 1.0) return 1.0;
    return betaI(x, alpha, beta);
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 1.0;
    if (x >= 1.0) return 0.0;
    return betaI(1.0 - x, beta, alpha);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return betaIInv(probability, alpha, beta);
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    return 1.0 - betaIInv(probability, beta, alpha);
  }

  @override
  double sample({Random? random}) {
    final rng = random ?? defaultRandom;
    final x = GammaDistribution.shape(alpha).sample(random: rng);
    final y = GammaDistribution.shape(beta).sample(random: rng);
    final sum = x + y;
    if (sum > 0.0) {
      return x / sum;
    }
    // Underflow fallback when both shape parameters < 1 produce 0.0 draws.
    final logX =
        log(GammaDistribution.shape(alpha + 1.0).sample(random: rng)) +
        log(nextOpenUnit(rng)) / alpha;
    final logY =
        log(GammaDistribution.shape(beta + 1.0).sample(random: rng)) +
        log(nextOpenUnit(rng)) / beta;
    if (logX > logY) {
      return 1.0 / (1.0 + exp(logY - logX));
    }
    final ratio = exp(logX - logY);
    return ratio / (1.0 + ratio);
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
