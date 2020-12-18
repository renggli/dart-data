import 'dart:math';

import '../../../numeric.dart';
import '../distribution.dart';
import 'errors.dart';

/// Abstract continuous distribution.
///
/// Subclasses must implement at least one of [probability] or
/// [cumulativeProbability].
abstract class ContinuousDistribution extends Distribution<double> {
  const ContinuousDistribution();

  @override
  double get lowerBound => double.negativeInfinity;

  @override
  bool get isLowerBoundOpen => lowerBound == double.negativeInfinity;

  @override
  double get upperBound => double.infinity;

  @override
  bool get isUpperBoundOpen => upperBound == double.infinity;

  @override
  double probability(double x) => derivative(cumulativeProbability, x);

  @override
  double cumulativeProbability(double x) =>
      integrate(probability, lowerBound, x);

  @override
  double inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    double f(double x) => cumulativeProbability(x) - p;
    const factor = 10.0;
    var adjustedLower = lowerBound;
    var adjustedUpper = upperBound;
    if (isLowerBoundOpen) {
      adjustedLower = min(-factor, adjustedUpper);
      while (f(adjustedLower) > 0.0) {
        adjustedUpper = adjustedLower;
        adjustedLower *= factor;
      }
    }
    if (isUpperBoundOpen) {
      adjustedUpper = max(factor, adjustedLower);
      while (f(adjustedUpper) < 0.0) {
        adjustedLower = adjustedUpper;
        adjustedUpper *= factor;
      }
    }
    return solve(f, adjustedLower, adjustedUpper);
  }
}
