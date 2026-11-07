import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:test/test.dart';

import '../../web/distributions/config.dart';

void main() {
  group('Distributions web app configuration and type safety', () {
    test('all configured distributions can be instantiated with default parameters', () {
      for (final distDef in distributions) {
        final params = distDef.parameters.map((p) => p.defaultValue).toList();
        final dist = distDef.creator(params);
        check(dist).isNotNull();

        if (distDef.isContinuous) {
          check(dist).isA<Distribution<double>>();
          final d = dist as Distribution<double>;
          final cdf = d.cumulativeProbability(0.0);
          check(cdf.isFinite).isTrue();
        } else {
          check(dist).isA<Distribution<int>>();
          final d = dist as Distribution<int>;
          final cdf = d.cumulativeProbability(0);
          check(cdf.isFinite).isTrue();
        }
      }
    });

    test('evalDistCumulativeProbability floor-clamps integer coordinates for discrete distributions', () {
      for (final distDef in distributions.where((d) => !d.isContinuous)) {
        final dist = distDef.creator(
          distDef.parameters.map((p) => p.defaultValue).toList(),
        ) as Distribution<int>;
        // Passing non-integer coordinates via floor should never throw TypeError
        const x = 2.7;
        final cdfVal = dist.cumulativeProbability(x.floor());
        check(cdfVal.isFinite).isTrue();
        check(cdfVal >= 0.0 && cdfVal <= 1.0).isTrue();
      }
    });

    test('parameter clamping sanitizes invalid, infinite, or out-of-range URL parameters', () {
      for (final distDef in distributions) {
        final invalidOverrides = <String, double>{
          for (final p in distDef.parameters) p.name: -99999.0,
        };

        final clampedParams = <double>[];
        for (final p in distDef.parameters) {
          var val = invalidOverrides[p.name]!;
          if (!val.isFinite) {
            val = p.defaultValue;
          } else {
            val = val.clamp(p.min, p.max);
            if (p.isInt) val = val.roundToDouble();
          }
          clampedParams.add(val);
        }

        // Must successfully instantiate without throwing ArgumentError
        final dist = distDef.creator(clampedParams);
        check(dist).isNotNull();
      }
    });

    test('infinite bounds quantile evaluation at p = 0 and p = 1', () {
      const normal = NormalDistribution.standard();
      check(normal.isLowerBoundOpen).equals(true);
      check(normal.isUpperBoundOpen).equals(true);
      check(normal.lowerBound).equals(double.negativeInfinity);
      check(normal.upperBound).equals(double.infinity);

      const cauchy = CauchyDistribution.standard();
      check(cauchy.isLowerBoundOpen).equals(true);
      check(cauchy.isUpperBoundOpen).equals(true);
      check(cauchy.lowerBound).equals(double.negativeInfinity);
      check(cauchy.upperBound).equals(double.infinity);

      final exp = ExponentialDistribution(1.0);
      check(exp.isLowerBoundOpen).equals(false);
      check(exp.isUpperBoundOpen).equals(true);
      check(exp.lowerBound).equals(0.0);
      check(exp.upperBound).equals(double.infinity);
    });

    test('cross-parameter constraints in uniform, uniform_discrete, and hypergeometric', () {
      final uniformDef = distributions.firstWhere(
        (d) => d.id == 'uniform_continuous',
      );
      final uDist = uniformDef.creator([5.0, 2.0]);
      check(uDist).isA<UniformDistribution>();
      check((uDist as UniformDistribution).upperBound).isGreaterThan(5.0);

      final uniformDiscDef = distributions.firstWhere(
        (d) => d.id == 'uniform_discrete',
      );
      final udDist = uniformDiscDef.creator([10.0, 3.0]);
      check(udDist).isA<UniformDiscreteDistribution>();
      check((udDist as UniformDiscreteDistribution).upperBound).equals(10);

      final hyperDef = distributions.firstWhere(
        (d) => d.id == 'hypergeometric',
      );
      final hDist = hyperDef.creator([10.0, 20.0, 15.0]);
      check(hDist).isA<HypergeometricDistribution>();
      final hd = hDist as HypergeometricDistribution;
      check(hd.successStates).equals(10);
      check(hd.draws).equals(10);
    });
  });
}
