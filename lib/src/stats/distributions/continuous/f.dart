import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../../../special/utils.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';
import 'chi_squared.dart';

/// The Fisher-Snedecor F-distribution.
///
/// See https://en.wikipedia.org/wiki/F-distribution.
class FDistribution extends ContinuousDistribution {
  /// An F-distribution with numerator degrees of freedom [d1] and denominator
  /// degrees of freedom [d2].
  new(this.d1, this.d2) {
    if (!d1.isFinite || d1 <= 0) {
      throw ArgumentError.value(d1, 'd1', 'd1 must be strictly positive');
    }
    if (!d2.isFinite || d2 <= 0) {
      throw ArgumentError.value(d2, 'd2', 'd2 must be strictly positive');
    }
  }

  /// Fits an F-distribution to [samples] using method of moments estimation.
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(
      samples,
      isValid: (value) => value > 0.0,
      invalidMessage: 'F-distribution samples must be positive',
      minCount: 4,
    );
    final mean = stats.mean;
    var d2 = mean > 1.0 ? (2.0 * mean) / (mean - 1.0) : 6.0;
    d2 = d2.clamp(2.1, 100.0);
    final denom = stats.variance * (d2 - 4.0) - 2.0 * mean * mean;
    var d1 = denom > 0.0 ? (2.0 * mean * mean * (d2 - 2.0)) / denom : 5.0;
    if (d1.isNaN || d1 <= 0.0) d1 = 5.0;
    d1 = d1.clamp(0.5, 100.0);
    return FDistribution(d1, d2);
  }

  /// Numerator degrees of freedom d1.
  final double d1;

  /// Denominator degrees of freedom d2.
  final double d2;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => d2 > 2.0 ? d2 / (d2 - 2.0) : double.nan;

  @override
  double get mode => d1 > 2.0 ? ((d1 - 2.0) / d1) * (d2 / (d2 + 2.0)) : 0.0;

  @override
  double get variance => d2 > 4.0
      ? (2.0 * d2 * d2 * (d1 + d2 - 2.0)) /
            (d1 * (d2 - 2.0) * (d2 - 2.0) * (d2 - 4.0))
      : double.nan;

  @override
  double get skewness => d2 > 6.0
      ? ((2.0 * d1 + d2 - 2.0) * sqrt(8.0 * (d2 - 4.0))) /
            ((d2 - 6.0) * sqrt(d1 * (d1 + d2 - 2.0)))
      : double.nan;

  @override
  double get excessKurtosis => d2 > 8.0
      ? 12.0 *
            (d1 * (5.0 * d2 - 22.0) * (d1 + d2 - 2.0) +
                (d2 - 4.0) * (d2 - 2.0) * (d2 - 2.0)) /
            (d1 * (d2 - 6.0) * (d2 - 8.0) * (d1 + d2 - 2.0))
      : double.nan;

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x == double.infinity) return 0.0;
    if (x == 0.0) {
      if (d1 < 2.0) return double.infinity;
      if (d1 == 2.0) return 1.0;
      return 0.0;
    }
    return exp(logProbability(x));
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x == double.infinity) return double.negativeInfinity;
    if (x == 0.0) {
      if (d1 < 2.0) return double.infinity;
      if (d1 == 2.0) return 0.0;
      return double.negativeInfinity;
    }
    final z = (d1 / d2) * x;
    final logOnePlusZ = z > 1e8 || !z.isFinite
        ? log(d1) - log(d2) + log(x) + (z.isFinite ? log1p(1.0 / z) : 0.0)
        : log1p(z);
    return 0.5 * d1 * (log(d1) - log(d2)) +
        (0.5 * d1 - 1.0) * log(x) -
        0.5 * (d1 + d2) * logOnePlusZ -
        betaLn(0.5 * d1, 0.5 * d2);
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 0.0;
    if (x == double.infinity) return 1.0;
    final ratio = (d2 / d1) / x;
    final z = ratio == 0.0 ? 1.0 : 1.0 / (1.0 + ratio);
    return betaI(z, 0.5 * d1, 0.5 * d2);
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    if (x <= 0.0) return 1.0;
    if (x == double.infinity) return 0.0;
    final ratio = (d2 / d1) / x;
    final z = ratio.isInfinite ? 1.0 : ratio / (1.0 + ratio);
    return betaI(z, 0.5 * d2, 0.5 * d1);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return 0.0;
    if (probability == 1.0) return double.infinity;
    final betaVal = betaIInv(probability, 0.5 * d1, 0.5 * d2);
    return (d2 * betaVal) / (d1 * (1.0 - betaVal));
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return double.infinity;
    if (probability == 1.0) return 0.0;
    final betaVal = betaIInv(probability, 0.5 * d2, 0.5 * d1);
    return (d2 * (1.0 - betaVal)) / (d1 * betaVal);
  }

  @override
  double sample({Random? random}) {
    final y1 = ChiSquaredDistribution(d1).sample(random: random);
    final y2 = ChiSquaredDistribution(d2).sample(random: random);
    return (y1 / d1) / (y2 / d2);
  }

  @override
  bool operator ==(Object other) =>
      other is FDistribution && d1 == other.d1 && d2 == other.d2;

  @override
  int get hashCode => Object.hash(FDistribution, d1, d2);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(d1, name: 'd1')
    ..addValue(d2, name: 'd2');
}
