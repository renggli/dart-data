import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import '../utils.dart';
import 'gamma.dart';

/// The Chi-squared (χ²) distribution with [dof] degrees of freedom.
///
/// See https://en.wikipedia.org/wiki/Chi-squared_distribution.
class ChiSquaredDistribution extends ContinuousDistribution {
  /// A Chi-squared distribution with degrees of freedom [dof] k.
  new(this.dof) {
    if (!dof.isFinite || dof <= 0) {
      throw ArgumentError.value(
        dof,
        'dof',
        'Degrees of freedom must be strictly positive',
      );
    }
  }

  /// Fits a Chi-squared distribution to [samples] using maximum likelihood
  /// estimation.
  factory fit(Iterable<num> samples) {
    final stats = welfordSampleStats(
      samples,
      isValid: (value) => value >= 0.0,
      invalidMessage: 'Chi-squared samples must be non-negative',
    );
    return ChiSquaredDistribution(stats.mean > 0.0 ? stats.mean : 1.0);
  }

  /// The degrees of freedom k.
  final double dof;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => dof;

  @override
  double get mode => dof >= 2.0 ? dof - 2.0 : 0.0;

  @override
  double get variance => 2.0 * dof;

  @override
  double get skewness => sqrt(8.0 / dof);

  @override
  double get excessKurtosis => 12.0 / dof;

  @override
  double probability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x == double.infinity) return 0.0;
    if (x == 0.0) {
      if (dof < 2.0) return double.infinity;
      if (dof == 2.0) return 0.5;
      return 0.0;
    }
    return exp(logProbability(x));
  }

  @override
  double logProbability(double x) {
    if (x.isNaN) return double.nan;
    if (x < 0.0 || x == double.infinity) return double.negativeInfinity;
    if (x == 0.0) {
      if (dof < 2.0) return double.infinity;
      if (dof == 2.0) return -ln2;
      return double.negativeInfinity;
    }
    final kHalf = 0.5 * dof;
    return (kHalf - 1.0) * log(x) - 0.5 * x - kHalf * ln2 - gammaLn(kHalf);
  }

  @override
  double cumulativeProbability(double x) {
    if (x.isNaN) return double.nan;
    return x <= 0.0 ? 0.0 : gammaP(0.5 * dof, 0.5 * x);
  }

  @override
  double survival(double x) {
    if (x.isNaN) return double.nan;
    return x <= 0.0 ? 1.0 : gammaQ(0.5 * dof, 0.5 * x);
  }

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    return gammaPInv(0.5 * dof, probability) * 2.0;
  }

  @override
  double inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    return gammaQInv(0.5 * dof, probability) * 2.0;
  }

  @override
  double sample({Random? random}) =>
      GammaDistribution(0.5 * dof, 2.0).sample(random: random);

  @override
  bool operator ==(Object other) =>
      other is ChiSquaredDistribution && dof == other.dof;

  @override
  int get hashCode => Object.hash(ChiSquaredDistribution, dof);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(dof, name: 'k');
}
