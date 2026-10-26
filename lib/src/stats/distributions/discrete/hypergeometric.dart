import 'dart:math';

import 'package:more/printer.dart';

import '../../../special/gamma.dart';
import '../discrete.dart';

/// The Hypergeometric distribution is a discrete probability distribution that
/// describes the probability of k successes (random draws for which the object
/// drawn has a specified feature) in [draws], without replacement, from a
/// population of size [populationSize] that contains exactly [successStates]
/// objects with that feature.
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

  /// Population size.
  final int populationSize;

  /// Success count in population.
  final int successStates;

  /// Number of draws.
  final int draws;

  @override
  int get lowerBound => max(0, draws - (populationSize - successStates));

  @override
  int get upperBound => min(draws, successStates);

  @override
  double get mean => draws * successStates / populationSize;

  @override
  double get median => mean.roundToDouble();

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
  double get skewness => populationSize > 2
      ? ((populationSize - 2 * successStates) *
                sqrt(populationSize - 1) *
                (populationSize - 2 * draws)) /
            (sqrt(
                  draws *
                      successStates *
                      (populationSize - successStates) *
                      (populationSize - draws).toDouble(),
                ) *
                (populationSize - 2))
      : double.nan;

  @override
  double get excessKurtosis {
    if (populationSize <= 3) return double.nan;
    final numK = successStates.toDouble();
    final numN = populationSize.toDouble();
    final numn = draws.toDouble();
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
      combinationLn(successStates, k) +
          combinationLn(populationSize - successStates, draws - k) -
          combinationLn(populationSize, draws),
    );
  }

  @override
  int sample({Random? random}) {
    final rand = random ?? _random;
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

final _random = Random();
