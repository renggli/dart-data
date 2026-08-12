import 'dart:math';

import 'package:more/printer.dart';

import '../continuous.dart';
import 'gamma.dart';

/// The Chi-squared distribution (also chi-square or χ2-distribution) with
/// [dof] degrees of freedom is a special case of the Gamma distribution.
///
/// See https://en.wikipedia.org/wiki/Chi-squared_distribution.
///
/// ```dart
/// final distribution = ChiSquaredDistribution(5);
/// print(distribution.mean);  // 5.0
/// ```
class ChiSquaredDistribution extends ContinuousDistribution {
  /// A Chi-squared distribution with parameter [dof].
  const new(this.dof) : assert(dof > 0, 'dof > 0');

  /// The degrees of freedom parameter.
  final double dof;

  GammaDistribution get _gamma => GammaDistribution(dof / 2, 2);

  @override
  double get lowerBound => 0.0;

  @override
  double get mean => dof;

  @override
  double get median => _gamma.median;

  @override
  double get mode => dof > 2 ? dof - 2 : double.nan;

  @override
  double get variance => 2 * dof;

  @override
  double get skewness => sqrt(8 / dof);

  @override
  double get kurtosisExcess => 12 / dof;

  @override
  double probability(double x) => _gamma.probability(x);

  @override
  double cumulativeProbability(double x) => _gamma.cumulativeProbability(x);

  @override
  double inverseCumulativeProbability(num p) =>
      _gamma.inverseCumulativeProbability(p);

  @override
  double sample({Random? random}) => _gamma.sample(random: random);

  @override
  bool operator ==(Object other) =>
      other is ChiSquaredDistribution && dof == other.dof;

  @override
  int get hashCode => Object.hash(ChiSquaredDistribution, dof);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(dof, name: 'dof');
}
