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

      const uniform = UniformDistribution(0.0, 1.0);
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

      final resSame = kolmogorovSmirnov2Sample(sample1, sample2);
      check(resSame.isSignificant).isFalse();
      check(resSame.pValue).isGreaterThan(0.05);

      final shiftedSample = sample1.map((x) => x + 3.0).toList();
      final resDiff = kolmogorovSmirnov2Sample(sample1, shiftedSample);
      check(resDiff.isSignificant).isTrue();
      check(resDiff.pValue).isLessThan(1e-4);

      check(() => kolmogorovSmirnov2Sample(<double>[], sample2))
          .throws<ArgumentError>();
      check(() => kolmogorovSmirnov2Sample(sample1, <double>[]))
          .throws<ArgumentError>();
    });

    test('Kolmogorov-Smirnov with discrete distribution does not throw', () {
      const poisson = PoissonDistribution(3.0);
      final sample = poisson.samples(random: math.Random(42)).take(50).toList();
      final res = kolmogorovSmirnovTest(sample, poisson);
      check(res.pValue).isGreaterThan(0.0);
      check(res.statistic).isGreaterOrEqual(0.0);
    });
  });
}
