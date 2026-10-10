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
  /// A Student's t-distribution with degrees of freedom [dof] ν.
  const new(this.dof) : assert(dof > 0, 'ν > 0');

  /// Fits a Student's t-distribution to [samples] using maximum likelihood estimation.
  factory fit(Iterable<num> samples) {
    final list = samples.map((val) => val.toDouble()).toList();
    if (list.length < 3) {
      throw ArgumentError.value(
        samples,
        'samples',
        'At least 3 samples required to fit Student-t distribution',
      );
    }
    final sampleCount = list.length;
    double logLikelihood(double nu) {
      final term1 =
          sampleCount *
          (gammaLn(0.5 * (nu + 1.0)) - gammaLn(0.5 * nu) - 0.5 * log(nu * pi));
      var term2 = 0.0;
      for (final x in list) {
        term2 += log(1.0 + (x * x) / nu);
      }
      return term1 - 0.5 * (nu + 1.0) * term2;
    }

    var a = 0.1;
    var b = 100.0;
    const phi = 0.618033988749895;
    var x1 = b - phi * (b - a);
    var x2 = a + phi * (b - a);
    var f1 = logLikelihood(x1);
    var f2 = logLikelihood(x2);

    for (var iter = 0; iter < 60; iter++) {
      if ((b - a).abs() < 1e-5) break;
      if (f1 > f2) {
        b = x2;
        x2 = x1;
        f2 = f1;
        x1 = b - phi * (b - a);
        f1 = logLikelihood(x1);
      } else {
        a = x1;
        x1 = x2;
        f1 = f2;
        x2 = a + phi * (b - a);
        f2 = logLikelihood(x2);
      }
    }
    final bestNu = 0.5 * (a + b);
    return StudentDistribution(bestNu);
  }

  /// The degrees of freedom ν.
  final double dof;

  @override
  double get mean => dof > 1.0 ? 0.0 : double.nan;

  @override
  double get median => 0.0;

  @override
  double get mode => 0.0;

  @override
  double get variance => dof > 2.0
      ? dof / (dof - 2.0)
      : dof > 1.0
      ? double.infinity
      : double.nan;

  @override
  double get skewness => dof > 3.0 ? 0.0 : double.nan;

  @override
  double get excessKurtosis => dof > 4.0
      ? 6.0 / (dof - 4.0)
      : dof > 2.0
      ? double.infinity
      : double.nan;

  @override
  double probability(double x) =>
      exp(gammaLn(0.5 * (dof + 1.0)) - gammaLn(0.5 * dof)) /
      (sqrt(dof * pi) * pow(1.0 + x * x / dof, 0.5 * (dof + 1.0)));

  @override
  double cumulativeProbability(double x) => ibeta(
    (x + sqrt(x * x + dof)) / (2.0 * sqrt(x * x + dof)),
    0.5 * dof,
    0.5 * dof,
  );

  @override
  double inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    var x = ibetaInv(2.0 * min(probability, 1.0 - probability), 0.5 * dof, 0.5);
    x = sqrt(dof * (1.0 - x) / x);
    return probability > 0.5 ? x : -x;
  }

  @override
  double sample({Random? random}) {
    const normal = NormalDistribution.standard();
    final gamma = GammaDistribution.shape(0.5 * dof);
    return normal.sample(random: random) *
        sqrt(dof / (2.0 * gamma.sample(random: random)));
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
