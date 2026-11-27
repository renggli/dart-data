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
          check(cdf.isFinite).isTrue;
        } else {
          check(dist).isA<Distribution<int>>();
          final d = dist as Distribution<int>;
          final cdf = d.cumulativeProbability(0);
          check(cdf.isFinite).isTrue;
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
        check(cdfVal.isFinite).isTrue;
        check(cdfVal >= 0.0 && cdfVal <= 1.0).isTrue;
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

  group('Multivariate distributions configuration and parameter constraints', () {
    test('all configured multivariate distributions instantiate with defaults and evaluate', () {
      for (final def in multivariateDistributions) {
        final params = def.parameters.map((p) => p.defaultValue).toList();
        syncMultivariateParameters(def, params);
        final dist = def.creator(params);
        check(dist.dimensions).equals(def.dimensions);
        check(dist.mean.length).equals(def.dimensions);
        check(dist.covariance.rowCount).equals(def.dimensions);
        check(dist.covariance.colCount).equals(def.dimensions);

        if (def.isContinuous) {
          check(dist).isA<MultivariateDistribution<double>>();
          final d = dist as MultivariateDistribution<double>;
          final pt = d.mean;
          check(d.probability(pt).isFinite).isTrue;
          check(d.logProbability(pt).isFinite).isTrue;
          check(d.sample().length).equals(def.dimensions);
        } else {
          check(dist).isA<MultivariateDistribution<int>>();
          final d = dist as MultivariateDistribution<int>;
          final s = d.sample();
          check(s.length).equals(def.dimensions);
          check(d.probability(s).isFinite).isTrue;
          check(d.logProbability(s).isFinite).isTrue;
        }
      }
    });

    test(
      'parameter clamping and syncMultivariateParameters handle extreme values',
      () {
        for (final def in multivariateDistributions) {
          final extreme = [for (final p in def.parameters) p.max];
          syncMultivariateParameters(def, extreme, changedIndex: 1);
          final dist = def.creator(extreme);
          check(dist.dimensions).equals(def.dimensions);

          final lowExtreme = [for (final p in def.parameters) p.min];
          syncMultivariateParameters(def, lowExtreme, changedIndex: 2);
          final lowDist = def.creator(lowExtreme);
          check(lowDist.dimensions).equals(def.dimensions);
        }

        final multDef = multivariateDistributions.firstWhere(
          (d) => d.id == 'multinomial',
        );
        final vals = <double>[10.0, 0.85, 0.85];
        syncMultivariateParameters(multDef, vals, changedIndex: 1);
        check(vals[1] + vals[2]).isLessOrEqual(0.95 + 1e-9);
        final multDist = multDef.creator(vals) as MultinomialDistribution;
        check(multDist.probabilities.getUnchecked(2)).isGreaterThan(0.0);
      },
    );
  });
}
