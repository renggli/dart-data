import 'dart:math';

import 'package:more/printer.dart';

import '../../../linear/matrix.dart';
import '../../../linear/vector.dart';
import '../../../special/factorial.dart';
import '../../../type/data_type.dart';
import '../discrete/binomial.dart';
import '../multivariate.dart';
import '../utils.dart';

/// Multinomial distribution generalizing the binomial distribution to
/// [dimensions] categories over [trials] independent experiments with category
/// [probabilities].
///
/// See https://en.wikipedia.org/wiki/Multinomial_distribution.
class MultinomialDistribution extends MultivariateDistribution<int> {
  /// Constructs a multinomial distribution with given [trials] count and
  /// category [probabilities].
  new(this.trials, Vector<double> probabilities)
    : _probabilities = probabilities.copy(),
      dimensions = probabilities.length {
    if (trials < 0) {
      throw ArgumentError.value(
        trials,
        'trials',
        'Trials must be non-negative.',
      );
    }
    if (dimensions < 2) {
      throw ArgumentError.value(
        dimensions,
        'probabilities.length',
        'Multinomial distribution requires at least 2 categories.',
      );
    }
    var sum = 0.0;
    for (var i = 0; i < dimensions; i++) {
      final p = _probabilities.getUnchecked(i);
      if (!p.isFinite || p < 0.0 || p > 1.0) {
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

  /// The number of trials n.
  final int trials;

  @override
  final int dimensions;

  final Vector<double> _probabilities;

  /// The category probabilities vector p.
  Vector<double> get probabilities => _probabilities.copy();

  @override
  Vector<double> get mean => Vector<double>.generate(
    dimensions,
    (i) => trials * _probabilities.getUnchecked(i),
    type: DataType.float64,
  );

  @override
  Matrix<double> get covariance =>
      Matrix<double>.generate(dimensions, dimensions, (r, c) {
        final pr = _probabilities.getUnchecked(r);
        if (r == c) {
          return trials * pr * (1.0 - pr);
        } else {
          return -trials * pr * _probabilities.getUnchecked(c);
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
      final p = _probabilities.getUnchecked(i);
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
    return logP == double.negativeInfinity ? 0.0 : exp(logP);
  }

  @override
  Vector<int> sample({Random? random}) {
    final counts = List<int>.filled(dimensions, 0);
    final rng = random ?? defaultRandom;
    var remainingTrials = trials;
    var remainingProb = 1.0;
    for (var i = 0; i < dimensions - 1 && remainingTrials > 0; i++) {
      final pi = _probabilities.getUnchecked(i);
      if (pi > 0.0 && remainingProb > 0.0) {
        final condP = (pi / remainingProb).clamp(0.0, 1.0);
        final draw = BinomialDistribution(
          remainingTrials,
          condP,
        ).sample(random: rng);
        counts[i] = draw;
        remainingTrials -= draw;
      }
      remainingProb -= pi;
    }
    counts[dimensions - 1] = remainingTrials;
    return Vector<int>.fromList(counts, type: DataType.integer);
  }

  @override
  bool operator ==(Object other) =>
      other is MultinomialDistribution &&
      trials == other.trials &&
      dimensions == other.dimensions &&
      _probabilities == other._probabilities;

  @override
  int get hashCode =>
      Object.hash(MultinomialDistribution, trials, _probabilities);

  @override
  ObjectPrinter get toStringPrinter => super.toStringPrinter
    ..addValue(trials, name: 'trials')
    ..addValue(_probabilities, name: 'p');
}
