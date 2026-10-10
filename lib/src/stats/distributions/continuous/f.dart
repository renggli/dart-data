import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../continuous.dart';
import '../errors.dart';
import 'chi_squared.dart';

/// The Fisher-Snedecor F-distribution.
///
/// See https://en.wikipedia.org/wiki/F-distribution.
class FDistribution extends ContinuousDistribution {
  /// An F-distribution with numerator degrees of freedom [d1] and denominator degrees of freedom [d2].
  const new(this.d1, this.d2)
    : assert(d1 > 0, 'd1 > 0'),
      assert(d2 > 0, 'd2 > 0');

  /// Fits an F-distribution to [samples] using method of moments estimation.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      if (x <= 0) {
        throw ArgumentError.value(
          x,
          'samples',
          'F-distribution samples must be positive',
        );
      }
      count++;
      sum += x;
    }
    if (count < 4) {
      throw ArgumentError.value(
        samples,
        'samples',
        'At least 4 samples required to fit F-distribution',
      );
    }
    final mean = sum / count;
    var sumSqDiff = 0.0;
    for (final x in samples) {
      final diff = x - mean;
      sumSqDiff += diff * diff;
    }
    final variance = sumSqDiff / (count - 1);

    var d2 = mean > 1.0 ? (2.0 * mean) / (mean - 1.0) : 6.0;
    d2 = d2.clamp(2.1, 100.0);
    final denom = variance * (d2 - 4.0) - 2.0 * mean * mean;
    var d1 = denom > 0.0 ? (2.0 * mean * mean * (d2 - 2.0)) / denom : 5.0;
    if (d1.isNaN || d1 <= 0.0) d1 = 5.0;
    d1 = d1.clamp(0.5, 100.0);
    return FDistribution(d1, d2);
  }

  /// Numerator degrees of freedom $d_1$.
  final double d1;

  /// Denominator degrees of freedom $d_2$.
  final double d2;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => d2 > 2.0 ? d2 / (d2 - 2.0) : double.nan;

  @override
  double get median => double.nan;

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
    if (x <= 0.0) return 0.0;
    final logPdf =
        0.5 * d1 * log(d1 / d2) +
        (0.5 * d1 - 1.0) * log(x) -
        0.5 * (d1 + d2) * log(1.0 + (d1 / d2) * x) -
        betaLn(0.5 * d1, 0.5 * d2);
    return exp(logPdf);
  }

  @override
  double cumulativeProbability(double x) {
    if (x <= 0.0) return 0.0;
    final z = (d1 * x) / (d1 * x + d2);
    return ibeta(z, 0.5 * d1, 0.5 * d2);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0.0) return 0.0;
    if (probability == 1.0) return double.infinity;
    final betaVal = ibetaInv(probability, 0.5 * d1, 0.5 * d2);
    return (d2 * betaVal) / (d1 * (1.0 - betaVal));
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
