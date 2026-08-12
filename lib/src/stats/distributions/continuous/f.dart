import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../continuous.dart';
import '../errors.dart';
import 'chi_squared.dart';

/// The Fisher-Snedecor F-distribution (also known as the F-distribution) is
/// characterized by two degrees of freedom parameters: [dof1] (numerator) and
/// [dof2] (denominator).
///
/// See https://en.wikipedia.org/wiki/F-distribution.
///
/// ```dart
/// final distribution = FDistribution(2, 5);
/// print(distribution.mean);  // 1.6666666666666667
/// ```
class FDistribution extends ContinuousDistribution {
  /// An F-distribution with numerator degrees of freedom [dof1] and denominator
  /// degrees of freedom [dof2].
  const new(this.dof1, this.dof2)
    : assert(dof1 > 0, 'dof1 > 0'),
      assert(dof2 > 0, 'dof2 > 0');

  /// The numerator degrees of freedom dof1.
  final double dof1;

  /// The denominator degrees of freedom dof2.
  final double dof2;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => dof2 > 2 ? dof2 / (dof2 - 2) : double.nan;

  @override
  double get median => inverseCumulativeProbability(0.5);

  @override
  double get mode =>
      dof1 > 2 ? (dof2 * (dof1 - 2)) / (dof1 * (dof2 + 2)) : double.nan;

  @override
  double get variance => dof2 > 4
      ? (2 * dof2 * dof2 * (dof1 + dof2 - 2)) /
            (dof1 * pow(dof2 - 2, 2) * (dof2 - 4))
      : double.nan;

  @override
  double get skewness => dof2 > 6
      ? (2 * dof1 + dof2 - 2) *
            sqrt(8 * (dof2 - 4)) /
            ((dof2 - 6) * sqrt(dof1 * (dof1 + dof2 - 2)))
      : double.nan;

  @override
  double get kurtosisExcess {
    if (dof2 <= 8) return double.nan;
    final n = dof1;
    final d = dof2;
    return 12 *
        (n * (5 * d - 22) * (n + d - 2) + (d - 4) * pow(d - 2, 2)) /
        (n * (d - 6) * (d - 8) * (n + d - 2));
  }

  @override
  double probability(double x) {
    if (x <= 0) return 0;
    final term1 = dof1 * x;
    final term2 = term1 + dof2;
    return exp(
      0.5 * dof1 * log(dof1) +
          0.5 * dof2 * log(dof2) +
          (0.5 * dof1 - 1) * log(x) -
          0.5 * (dof1 + dof2) * log(term2) -
          betaLn(0.5 * dof1, 0.5 * dof2),
    );
  }

  @override
  double cumulativeProbability(double x) {
    if (x <= 0) return 0;
    final term = dof1 * x / (dof1 * x + dof2);
    return ibeta(term, 0.5 * dof1, 0.5 * dof2);
  }

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    if (p == 0) return 0;
    if (p == 1) return double.infinity;
    final betaInv = ibetaInv(p, 0.5 * dof1, 0.5 * dof2);
    return dof2 * betaInv / (dof1 * (1 - betaInv));
  }

  @override
  double sample({Random? random}) {
    final chi1 = ChiSquaredDistribution(dof1).sample(random: random);
    final chi2 = ChiSquaredDistribution(dof2).sample(random: random);
    if (chi2 == 0) return double.infinity;
    return (chi1 / dof1) / (chi2 / dof2);
  }

  @override
  bool operator ==(Object other) =>
      other is FDistribution && dof1 == other.dof1 && dof2 == other.dof2;

  @override
  int get hashCode => Object.hash(FDistribution, dof1, dof2);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(dof1, name: 'dof1')
    ..addValue(dof2, name: 'dof2');
}
