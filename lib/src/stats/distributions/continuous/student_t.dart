import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/beta.dart';
import '../../../special/gamma.dart';
import '../continuous.dart';
import '../errors.dart';
import 'gamma.dart';
import 'normal.dart';

/// The Student's t-distribution.
///
/// See https://en.wikipedia.org/wiki/Student%27s_t-distribution.
class StudentDistribution extends ContinuousDistribution {
  /// A Student's t-distribution with degrees of freedom ν.
  const StudentDistribution(this.dof) : assert(dof > 0, 'ν > 0');

  /// The degrees of freedom ν.
  final double dof;

  @override
  double get mean => dof > 1 ? 0 : double.nan;

  @override
  double get median => 0;

  @override
  double get mode => 0;

  @override
  double get variance => dof > 2
      ? dof / (dof - 2)
      : dof > 1
          ? double.infinity
          : double.nan;

  @override
  double get skewness => dof > 3 ? 0 : double.nan;

  @override
  double get kurtosisExcess => dof > 4
      ? 6 / (dof - 2)
      : dof >= 2
          ? double.infinity
          : double.nan;

  @override
  double probability(double x) =>
      exp(gammaLn(0.5 * (dof + 1)) - gammaLn(0.5 * dof)) /
      (sqrt(dof * pi) * pow(1 + x * x / dof, 0.5 * (dof + 1)));

  @override
  double cumulativeProbability(double x) => ibeta(
      (x + sqrt(x * x + dof)) / (2 * sqrt(x * x + dof)), 0.5 * dof, 0.5 * dof);

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    var x = ibetaInv(2 * min(p, 1 - p), 0.5 * dof, 0.5);
    x = sqrt(dof * (1 - x) / x);
    return p > 0.5 ? x : -x;
  }

  @override
  double sample({Random? random}) {
    const normal = NormalDistribution.standard();
    final gamma = GammaDistribution.shape(0.5 * dof);
    return normal.sample(random: random) *
        sqrt(dof / (2 * gamma.sample(random: random)));
  }

  @override
  bool operator ==(Object other) =>
      other is StudentDistribution && dof == other.dof;

  @override
  int get hashCode => Object.hash(StudentDistribution, dof);

  @override
  ObjectPrinter get toStringPrinter =>
      super.toStringPrinter..addValue(dof, name: 'ν');
}
