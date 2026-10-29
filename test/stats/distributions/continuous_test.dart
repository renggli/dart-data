import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('ContinuousDistribution contracts and properties', () {
    test('bounds, equality, hashCode, and default random sampling', () {
      // Cauchy
      final cauchy = CauchyDistribution(0.0, 1.0);
      check(cauchy.lowerBound).equals(double.negativeInfinity);
      check(cauchy.upperBound).equals(double.infinity);
      check(cauchy == CauchyDistribution(0.0, 1.0)).isTrue();
      check(cauchy.hashCode).equals(CauchyDistribution(0.0, 1.0).hashCode);
      check(cauchy.sample().isFinite).isTrue();

      // Laplace
      final laplace = LaplaceDistribution(0.0, 1.0);
      check(laplace.lowerBound).equals(double.negativeInfinity);
      check(laplace.upperBound).equals(double.infinity);
      check(laplace == LaplaceDistribution(0.0, 1.0)).isTrue();
      check(laplace.hashCode).equals(LaplaceDistribution(0.0, 1.0).hashCode);
      check(laplace.sample().isFinite).isTrue();

      // Logistic
      final logistic = LogisticDistribution(0.0, 1.0);
      check(logistic.lowerBound).equals(double.negativeInfinity);
      check(logistic.upperBound).equals(double.infinity);
      check(logistic == LogisticDistribution(0.0, 1.0)).isTrue();
      check(logistic.hashCode).equals(LogisticDistribution(0.0, 1.0).hashCode);
      check(logistic.sample().isFinite).isTrue();

      // Degenerate
      final degen = DegenerateDistribution(5.0);
      check(degen.lowerBound).equals(5.0);
      check(degen.upperBound).equals(5.0);
      check(degen == DegenerateDistribution(5.0)).isTrue();
      check(degen.hashCode).equals(DegenerateDistribution(5.0).hashCode);
      check(degen.sample()).equals(5.0);

      // LogNormal
      final logNormal = LogNormalDistribution(0.0, 1.0);
      check(logNormal.lowerBound).equals(0.0);
      check(logNormal.cumulativeProbability(1e-10)).isGreaterThan(0.0);

      // Student-t large dof does not underflow to 0
      final student500 = StudentDistribution(500.0);
      check(student500.probability(0.0)).isCloseTo(0.39874, 1e-4);

      // ChiSquared at x == 0
      check(ChiSquaredDistribution(1.0).probability(0.0))
          .equals(double.infinity);
      check(ChiSquaredDistribution(2.0).probability(0.0)).equals(0.5);
      check(ChiSquaredDistribution(3.0).probability(0.0)).equals(0.0);

      // Beta
      final beta = BetaDistribution(2.0, 2.0);
      check(beta.lowerBound).equals(0.0);
      check(beta.upperBound).equals(1.0);
      check(beta == BetaDistribution(2.0, 2.0)).isTrue();
      check(beta.hashCode).equals(BetaDistribution(2.0, 2.0).hashCode);
      check(beta.sample() >= 0.0 && beta.sample() <= 1.0).isTrue();

      // Inverse Gamma
      final invGamma = InverseGammaDistribution(2.0, 1.0);
      check(invGamma.sample() > 0.0).isTrue();
    });
  });

  group('ContinuousDistribution logProbability', () {
    test('evaluates exact log probability density', () {
      const normal = NormalDistribution.standard();
      check(normal.logProbability(0.0))
          .isCloseTo(math.log(normal.probability(0.0)), 1e-12);
      check(normal.logProbability(1.5))
          .isCloseTo(math.log(normal.probability(1.5)), 1e-12);

      final exp = ExponentialDistribution(2.0);
      check(exp.logProbability(1.0))
          .isCloseTo(math.log(exp.probability(1.0)), 1e-12);
    });

    test('NaN and Infinity validation and evaluation edge cases', () {
      check(() => BetaDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => CauchyDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => ChiSquaredDistribution(double.nan)).throws<ArgumentError>();
      check(() => ExponentialDistribution(double.nan)).throws<ArgumentError>();
      check(() => FDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => GammaDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => InverseGammaDistribution(double.nan, 1.0))
          .throws<ArgumentError>();
      check(() => LaplaceDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => LogNormalDistribution(double.nan, 1.0))
          .throws<ArgumentError>();
      check(() => LogisticDistribution(double.nan, 1.0))
          .throws<ArgumentError>();
      check(() => NormalDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => ParetoDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => StudentDistribution(double.nan)).throws<ArgumentError>();
      check(() => UniformDistribution(double.nan, 1.0)).throws<ArgumentError>();
      check(() => WeibullDistribution(double.nan, 1.0)).throws<ArgumentError>();

      check(DegenerateDistribution(5.0).probability(double.nan)).isNaN();
      check(DegenerateDistribution(5.0).cumulativeProbability(double.nan))
          .isNaN();
      check(ExponentialDistribution(1.0).probability(double.nan)).isNaN();
      check(ExponentialDistribution(1.0).cumulativeProbability(double.nan))
          .isNaN();
      check(UniformDistribution(0.0, 1.0).probability(double.nan)).isNaN();
      check(UniformDistribution(0.0, 1.0).cumulativeProbability(double.nan))
          .isNaN();
      check(GammaDistribution(2.0, 1.0).probability(double.infinity))
          .equals(0.0);
      check(WeibullDistribution(2.0, 1.0).probability(double.infinity))
          .equals(0.0);
      check(FDistribution(2.0, 2.0).probability(double.infinity)).equals(0.0);
    });
  });
}
