import 'dart:math';

import 'package:more/printer.dart';

import '../../../../type.dart';
import '../../../linear/matrix.dart';
import '../../../linear/vector.dart';
import '../../../special/gamma.dart';
import 'multivariate_distribution.dart';

/// Multinomial distribution generalizing the binomial distribution to [dimensions] categories
/// over [trials] independent experiments with category [probabilities].
///
/// See https://en.wikipedia.org/wiki/Multinomial_distribution.
class MultinomialDistribution extends MultivariateDistribution<int> {
  /// Constructs a multinomial distribution with given [trials] count and category [probabilities].
  new(this.trials, this.probabilities) : dimensions = probabilities.length {
    if (trials < 0) {
      throw ArgumentError.value(
        trials,
        'trials',
        'Trials must be non-negative.',
      );
    }
    if (probabilities.length < 2) {
      throw ArgumentError.value(
        probabilities.length,
        'probabilities.length',
        'Multinomial distribution requires at least 2 categories.',
      );
    }
    var sum = 0.0;
    for (var i = 0; i < dimensions; i++) {
      final p = probabilities.getUnchecked(i);
      if (p < 0.0 || p > 1.0) {
        throw ArgumentError.value(
          p,
          'probabilities[$i]',
          'Probabilities must be between 0.0 and 1.0.',
        );
      }
      sum += p;
    }
    if ((sum - 1.0).abs() > 1e-4) {
      throw ArgumentError.value(
        sum,
        'probabilities.sum',
        'Category probabilities must sum to 1.0.',
      );
    }
  }

  /// The number of trials $n$.
  final int trials;

  /// The category probabilities vector $p$.
  final Vector<double> probabilities;

  @override
  final int dimensions;

  @override
  Vector<double> get mean => Vector<double>.generate(
    dimensions,
    (i) => trials * probabilities.getUnchecked(i),
    type: DataType.float64,
  );

  @override
  Matrix<double> get covariance =>
      Matrix<double>.generate(dimensions, dimensions, (r, c) {
        final pr = probabilities.getUnchecked(r);
        if (r == c) {
          return trials * pr * (1.0 - pr);
        } else {
          return -trials * pr * probabilities.getUnchecked(c);
        }
      }, type: DataType.float64);

  @override
  double logProbability(Vector<int> x) {
    if (x.length != dimensions) {
      throw ArgumentError(
        'Vector length (${x.length}) must match distribution dimensions ($dimensions).',
      );
    }
    var sumX = 0;
    var sumLogFact = 0.0;
    var sumWeightedLogP = 0.0;
    for (var i = 0; i < dimensions; i++) {
      final xi = x.getUnchecked(i);
      if (xi < 0) return double.negativeInfinity;
      sumX += xi;
      sumLogFact += factorialLn(xi);
      final p = probabilities.getUnchecked(i);
      if (xi > 0) {
        if (p <= 0.0) return double.negativeInfinity;
        sumWeightedLogP += xi * log(p);
      }
    }
    if (sumX != trials) {
      return double.negativeInfinity;
    }
    return factorialLn(trials) - sumLogFact + sumWeightedLogP;
  }

  @override
  double probability(Vector<int> x) {
    final logP = logProbability(x);
    return logP.isInfinite && logP < 0 ? 0.0 : exp(logP);
  }

  @override
  Vector<int> sample({Random? random}) {
    final counts = List<int>.filled(dimensions, 0);
    final rng = random ?? Random();
    for (var t = 0; t < trials; t++) {
      final u = rng.nextDouble();
      var cum = 0.0;
      var selected = dimensions - 1;
      for (var i = 0; i < dimensions - 1; i++) {
        cum += probabilities.getUnchecked(i);
        if (u < cum) {
          selected = i;
          break;
        }
      }
      counts[selected]++;
    }
    return Vector<int>.fromList(counts, type: DataType.int32);
  }

  @override
  bool operator ==(Object other) =>
      other is MultinomialDistribution &&
      trials == other.trials &&
      dimensions == other.dimensions &&
      probabilities == other.probabilities;

  @override
  int get hashCode =>
      Object.hash(MultinomialDistribution, trials, probabilities);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(trials, name: 'trials')
    ..addValue(probabilities, name: 'p');
}
