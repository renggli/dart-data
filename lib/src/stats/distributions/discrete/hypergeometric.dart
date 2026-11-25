import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/binomial.dart';
import '../discrete.dart';
import '../utils.dart';

/// The Hypergeometric distribution describing the number of successes in
/// [draws] draws without replacement from a finite population of size
/// [populationSize] containing [successStates] success states.
///
/// See https://en.wikipedia.org/wiki/Hypergeometric_distribution.
///
/// ```dart
/// final distribution = HypergeometricDistribution(50, 10, 5);
/// print(distribution.mean);  // 1.0
/// ```
class HypergeometricDistribution extends DiscreteDistribution {
  /// A hypergeometric distribution with [populationSize], [successStates] in
  /// the population, and number of [draws].
  new(this.populationSize, this.successStates, this.draws) {
    if (populationSize <= 0) {
      throw ArgumentError.value(
        populationSize,
        'populationSize',
        'Population size must be positive',
      );
    }
    if (successStates < 0 || successStates > populationSize) {
      throw ArgumentError.value(
        successStates,
        'successStates',
        'Success count must be between 0 and populationSize',
      );
    }
    if (draws < 0 || draws > populationSize) {
      throw ArgumentError.value(
        draws,
        'draws',
        'Number of draws must be between 0 and populationSize',
      );
    }
  }

  /// Fits a hypergeometric distribution to non-negative integer [samples]
  /// given [populationSize] and optional [draws] (defaulting to the maximum
  /// observed sample).
  factory fit(
    Iterable<num> samples, {
    required int populationSize,
    int? draws,
  }) {
    if (populationSize <= 0) {
      throw ArgumentError.value(
        populationSize,
        'populationSize',
        'Population size must be positive',
      );
    }
    var count = 0;
    var sum = 0.0;
    var maxVal = 0;
    for (final x in samples) {
      if (!x.isFinite || x < 0 || x.roundToDouble() != x) {
        throw ArgumentError.value(
          x,
          'samples',
          'Hypergeometric samples must be non-negative integers',
        );
      }
      final xi = x.round();
      if (xi > populationSize) {
        throw ArgumentError.value(
          x,
          'samples',
          'Samples cannot exceed populationSize ($populationSize)',
        );
      }
      if (xi > maxVal) maxVal = xi;
      count++;
      sum += xi;
    }
    if (count == 0) {
      throw ArgumentError.value(samples, 'samples', 'Cannot fit empty samples');
    }
    final nDraws = draws ?? maxVal;
    if (nDraws < maxVal || nDraws > populationSize) {
      throw ArgumentError.value(
        draws,
        'draws',
        'Number of draws must be between maximum sample ($maxVal) and populationSize ($populationSize)',
      );
    }
    if (nDraws == 0) {
      return HypergeometricDistribution(populationSize, 0, 0);
    }
    final mean = sum / count;
    final k = (mean * populationSize / nDraws).round().clamp(
      maxVal,
      populationSize,
    );
    return HypergeometricDistribution(populationSize, k, nDraws);
  }

  /// Population size.
  final int populationSize;

  /// Success count in population.
  final int successStates;

  /// Number of draws.
  final int draws;

  @override
  int get lowerBound => max(0, draws - (populationSize - successStates));

  @override
  bool get isLowerBoundOpen => false;

  @override
  int get upperBound => min(draws, successStates);

  @override
  bool get isUpperBoundOpen => false;

  @override
  double get mean => draws * successStates / populationSize;

  @override
  double get median => inverseCumulativeProbability(0.5).toDouble();

  @override
  double get mode => ((draws + 1) * (successStates + 1) / (populationSize + 2))
      .floorToDouble();

  @override
  double get variance => populationSize > 1
      ? draws *
            (successStates / populationSize) *
            ((populationSize - successStates) / populationSize) *
            ((populationSize - draws) / (populationSize - 1))
      : 0.0;

  @override
  double get skewness {
    if (populationSize <= 2) return double.nan;
    final denom =
        sqrt(
          draws *
              successStates *
              (populationSize - successStates) *
              (populationSize - draws).toDouble(),
        ) *
        (populationSize - 2);
    if (denom == 0.0) return double.nan;
    return ((populationSize - 2 * successStates) *
            sqrt(populationSize - 1) *
            (populationSize - 2 * draws)) /
        denom;
  }

  @override
  double get excessKurtosis {
    if (populationSize <= 3) return double.nan;
    final k = successStates.toDouble();
    final capN = populationSize.toDouble();
    final n = draws.toDouble();
    final kComp = capN - k;
    final nComp = capN - n;
    final denominator = n * k * kComp * nComp * (capN - 2.0) * (capN - 3.0);
    if (denominator == 0.0) return double.nan;
    final numerator =
        (capN - 1.0) *
            capN *
            capN *
            (capN * (capN + 1.0) - 6.0 * k * kComp - 6.0 * n * nComp) +
        6.0 * n * k * kComp * nComp * (5.0 * capN - 6.0);
    return numerator / denominator;
  }

  @override
  double probability(int k) {
    if (k < lowerBound || k > upperBound) return 0.0;
    return exp(logProbability(k));
  }

  @override
  double logProbability(int x) {
    if (x < lowerBound || x > upperBound) return double.negativeInfinity;
    return binomialLn(successStates, x) +
        binomialLn(populationSize - successStates, draws - x) -
        binomialLn(populationSize, draws);
  }

  @override
  double cumulativeProbability(int k) {
    final lo = lowerBound;
    final hi = upperBound;
    if (k < lo) return 0.0;
    if (k >= hi) return 1.0;
    if (k - lo <= hi - k) {
      var p = probability(lo);
      var sum = p;
      final base = populationSize - successStates - draws;
      for (var i = lo; i < k; i++) {
        p *= (successStates - i) * (draws - i) / ((i + 1) * (base + i + 1));
        sum += p;
      }
      return sum.clamp(0.0, 1.0);
    }
    return (1.0 - _upperTailSum(k + 1, hi)).clamp(0.0, 1.0);
  }

  @override
  double survival(int x) {
    final lo = lowerBound;
    final hi = upperBound;
    if (x < lo) return 1.0;
    if (x >= hi) return 0.0;
    if (hi - x <= x - lo) {
      return _upperTailSum(x + 1, hi).clamp(0.0, 1.0);
    }
    return (1.0 - cumulativeProbability(x)).clamp(0.0, 1.0);
  }

  double _upperTailSum(int start, int hi) {
    var p = probability(hi);
    var sum = p;
    final base = populationSize - successStates - draws;
    for (var i = hi; i > start; i--) {
      p *= i * (base + i) / ((successStates - i + 1) * (draws - i + 1));
      sum += p;
    }
    return sum;
  }

  @override
  int sample({Random? random}) {
    final rand = random ?? defaultRandom;
    var successes = 0;
    var remainingPopulation = populationSize;
    var remainingSuccesses = successStates;
    for (var i = 0; i < draws; i++) {
      if (remainingSuccesses == 0) break;
      if (remainingPopulation == remainingSuccesses) {
        successes += draws - i;
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
      populationSize == other.populationSize &&
      successStates == other.successStates &&
      draws == other.draws;

  @override
  int get hashCode => Object.hash(
    HypergeometricDistribution,
    populationSize,
    successStates,
    draws,
  );

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(populationSize, name: 'populationSize')
    ..addValue(successStates, name: 'successStates')
    ..addValue(draws, name: 'draws');
}
