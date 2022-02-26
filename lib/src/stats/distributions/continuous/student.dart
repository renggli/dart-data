import 'dart:math';

import '../../../../data.dart';
import '../../../special/beta.dart';
import '../../../special/gamma.dart';
import '../continuous.dart';

/// Student's t-distribution.
///
/// For details see https://en.wikipedia.org/wiki/Student%27s_t-distribution
class StudentDistribution extends ContinuousDistribution {
  /// A Student's t-distribution with degrees of freedom.
  const StudentDistribution(this.v) : assert(v > 0);

  /// The degrees of freedom.
  final double v;

  @override
  double get mean => v > 1.0 ? 0.0 : double.nan;

  @override
  double get median => 0;

  @override
  double get mode => 0;

  @override
  double get variance => v > 2
      ? v / (v - 2)
      : v > 1
          ? double.infinity
          : double.nan;

  @override
  double probability(double x) =>
      exp(logGamma(0.5 * (v + 1.0)) - logGamma(0.5 * v)) /
      (sqrt(v * pi) * pow(1.0 + x * x / v, 0.5 * (v + 1.0)));

  @override
  double cumulativeProbability(double x) => incompleteBeta(
      (x + sqrt(x * x + v)) / (2.0 * sqrt(x * x + v)), 0.5 * v, 0.5 * v);

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    var x = incompleteBetaInv(2.0 * min(p, 1.0 - p), 0.5 * v, 0.5);
    x = sqrt(v * (1.0 - x) / x);
    return p > 0.5 ? x : -x;
  }

  @override
  double sample({Random? random}) => throw UnimplementedError();

  @override
  bool operator ==(Object other) =>
      other is StudentDistribution && v == other.v;

  @override
  int get hashCode => v.hashCode;

  @override
  String toString() => 'StudentDistribution{v: $v}';
}
