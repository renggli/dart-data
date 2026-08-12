import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../discrete.dart';

/// The Hypergeometric distribution is a discrete probability distribution that
/// describes the probability of k successes (random draws for which the object
/// drawn has a specified feature) in [n] draws, without replacement, from a
/// population of size [N] that contains exactly [K] objects with that feature.
///
/// See https://en.wikipedia.org/wiki/Hypergeometric_distribution.
///
/// ```dart
/// final distribution = HypergeometricDistribution(50, 10, 5);
/// print(distribution.mean);  // 1.0
/// ```
class HypergeometricDistribution extends DiscreteDistribution {
  /// A hypergeometric distribution with population size [N], success count in
  /// population [K], and draw count [n].
  const new(this.N, this.K, this.n)
    : assert(N >= 0, 'N >= 0'),
      assert(0 <= K && K <= N, '0 <= K <= N'),
      assert(0 <= n && n <= N, '0 <= n <= N');

  /// Population size.
  final int N;

  /// Success count in population.
  final int K;

  /// Number of draws.
  final int n;

  @override
  int get lowerBound => max(0, n - (N - K));

  @override
  int get upperBound => min(n, K);

  @override
  double get mean => n * K / N;

  @override
  double get median => mean.roundToDouble();

  @override
  double get mode => ((n + 1) * (K + 1) / (N + 2)).floorToDouble();

  @override
  double get variance =>
      N > 1 ? n * (K / N) * ((N - K) / N) * ((N - n) / (N - 1)) : 0.0;

  @override
  double get skewness => N > 2
      ? ((N - 2 * K) * sqrt(N - 1) * (N - 2 * n)) /
            (sqrt(n * K * (N - K) * (N - n).toDouble()) * (N - 2))
      : double.nan;

  @override
  double get kurtosisExcess {
    if (N <= 3) return double.nan;
    final numK = K.toDouble();
    final numN = N.toDouble();
    final numn = n.toDouble();
    final numerator =
        (numN - 1) *
        numN *
        numN *
        ((numN * (numN + 1) - 6 * numn * (numN - numn)) +
            3 *
                numK *
                (numN - numK) *
                (6 * numn * (numN - numn) - numN * (numN + 1)) +
            6 * numn * (numN - numn) * numK * (numN - numK) * (numN - 2));
    final denominator =
        numn * numK * (numN - numK) * (numN - numn) * (numN - 2) * (numN - 3);
    if (denominator == 0) return double.nan;
    return numerator / denominator - 3;
  }

  @override
  double probability(int k) {
    if (k < lowerBound || k > upperBound) return 0;
    return exp(
      combinationLn(K, k) + combinationLn(N - K, n - k) - combinationLn(N, n),
    );
  }

  @override
  int sample({Random? random}) {
    final rand = random ?? _random;
    var successes = 0;
    var remainingPopulation = N;
    var remainingSuccesses = K;
    for (var i = 0; i < n; i++) {
      if (remainingSuccesses == 0) break;
      if (remainingPopulation == remainingSuccesses) {
        successes += n - i;
        break;
      }
      final pSuccess = remainingSuccesses / remainingPopulation;
      if (rand.nextDouble() < pSuccess) {
        successes++;
        remainingSuccesses--;
      }
      remainingPopulation--;
    }
    return successes;
  }

  @override
  bool operator ==(Object other) =>
      other is HypergeometricDistribution &&
      N == other.N &&
      K == other.K &&
      n == other.n;

  @override
  int get hashCode => Object.hash(HypergeometricDistribution, N, K, n);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(N, name: 'N')
    ..addValue(K, name: 'K')
    ..addValue(n, name: 'n');
}

final _random = Random();
