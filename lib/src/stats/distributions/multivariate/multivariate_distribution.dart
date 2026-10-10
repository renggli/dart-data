import 'dart:math';

import 'package:meta/meta.dart';
import 'package:more/printer.dart' show ToStringPrinter;

import '../../../linear/matrix.dart';
import '../../../linear/vector.dart';

/// Abstract base class representing a multivariate probability distribution over vectors of [T].
@immutable
abstract class MultivariateDistribution<T extends num> with ToStringPrinter {
  const new();

  /// The number of dimensions / variables in this distribution.
  int get dimensions;

  /// The expected value vector of the distribution.
  Vector<double> get mean;

  /// The covariance matrix of the distribution.
  Matrix<double> get covariance;

  /// Returns the probability density (or probability mass) at [x].
  double probability(Vector<T> x);

  /// Returns the natural logarithm of the probability density (or mass) at [x].
  double logProbability(Vector<T> x);

  /// Draws a single pseudo-random sample vector from the distribution.
  Vector<T> sample({Random? random});

  /// Generates an infinite sequence of pseudo-random sample vectors from the distribution.
  Iterable<Vector<T>> samples({Random? random}) sync* {
    for (;;) {
      yield sample(random: random);
    }
  }
}
