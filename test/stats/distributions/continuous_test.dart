import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('continuous distributions', () {
    test('normal distribution', () {
      const dist = NormalDistribution.standard();
      check(dist.mean).equals(0.0);
      check(dist.standardDeviation).equals(1.0);
      check(dist.variance).equals(1.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(0.0);
      check(dist.excessKurtosis).equals(0.0);
      check(dist.lowerBound).equals(double.negativeInfinity);
      check(dist.upperBound).equals(double.infinity);
      check(dist.isLowerBoundOpen).isTrue();
      check(dist.isUpperBoundOpen).isTrue();

      // PDF at x = 0 is 1 / sqrt(2*pi) ≈ 0.39894228
      check(dist.probability(0.0))
          .isCloseTo(1.0 / math.sqrt(2 * math.pi), 1e-6);
      check(dist.cumulativeProbability(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.cumulativeProbability(1.96))
          .isCloseTo(0.9750021048517795, 1e-12);
      check(dist.cumulativeProbability(-10.0)).isGreaterThan(0.0);
      check(dist.survival(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.survival(1.96)).isCloseTo(1.0 - 0.9750021048517795, 1e-12);
      check(dist.survival(10.0)).isGreaterThan(0.0);
      check(dist.inverseCumulativeProbability(0.5)).isCloseTo(0.0, 1e-6);
      check(dist.inverseSurvival(0.5)).isCloseTo(0.0, 1e-6);
      check(dist.inverseCumulativeProbability(0.975)).isCloseTo(1.95996, 1e-4);
      check(dist.inverseCumulativeProbability(0.025)).isCloseTo(-1.95996, 1e-4);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();
      check(() => dist.inverseCumulativeProbability(1.1))
          .throws<InvalidProbability>();

      // Sample & fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = NormalDistribution.fit(samples);
      check(fitted.mean).isCloseTo(0.0, 0.1);
      check(fitted.standardDeviation).isCloseTo(1.0, 0.1);

      // Fit identical samples
      final fittedSame = NormalDistribution.fit(const [5.0, 5.0]);
      check(fittedSame.mean).equals(5.0);

      // Fit error
      check(() => NormalDistribution.fit(const [1.0])).throws<ArgumentError>();

      // Constructor validation
      check(() => NormalDistribution(0.0, 0.0)).throws<ArgumentError>();
      check(() => NormalDistribution(0.0, -1.0)).throws<ArgumentError>();

      // Equality and toString
      final dist2 = NormalDistribution(0.0, 1.0);
      check(dist == dist2).isTrue();
      check(dist.hashCode).equals(dist2.hashCode);
      check(dist.toString()).contains('NormalDistribution');
    });

    test('Student t-distribution', () {
      final dist = StudentDistribution(10.0);
      check(dist.dof).equals(10.0);
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance).isCloseTo(10.0 / 8.0, 1e-6);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).isCloseTo(6.0 / 6.0, 1e-6);
      check(dist.probability(0.0)).isGreaterThan(0.3);
      check(dist.cumulativeProbability(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.inverseCumulativeProbability(0.5)).isCloseTo(0.0, 1e-6);
      // For df = 10, t_0.975 ≈ 2.2281
      check(dist.inverseCumulativeProbability(0.975)).isCloseTo(2.2281, 1e-3);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Degenerate moments for small dof
      final distDof1 = StudentDistribution(1.0);
      check(distDof1.mean.isNaN).isTrue();
      check(distDof1.variance.isNaN).isTrue();
      check(distDof1.skewness.isNaN).isTrue();
      check(distDof1.excessKurtosis.isNaN).isTrue();

      final distDof2 = StudentDistribution(2.0);
      check(distDof2.mean).equals(0.0);
      check(distDof2.variance.isInfinite).isTrue();

      final distDof3 = StudentDistribution(3.0);
      check(distDof3.skewness.isNaN).isTrue();
      check(distDof3.excessKurtosis.isInfinite).isTrue();

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final fitted = StudentDistribution.fit(samples);
      check(fitted.dof).isCloseTo(10.0, 3.5);
      check(() => StudentDistribution.fit(const [1.0, 2.0]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => StudentDistribution(0.0)).throws<ArgumentError>();
      check(() => StudentDistribution(-1.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == StudentDistribution(10.0)).isTrue();
      check(dist.hashCode).equals(StudentDistribution(10.0).hashCode);
      check(dist.toString()).contains('StudentDistribution');
    });

    test('Chi-squared distribution', () {
      final dist = ChiSquaredDistribution(5.0);
      check(dist.dof).equals(5.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.mean).equals(5.0);
      check(dist.median).isGreaterThan(4.0);
      check(dist.mode).equals(3.0);
      check(dist.variance).equals(10.0);
      check(dist.skewness).isCloseTo(math.sqrt(8.0 / 5.0), 1e-6);
      check(dist.excessKurtosis).isCloseTo(12.0 / 5.0, 1e-6);

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(2.0)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(5.0)).isGreaterThan(0.4);
      check(dist.cumulativeProbability(5.0)).isLessThan(0.6);

      // Mode when dof < 2
      final distSmall = ChiSquaredDistribution(1.0);
      check(distSmall.mode).equals(0.0);

      // Quantile roundtrip
      const prob = 0.95;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = ChiSquaredDistribution.fit(samples);
      check(fitted.dof).isCloseTo(5.0, 0.5);
      check(() => ChiSquaredDistribution.fit(const [])).throws<ArgumentError>();
      check(() => ChiSquaredDistribution.fit(const [-1.0]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => ChiSquaredDistribution(0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == ChiSquaredDistribution(5.0)).isTrue();
      check(dist.hashCode).equals(ChiSquaredDistribution(5.0).hashCode);
      check(dist.toString()).contains('ChiSquaredDistribution');
    });

    test('F-distribution', () {
      final dist = FDistribution(10.0, 20.0);
      check(dist.d1).equals(10.0);
      check(dist.d2).equals(20.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).isCloseTo(20.0 / 18.0, 1e-6);
      check(dist.cumulativeProbability(dist.median)).isCloseTo(0.5, 1e-4);
      check(dist.mode).isGreaterThan(0.0);
      check(dist.variance).isGreaterThan(0.0);
      check(dist.skewness).isGreaterThan(0.0);
      check(dist.excessKurtosis).isGreaterThan(0.0);

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(1.0)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(1.0)).isGreaterThan(0.4);
      check(dist.cumulativeProbability(1.0)).isLessThan(0.6);

      // Edge cases for moments
      final distSmallD2 = FDistribution(1.0, 2.0);
      check(distSmallD2.mean.isNaN).isTrue();
      check(distSmallD2.variance.isNaN).isTrue();
      check(distSmallD2.skewness.isNaN).isTrue();
      check(distSmallD2.excessKurtosis.isNaN).isTrue();
      check(distSmallD2.mode).equals(0.0);

      // Quantile roundtrip
      const prob = 0.90;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-4);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(2000).toList();
      final fitted = FDistribution.fit(samples);
      check(fitted.d1).isCloseTo(10.0, 6.0);
      check(fitted.d2).isCloseTo(20.0, 8.0);
      check(() => FDistribution.fit(const [1.0, 2.0, 3.0]))
          .throws<ArgumentError>();
      check(() => FDistribution.fit(const [-1.0, 2.0, 3.0, 4.0]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => FDistribution(0.0, 5.0)).throws<ArgumentError>();
      check(() => FDistribution(5.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == FDistribution(10.0, 20.0)).isTrue();
      check(dist.hashCode).equals(FDistribution(10.0, 20.0).hashCode);
      check(dist.toString()).contains('FDistribution');
    });

    test('exponential distribution', () {
      final dist = ExponentialDistribution(2.0);
      check(dist.rate).equals(2.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).equals(0.5);
      check(dist.median).isCloseTo(math.ln2 / 2.0, 1e-6);
      check(dist.mode).equals(0.0);
      check(dist.variance).equals(0.25);
      check(dist.skewness).equals(2.0);
      check(dist.excessKurtosis).equals(6.0);

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(0.0)).equals(2.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(0.5))
          .isCloseTo(1.0 - math.exp(-1.0), 1e-6);
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(dist.median, 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = ExponentialDistribution.fit(samples);
      check(fitted.rate).isCloseTo(2.0, 0.2);
      check(() => ExponentialDistribution.fit(const []))
          .throws<ArgumentError>();
      check(() => ExponentialDistribution.fit(const [-1.0]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => ExponentialDistribution(0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == ExponentialDistribution(2.0)).isTrue();
      check(dist.hashCode).equals(ExponentialDistribution(2.0).hashCode);
      check(dist.toString()).contains('ExponentialDistribution');
    });

    test('gamma distribution', () {
      final dist = GammaDistribution(3.0, 2.0);
      check(dist.shape).equals(3.0);
      check(dist.scale).equals(2.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).equals(6.0);
      check(dist.cumulativeProbability(dist.median)).isCloseTo(0.5, 1e-4);
      check(dist.mode).equals(4.0);
      check(dist.variance).equals(12.0);
      check(dist.skewness).isCloseTo(2.0 / math.sqrt(3.0), 1e-6);
      check(dist.excessKurtosis).isCloseTo(6.0 / 3.0, 1e-6);

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(4.0)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);

      // Mode when shape < 1
      final distSmallShape = GammaDistribution(0.5, 2.0);
      check(distSmallShape.mode).equals(0.0);
      // Sample when shape < 1
      final smallSamples = distSmallShape
          .samples(random: math.Random(42))
          .take(10)
          .toList();
      check(smallSamples.every((sample) => sample >= 0)).isTrue();

      // Standard constructor
      final distStd = GammaDistribution.shape(4.0);
      check(distStd.scale).equals(1.0);

      // Quantile roundtrip
      const prob = 0.8;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = GammaDistribution.fit(samples);
      check(fitted.shape).isCloseTo(3.0, 0.5);
      check(fitted.scale).isCloseTo(2.0, 0.5);
      check(() => GammaDistribution.fit(const [1.0])).throws<ArgumentError>();
      check(() => GammaDistribution.fit(const [-1.0, 2.0]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => GammaDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => GammaDistribution(1.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == GammaDistribution(3.0, 2.0)).isTrue();
      check(dist.hashCode).equals(GammaDistribution(3.0, 2.0).hashCode);
      check(dist.toString()).contains('GammaDistribution');
    });

    test('beta distribution', () {
      final dist = BetaDistribution(2.0, 5.0);
      check(dist.alpha).equals(2.0);
      check(dist.beta).equals(5.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.upperBound).equals(1.0);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();
      check(dist.mean).isCloseTo(2.0 / 7.0, 1e-6);
      check(dist.cumulativeProbability(dist.median)).isCloseTo(0.5, 1e-4);
      check(dist.mode).isCloseTo(1.0 / 5.0, 1e-6);
      check(dist.variance).isCloseTo(10.0 / (49.0 * 8.0), 1e-6);
      check(dist.skewness).isGreaterThan(0.0);
      check(dist.excessKurtosis).isA<double>();

      // Symmetric beta
      final distSym = BetaDistribution(3.0, 3.0);
      check(distSym.median).equals(0.5);

      // Mode when alpha <= 1 or beta <= 1
      final distFlat = BetaDistribution(0.5, 0.5);
      check(distFlat.mode.isNaN).isTrue();

      // PDF boundary checks
      check(dist.probability(-0.5)).equals(0.0);
      check(dist.probability(1.5)).equals(0.0);
      check(dist.probability(0.0)).equals(0.0);
      check(dist.probability(1.0)).equals(0.0);
      check(dist.probability(0.2)).isGreaterThan(0.0);

      final distAlpha1 = BetaDistribution(1.0, 2.0);
      check(distAlpha1.probability(0.0)).equals(2.0);
      final distBeta1 = BetaDistribution(2.0, 1.0);
      check(distBeta1.probability(1.0)).equals(2.0);

      final distAlphaSmall = BetaDistribution(0.5, 2.0);
      check(distAlphaSmall.probability(0.0).isInfinite).isTrue();
      final distBetaSmall = BetaDistribution(2.0, 0.5);
      check(distBetaSmall.probability(1.0).isInfinite).isTrue();

      check(dist.cumulativeProbability(-0.5)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(1.0)).equals(1.0);
      check(dist.cumulativeProbability(1.5)).equals(1.0);

      // Quantile roundtrip
      const prob = 0.75;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Fit
      final samples = dist.samples(random: math.Random(42)).take(1000).toList();
      final fitted = BetaDistribution.fit(samples);
      check(fitted.alpha).isCloseTo(2.0, 0.4);
      check(fitted.beta).isCloseTo(5.0, 1.0);
      check(() => BetaDistribution.fit(const [0.5])).throws<ArgumentError>();
      check(() => BetaDistribution.fit(const [0.0, 0.5]))
          .throws<ArgumentError>();
      check(() => BetaDistribution.fit(const [0.5, 1.0]))
          .throws<ArgumentError>();

      // Constructor validation
      check(() => BetaDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => BetaDistribution(1.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == BetaDistribution(2.0, 5.0)).isTrue();
      check(dist.hashCode).equals(BetaDistribution(2.0, 5.0).hashCode);
      check(dist.toString()).contains('BetaDistribution');
    });

    test('uniform distribution', () {
      final dist = UniformDistribution(10.0, 20.0);
      check(dist.min).equals(10.0);
      check(dist.max).equals(20.0);
      check(dist.lowerBound).equals(10.0);
      check(dist.upperBound).equals(20.0);
      check(dist.isLowerBoundOpen).isFalse();
      check(dist.isUpperBoundOpen).isFalse();
      check(dist.mean).equals(15.0);
      check(dist.median).equals(15.0);
      check(dist.mode.isNaN).isTrue();
      check(dist.variance).isCloseTo(100.0 / 12.0, 1e-6);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(-1.2);

      check(dist.probability(15.0)).equals(0.1);
      check(dist.probability(5.0)).equals(0.0);
      check(dist.probability(25.0)).equals(0.0);
      check(dist.cumulativeProbability(5.0)).equals(0.0);
      check(dist.cumulativeProbability(15.0)).equals(0.5);
      check(dist.cumulativeProbability(25.0)).equals(1.0);
      check(dist.inverseCumulativeProbability(0.5)).equals(15.0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Standard constructor
      const stdUniform = UniformDistribution.standard();
      check(stdUniform.min).equals(0.0);
      check(stdUniform.max).equals(1.0);

      // Fit
      final samples = [10.5, 12.0, 15.0, 19.5];
      final fitted = UniformDistribution.fit(samples);
      check(fitted.min).equals(10.5);
      check(fitted.max).equals(19.5);
      check(UniformDistribution.fit(const [5.0]).max).equals(6.0);
      check(() => UniformDistribution.fit(const [])).throws<ArgumentError>();

      // Constructor validation
      check(() => UniformDistribution(20.0, 10.0)).throws<ArgumentError>();
      check(() => UniformDistribution(10.0, 10.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == UniformDistribution(10.0, 20.0)).isTrue();
      check(dist.hashCode).equals(UniformDistribution(10.0, 20.0).hashCode);
      check(dist.toString()).contains('UniformDistribution');
    });

    test('inverse gamma distribution', () {
      final dist = InverseGammaDistribution(4.0, 6.0);
      check(dist.shape).equals(4.0);
      check(dist.scale).equals(6.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).isCloseTo(2.0, 1e-6);
      check(dist.cumulativeProbability(dist.median)).isCloseTo(0.5, 1e-4);
      check(dist.mode).isCloseTo(1.2, 1e-6);
      check(dist.variance).isCloseTo(2.0, 1e-6);
      check(dist.skewness).isCloseTo(4.0 * math.sqrt(2.0), 1e-6);
      check(dist.excessKurtosis).isA<double>();

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(0.0)).equals(0.0);
      check(dist.probability(1.2)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);

      // Moments edge cases for small shape
      final distSmall1 = InverseGammaDistribution(0.5, 1.0);
      check(distSmall1.mean.isNaN).isTrue();
      check(distSmall1.variance.isNaN).isTrue();
      check(distSmall1.skewness.isNaN).isTrue();
      check(distSmall1.excessKurtosis.isNaN).isTrue();

      final distSmall2 = InverseGammaDistribution(1.5, 1.0);
      check(distSmall2.mean).isGreaterThan(0.0);
      check(distSmall2.variance.isNaN).isTrue();

      final distSmall3 = InverseGammaDistribution(2.5, 1.0);
      check(distSmall3.variance).isGreaterThan(0.0);
      check(distSmall3.skewness.isNaN).isTrue();

      final distSmall4 = InverseGammaDistribution(3.5, 1.0);
      check(distSmall4.skewness).isGreaterThan(0.0);
      check(distSmall4.excessKurtosis.isNaN).isTrue();

      const prob = 0.5;
      final quant = dist.inverseCumulativeProbability(prob);
      check(dist.cumulativeProbability(quant)).isCloseTo(prob, 1e-5);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample > 0)).isTrue();

      // Constructor validation
      check(() => InverseGammaDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => InverseGammaDistribution(1.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == InverseGammaDistribution(4.0, 6.0)).isTrue();
      check(dist.hashCode).equals(InverseGammaDistribution(4.0, 6.0).hashCode);
      check(dist.toString()).contains('InverseGammaDistribution');
    });

    test('Cauchy distribution', () {
      final dist = CauchyDistribution(0.0, 1.0);
      check(dist.location).equals(0.0);
      check(dist.scale).equals(1.0);
      check(dist.mean.isNaN).isTrue();
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance.isNaN).isTrue();
      check(dist.skewness.isNaN).isTrue();
      check(dist.excessKurtosis.isNaN).isTrue();

      check(dist.probability(0.0)).isCloseTo(1.0 / math.pi, 1e-6);
      check(dist.cumulativeProbability(0.0)).isCloseTo(0.5, 1e-6);
      check(dist.inverseCumulativeProbability(0.5)).isCloseTo(0.0, 1e-6);
      check(dist.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Default constructor
      const defaultCauchy = CauchyDistribution.standard();
      check(defaultCauchy.location).equals(0.0);
      check(defaultCauchy.scale).equals(1.0);

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.isNotEmpty).isTrue();

      // Constructor validation
      check(() => CauchyDistribution(0.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == CauchyDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(CauchyDistribution(0.0, 1.0).hashCode);
      check(dist.toString()).contains('CauchyDistribution');
    });

    test('Degenerate distribution', () {
      const dist = DegenerateDistribution(5.0);
      check(dist.k).equals(5.0);
      check(dist.mean).equals(5.0);
      check(dist.median).equals(5.0);
      check(dist.mode).equals(5.0);
      check(dist.variance).equals(0.0);
      check(dist.standardDeviation).equals(0.0);
      check(dist.skewness.isNaN).isTrue();
      check(dist.excessKurtosis.isNaN).isTrue();

      check(dist.probability(5.0)).equals(1.0);
      check(dist.probability(3.0)).equals(0.0);
      check(dist.cumulativeProbability(4.0)).equals(0.0);
      check(dist.cumulativeProbability(5.0)).equals(1.0);
      check(dist.cumulativeProbability(6.0)).equals(1.0);
      check(dist.inverseCumulativeProbability(0.5)).equals(5.0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Default constructor
      const defaultDegenerate = DegenerateDistribution();
      check(defaultDegenerate.k).equals(0.0);

      // Samples
      final samples = dist.samples().take(10).toList();
      check(samples.every((sample) => sample == 5.0)).isTrue();

      // Equality and toString
      check(dist == const DegenerateDistribution(5.0)).isTrue();
      check(dist.hashCode).equals(const DegenerateDistribution(5.0).hashCode);
      check(dist.toString()).contains('DegenerateDistribution');
    });

    test('Laplace distribution', () {
      final dist = LaplaceDistribution(0.0, 1.0);
      check(dist.location).equals(0.0);
      check(dist.scale).equals(1.0);
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance).equals(2.0);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(3.0);

      check(dist.probability(0.0)).equals(0.5);
      check(dist.cumulativeProbability(0.0)).equals(0.5);
      check(dist.cumulativeProbability(-1.0))
          .isCloseTo(0.5 * math.exp(-1.0), 1e-6);
      check(dist.cumulativeProbability(1.0))
          .isCloseTo(1.0 - 0.5 * math.exp(-1.0), 1e-6);

      check(dist.inverseCumulativeProbability(0.5)).equals(0.0);
      check(dist.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(dist.inverseCumulativeProbability(0.25)).isLessThan(0.0);
      check(dist.inverseCumulativeProbability(0.75)).isGreaterThan(0.0);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Default constructor
      const defaultLaplace = LaplaceDistribution.standard();
      check(defaultLaplace.location).equals(0.0);
      check(defaultLaplace.scale).equals(1.0);

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.isNotEmpty).isTrue();

      // Constructor validation
      check(() => LaplaceDistribution(0.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == LaplaceDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(LaplaceDistribution(0.0, 1.0).hashCode);
      check(dist.toString()).contains('LaplaceDistribution');
    });

    test('Log-normal distribution', () {
      final dist = LogNormalDistribution(0.0, 1.0);
      check(dist.mu).equals(0.0);
      check(dist.sigma).equals(1.0);
      check(dist.lowerBound).equals(double.negativeInfinity);
      check(dist.mean).isCloseTo(math.exp(0.5), 1e-6);
      check(dist.median).equals(1.0);
      check(dist.mode).isCloseTo(math.exp(-1.0), 1e-6);
      check(dist.variance).isCloseTo((math.e - 1.0) * math.e, 1e-6);
      check(dist.skewness).isGreaterThan(0.0);
      check(dist.excessKurtosis).isGreaterThan(0.0);

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(0.0)).equals(0.0);
      check(dist.probability(1.0)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(1.0)).isCloseTo(0.5, 1e-6);
      check(dist.inverseCumulativeProbability(0.5)).isCloseTo(1.0, 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Samples
      final sample = dist.sample(random: math.Random(42));
      check(sample).isGreaterThan(0.0);

      // Constructor validation
      check(() => LogNormalDistribution(0.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == LogNormalDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(LogNormalDistribution(0.0, 1.0).hashCode);
      check(dist.toString()).contains('LogNormalDistribution');
    });

    test('Logistic distribution', () {
      final dist = LogisticDistribution(0.0, 1.0);
      check(dist.location).equals(0.0);
      check(dist.scale).equals(1.0);
      check(dist.mean).equals(0.0);
      check(dist.median).equals(0.0);
      check(dist.mode).equals(0.0);
      check(dist.variance).isCloseTo(math.pi * math.pi / 3.0, 1e-6);
      check(dist.skewness).equals(0.0);
      check(dist.excessKurtosis).equals(1.2);

      check(dist.probability(0.0)).equals(0.25);
      check(dist.cumulativeProbability(0.0)).equals(0.5);
      check(dist.inverseCumulativeProbability(0.5)).equals(0.0);
      check(dist.inverseCumulativeProbability(0.0))
          .equals(double.negativeInfinity);
      check(dist.inverseCumulativeProbability(1.0)).equals(double.infinity);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Default constructor
      const defaultLogistic = LogisticDistribution.standard();
      check(defaultLogistic.location).equals(0.0);
      check(defaultLogistic.scale).equals(1.0);

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.isNotEmpty).isTrue();

      // Constructor validation
      check(() => LogisticDistribution(0.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == LogisticDistribution(0.0, 1.0)).isTrue();
      check(dist.hashCode).equals(LogisticDistribution(0.0, 1.0).hashCode);
      check(dist.toString()).contains('LogisticDistribution');
    });

    test('Pareto distribution', () {
      final dist = ParetoDistribution(3.0, 1.0);
      check(dist.scale).equals(1.0);
      check(dist.shape).equals(3.0);
      check(dist.lowerBound).equals(1.0);
      check(dist.mean).isCloseTo(1.5, 1e-6);
      check(dist.median).isCloseTo(math.pow(2.0, 1.0 / 3.0), 1e-6);
      check(dist.mode).equals(1.0);
      check(dist.variance).isCloseTo(3.0 / 4.0, 1e-6);
      check(dist.skewness.isNaN).isTrue(); // shape <= 3 gives nan
      check(dist.excessKurtosis.isNaN).isTrue(); // shape <= 4 gives nan

      // Edge moments
      final distAlpha1 = ParetoDistribution(1.0, 1.0);
      check(distAlpha1.mean.isInfinite).isTrue();
      check(distAlpha1.variance.isNaN).isTrue();

      final distAlpha2 = ParetoDistribution(1.5, 1.0);
      check(distAlpha2.variance.isInfinite).isTrue();

      final distAlpha5 = ParetoDistribution(5.0, 1.0);
      check(distAlpha5.skewness).isGreaterThan(0.0);
      check(distAlpha5.excessKurtosis).isGreaterThan(0.0);

      check(dist.probability(0.5)).equals(0.0);
      check(dist.probability(1.0)).equals(3.0);
      check(dist.cumulativeProbability(0.5)).equals(0.0);
      check(dist.cumulativeProbability(1.0)).equals(0.0);
      check(dist.cumulativeProbability(2.0)).isCloseTo(1.0 - 1.0 / 8.0, 1e-6);
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(math.pow(2.0, 1.0 / 3.0), 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 1.0)).isTrue();

      // Constructor validation
      check(() => ParetoDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => ParetoDistribution(1.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == ParetoDistribution(3.0, 1.0)).isTrue();
      check(dist.hashCode).equals(ParetoDistribution(3.0, 1.0).hashCode);
      check(dist.toString()).contains('ParetoDistribution');
    });

    test('Weibull distribution', () {
      final dist = WeibullDistribution(1.0, 1.0);
      check(dist.scale).equals(1.0);
      check(dist.shape).equals(1.0);
      check(dist.lowerBound).equals(0.0);
      check(dist.mean).isCloseTo(1.0, 1e-6);
      check(dist.median).isCloseTo(math.ln2, 1e-6);
      check(dist.mode).equals(0.0);
      check(dist.variance).isCloseTo(1.0, 1e-6);
      check(dist.skewness).isCloseTo(2.0, 1e-5);
      check(dist.excessKurtosis).isCloseTo(6.0, 1e-5);

      final distShape2 = WeibullDistribution(2.0, 1.0);
      check(distShape2.mode).isGreaterThan(0.0);

      check(dist.probability(-1.0)).equals(0.0);
      check(dist.probability(1.0)).isGreaterThan(0.0);
      check(dist.cumulativeProbability(-1.0)).equals(0.0);
      check(dist.cumulativeProbability(0.0)).equals(0.0);
      check(dist.cumulativeProbability(1.0))
          .isCloseTo(1.0 - math.exp(-1.0), 1e-6);
      check(dist.inverseCumulativeProbability(0.5))
          .isCloseTo(dist.median, 1e-6);
      check(() => dist.inverseCumulativeProbability(-0.1))
          .throws<InvalidProbability>();

      // Samples
      final samples = dist.samples(random: math.Random(42)).take(50).toList();
      check(samples.every((sample) => sample >= 0.0)).isTrue();

      // Constructor validation
      check(() => WeibullDistribution(0.0, 1.0)).throws<ArgumentError>();
      check(() => WeibullDistribution(1.0, 0.0)).throws<ArgumentError>();

      // Equality and toString
      check(dist == WeibullDistribution(1.0, 1.0)).isTrue();
      check(dist.hashCode).equals(WeibullDistribution(1.0, 1.0).hashCode);
      check(dist.toString()).contains('WeibullDistribution');
    });

    test('Continuous distributions bounds, equality, hashCode, and default random sampling', () {
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
      const degen = DegenerateDistribution(5.0);
      check(degen.lowerBound).equals(double.negativeInfinity);
      check(degen.upperBound).equals(double.infinity);
      check(degen == const DegenerateDistribution(5.0)).isTrue();
      check(degen.hashCode).equals(const DegenerateDistribution(5.0).hashCode);
      check(degen.sample()).equals(5.0);

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

    test('logProbability evaluation', () {
      const normal = NormalDistribution.standard();
      check(normal.logProbability(0.0))
          .isCloseTo(math.log(normal.probability(0.0)), 1e-12);
      check(normal.logProbability(1.5))
          .isCloseTo(math.log(normal.probability(1.5)), 1e-12);

      final exp = ExponentialDistribution(2.0);
      check(exp.logProbability(1.0))
          .isCloseTo(math.log(exp.probability(1.0)), 1e-12);
    });
  });
}
