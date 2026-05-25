import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../discrete.dart';

/// The Binomial distribution is a discrete probability distribution which
/// describes the number of successes in a series of independent yes/no
/// experiments all with the same probability of success.
///
/// See https://en.wikipedia.org/wiki/Binomial_distribution.
///
/// ```dart
/// final distribution = BinomialDistribution(2, 0.5);
/// print(distribution.probability(1));  // 0.5
/// ```
class BinomialDistribution extends DiscreteDistribution {
  /// A binomial distribution with parameters [n] and [p].
  const BinomialDistribution(this.n, this.p)
    : assert(0 <= n, 'n <= 0'),
      assert(0 <= p && p <= 1, '0 <= p <= 1');

  /// Number of trials.
  final int n;

  /// Success probability of each trial (0..1).
  final double p;

  /// Failure probability of each trial (0..1).
  double get q => 1 - p;

  @override
  int get lowerBound => 0;

  @override
  int get upperBound => n;

  @override
  double get mean => n * p;

  @override
  double get median => mean.roundToDouble();

  @override
  double get mode => ((n + 1) * p).floorToDouble();

  @override
  double get variance => n * p * q;

  @override
  double get skewness => (q - p) / sqrt(n * p * q);

  @override
  double get kurtosisExcess => (1 - 6 * p * q) / (n * p * q);

  @override
  double probability(int k) => 0 <= k && k <= n
      ? exp(combinationLn(n, k) + k * log(p) + (n - k) * log(q))
      : 0;

  @override
  int sample({Random? random}) {
    final rand = random ?? _random;
    // Use symmetry: work with the smaller of p and q.
    final pp = p <= 0.5 ? p : q;
    final np = n * pp;
    final result = np < 10 ? _sampleInversion(rand, pp) : _sampleBtrd(rand, pp);
    return p <= 0.5 ? result : n - result;
  }

  /// Inverse-transform method: O(np) expected time, good for small np.
  int _sampleInversion(Random rand, double pp) {
    final qq = 1 - pp;
    final s = pp / qq;
    final a = (n + 1) * s;
    var r = pow(qq, n).toDouble();
    var u = rand.nextDouble();
    var x = 0;
    while (u > r) {
      u -= r;
      x++;
      r *= (a / x) - s;
    }
    return x;
  }

  /// BTRD algorithm (Hörmann 1993): O(1) expected time for large np.
  int _sampleBtrd(Random rand, double pp) {
    final qq = 1 - pp;
    final fm = (n + 1) * pp;
    final m = fm.floor();
    final p1 = (2.195 * sqrt(n * pp * qq) - 4.6 * qq).floor() + 0.5;
    final xm = m + 0.5;
    final xl = xm - p1;
    final xr = xm + p1;
    final c = 0.134 + 20.5 / (15.3 + m);
    final al = (fm - xl) / (fm - xl * pp);
    final lambdaL = al * (1 + 0.5 * al);
    final ar = (xr - fm) / (xr * qq);
    final lambdaR = ar * (1 + 0.5 * ar);
    final p2 = p1 * (1 + 2 * c);
    final p3 = p2 + c / lambdaL;
    final p4 = p3 + c / lambdaR;
    for (;;) {
      final u = rand.nextDouble() * p4;
      final v = rand.nextDouble();
      int k;
      if (u <= p1) {
        k = (xm - p1 * v + u).floor();
        return k;
      }
      if (u <= p2) {
        final x = xl + (u - p1) / c;
        k = x.floor();
        if (k < 0 || k > n) continue;
        final f = (xm - x).abs();
        if (f <= 1) return k;
        if (v <= (2.0 - f) / (1.0 + f)) return k;
      } else if (u <= p3) {
        k = (xl + log(v) / lambdaL).floor();
        if (k < 0) continue;
      } else {
        k = (xr - log(v) / lambdaR).floor();
        if (k > n) continue;
      }
      // Final acceptance check using log-space PMF ratio.
      final a2 =
          combinationLn(n, k) +
          k * log(pp) +
          (n - k) * log(qq) -
          combinationLn(n, m) -
          m * log(pp) -
          (n - m) * log(qq);
      if (log(v) <= a2) return k;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BinomialDistribution && n == other.n && p == other.p;

  @override
  int get hashCode => Object.hash(BinomialDistribution, n, p);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(n, name: 'n')
    ..addValue(p, name: 'p')
    ..addValue(q, name: 'q');
}

final _random = Random();
