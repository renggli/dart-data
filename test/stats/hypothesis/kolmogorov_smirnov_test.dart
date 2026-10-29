import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

void main() {
  group('kolmogorov-smirnov', () {
    test('Kolmogorov-Smirnov one-sample test', () {
      const normal = NormalDistribution.standard();
      final normalSample = normal
          .samples(random: math.Random(42))
          .take(100)
          .toList();

      final resNormal = kolmogorovSmirnovTest(normalSample, normal);
      check(resNormal.isSignificant).isFalse();
      check(resNormal.pValue).isGreaterThan(0.05);
      check(resNormal.statistic).isLessThan(0.15);

      const uniform = UniformDistribution.standard();
      final uniformSample = uniform
          .samples(random: math.Random(42))
          .take(100)
          .toList();

      final resReject = kolmogorovSmirnovTest(uniformSample, normal);
      check(resReject.isSignificant).isTrue();
      check(resReject.pValue).isLessThan(1e-4);

      check(() => kolmogorovSmirnovTest(<double>[], normal))
          .throws<ArgumentError>();
    });

    test('Kolmogorov-Smirnov two-sample test', () {
      const normal = NormalDistribution.standard();
      final sample1 = normal.samples(random: math.Random(1)).take(100).toList();
      final sample2 = normal.samples(random: math.Random(2)).take(100).toList();

      final resSame = kolmogorovSmirnovTwoSample(sample1, sample2);
      check(resSame.isSignificant).isFalse();
      check(resSame.pValue).isGreaterThan(0.05);

      final shiftedSample = sample1.map((x) => x + 3.0).toList();
      final resDiff = kolmogorovSmirnovTwoSample(sample1, shiftedSample);
      check(resDiff.isSignificant).isTrue();
      check(resDiff.pValue).isLessThan(1e-4);

      check(() => kolmogorovSmirnovTwoSample(<double>[], sample2))
          .throws<ArgumentError>();
      check(() => kolmogorovSmirnovTwoSample(sample1, <double>[]))
          .throws<ArgumentError>();
    });

    test('Kolmogorov-Smirnov rejects discrete distributions', () {
      final poisson = PoissonDistribution(3.0);
      final sample = poisson.samples(random: math.Random(42)).take(50).toList();
      check(() => kolmogorovSmirnovTest(sample, poisson))
          .throws<ArgumentError>();
    });

    test('Kolmogorov-Smirnov exact Marsaglia-Tsang-Wang small n', () {
      const uniform = UniformDistribution.standard();

      // n = 1: D_1 = max(1 - 0.7, 0.7 - 0) = 0.7
      // P(D_1 < 0.7) = 2(0.7) - 1 = 0.4 -> p-value = 1 - 0.4 = 0.6
      final res1 = kolmogorovSmirnovTest([0.7], uniform);
      check(res1.statistic).isCloseTo(0.7, 1e-10);
      check(res1.pValue).isCloseTo(0.6, 1e-10);

      // n = 2: sample [0.4, 0.4]
      // CDF at 0.4 is 0.4
      // i=0: dp = 1/2 - 0.4 = 0.1, dm = 0.4 - 0 = 0.4
      // i=1: dp = 1 - 0.4 = 0.6, dm = 0.4 - 1/2 = -0.1
      // D_2 = 0.6
      // P(D_2 < 0.6) = 1 - 2*(1 - 0.6)^2 = 1 - 2*0.16 = 0.68 -> p-value = 0.32
      final res2 = kolmogorovSmirnovTest([0.4, 0.4], uniform);
      check(res2.statistic).isCloseTo(0.6, 1e-10);
      check(res2.pValue).isCloseTo(0.32, 1e-10);

      // Sample of size 5 with known exact p-value
      final sample5 = [0.1, 0.2, 0.3, 0.4, 0.5];
      // CDF matches iOverN exactly at 0.5:
      // i=0: cdf=0.1, dp=0.2-0.1=0.1, dm=0.1-0=0.1
      // i=4: cdf=0.5, dp=1.0-0.5=0.5, dm=0.5-0.8=-0.3
      // dStat = 0.5
      final res5 = kolmogorovSmirnovTest(sample5, uniform);
      check(res5.statistic).isCloseTo(0.5, 1e-10);
      // For n=5, d=0.5: P(D_5 < 0.5) = 0.888 -> p-value = 0.112
      check(res5.pValue).isCloseTo(0.112, 1e-10);
    });

    test('Kolmogorov-Smirnov returns NaN on NaN inputs', () {
      const normal = NormalDistribution.standard();
      final res1 = kolmogorovSmirnovTest([1.0, double.nan, 2.0], normal);
      check(res1.statistic.isNaN).isTrue();
      check(res1.pValue.isNaN).isTrue();

      final res2 = kolmogorovSmirnovTwoSample([1.0, 2.0], [double.nan, 3.0]);
      check(res2.statistic.isNaN).isTrue();
      check(res2.pValue.isNaN).isTrue();
    });
  });
}
