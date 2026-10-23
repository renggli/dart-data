import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('DiscreteDistribution contracts and defaults', () {
    test('default implementations and bounds', () {
      final custom = _TestDiscreteDist();
      check(custom.lowerBound).equals(DataType.integer.safeMin);
      check(custom.probability(0)).equals(0.5);
    });

    test('equality, hashCode, default random, and sampling branches', () {
      // Bernoulli
      final b1 = BernoulliDistribution(0.4);
      final b2 = BernoulliDistribution(0.4);
      final b3 = BernoulliDistribution(0.6);
      check(b1 == b2).isTrue();
      check(b1 == b3).isFalse();
      check(b1.hashCode).equals(b2.hashCode);
      check(b1.sample()).isNotNull();

      // Binomial
      final bin1 = BinomialDistribution(10, 0.4);
      final bin2 = BinomialDistribution(10, 0.4);
      final bin3 = BinomialDistribution(10, 0.5);
      check(bin1 == bin2).isTrue();
      check(bin1 == bin3).isFalse();
      check(bin1.hashCode).equals(bin2.hashCode);
      check(bin1.sample()).isNotNull();

      // Poisson rate >= 30 (normal approximation)
      final p1 = PoissonDistribution(50.0);
      final p2 = PoissonDistribution(50.0);
      final p3 = PoissonDistribution(10.0);
      check(p1 == p2).isTrue();
      check(p1 == p3).isFalse();
      check(p1.hashCode).equals(p2.hashCode);
      check(p1.sample()).isNotNull();
      check(p3.sample()).isNotNull();

      // Geometric
      final g1 = GeometricDistribution(0.3);
      final g2 = GeometricDistribution(0.3);
      final g3 = GeometricDistribution(0.7);
      check(g1 == g2).isTrue();
      check(g1 == g3).isFalse();
      check(g1.hashCode).equals(g2.hashCode);
      check(g1.sample()).isNotNull();

      // Hypergeometric early breaks (K == 0, K == N)
      final h1 = HypergeometricDistribution(50, 20, 10);
      final h2 = HypergeometricDistribution(50, 20, 10);
      final h3 = HypergeometricDistribution(50, 25, 10);
      check(h1 == h2).isTrue();
      check(h1 == h3).isFalse();
      check(h1.hashCode).equals(h2.hashCode);
      check(h1.sample()).isNotNull();

      final hZeroK = HypergeometricDistribution(10, 0, 5);
      check(hZeroK.sample()).equals(0);

      final hAllK = HypergeometricDistribution(10, 10, 5);
      check(hAllK.sample()).equals(5);

      // Negative Binomial
      final nb1 = NegativeBinomialDistribution(5, 0.5);
      final nb2 = NegativeBinomialDistribution(5, 0.5);
      final nb3 = NegativeBinomialDistribution(5, 0.6);
      check(nb1 == nb2).isTrue();
      check(nb1 == nb3).isFalse();
      check(nb1.hashCode).equals(nb2.hashCode);
      check(nb1.sample()).isNotNull();

      // Rademacher
      const r1 = RademacherDistribution();
      const r2 = RademacherDistribution();
      check(r1 == r2).isTrue();
      check(r1.hashCode).equals(r2.hashCode);
      check(r1.sample()).isNotNull();

      // Uniform Discrete
      final u1 = UniformDiscreteDistribution(1, 6);
      final u2 = UniformDiscreteDistribution(1, 6);
      final u3 = UniformDiscreteDistribution(1, 10);
      check(u1 == u2).isTrue();
      check(u1 == u3).isFalse();
      check(u1.hashCode).equals(u2.hashCode);
      check(u1.sample()).isNotNull();
    });
  });

  group('DiscreteDistribution quantiles and probability', () {
    test('quantiles for large parameters do not hang', () {
      final pois = PoissonDistribution(1000.0);
      final pQuant = pois.inverseCumulativeProbability(0.999);
      check(pQuant).isGreaterThan(1000);
      check(pois.cumulativeProbability(pQuant)).isGreaterOrEqual(0.999);

      final binom = BinomialDistribution(10000, 0.5);
      final bQuant = binom.inverseCumulativeProbability(0.5);
      check(bQuant).equals(5000);

      final nbinom = NegativeBinomialDistribution(50, 0.4);
      final nbQuant = nbinom.inverseCumulativeProbability(0.95);
      check(nbQuant).isGreaterThan(0);
      check(nbinom.cumulativeProbability(nbQuant)).isGreaterOrEqual(0.95);
    });

    test('logProbability evaluation', () {
      final binom = BinomialDistribution(10, 0.5);
      check(binom.logProbability(5))
          .isCloseTo(math.log(binom.probability(5)), 1e-12);

      final pois = PoissonDistribution(4.0);
      check(pois.logProbability(3))
          .isCloseTo(math.log(pois.probability(3)), 1e-12);
    });
  });

  group('InvalidProbability errors', () {
    test('error creation and toString', () {
      final err = InvalidProbability(1.5);
      check(err.probability).equals(1.5);
      check(err.toString()).contains('Invalid probability');
    });

    test('InvalidProbability.check throws on NaN', () {
      check(() => InvalidProbability.check(double.nan))
          .throws<InvalidProbability>();
    });
  });
}

class _TestDiscreteDist extends DiscreteDistribution {
  @override
  double cumulativeProbability(int k) => k >= 0 ? 1.0 : 0.5;

  @override
  int sample({math.Random? random}) => 0;

  @override
  double get mean => 0.0;
  @override
  double get median => 0.0;
  @override
  double get mode => 0.0;
  @override
  double get variance => 0.0;
  @override
  double get skewness => 0.0;
  @override
  double get excessKurtosis => 0.0;
}
