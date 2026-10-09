import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import 'gamma.dart';

/// The Chi-squared ($\chi^2$) distribution.
///
/// See https://en.wikipedia.org/wiki/Chi-squared_distribution.
class ChiSquaredDistribution extends ContinuousDistribution {
  /// A Chi-squared distribution with degrees of freedom [dof] k.
  const new(this.dof) : assert(dof > 0, 'k > 0');

  /// Fits a Chi-squared distribution to [samples] using maximum likelihood estimation.
  factory fit(Iterable<num> samples) {
    var count = 0;
    var sum = 0.0;
    for (final x in samples) {
      if (x < 0) {
        throw ArgumentError.value(
          x,
          'samples',
          'Chi-squared samples must be non-negative',
        );
      }
      count++;
      sum += x;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final k = sum / count;
    return ChiSquaredDistribution(k > 0 ? k : 1.0);
  }

  /// The degrees of freedom k.
  final double dof;

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => dof;

  @override
  double get median => dof * pow(1.0 - 2.0 / (9.0 * dof), 3).toDouble();

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
    if (x <= 0.0) return 0.0;
    final kHalf = 0.5 * dof;
    return exp((kHalf - 1.0) * log(x) - 0.5 * x - kHalf * ln2 - gammaLn(kHalf));
  }

  @override
  double cumulativeProbability(double x) =>
      x <= 0.0 ? 0.0 : lowRegGamma(0.5 * dof, 0.5 * x);

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    return gammapInv(p, 0.5 * dof) * 2.0;
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
