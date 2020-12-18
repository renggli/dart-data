import 'dart:math' as math;

import '../../../numeric.dart';
import '../distribution.dart';

/// Abstract continuous distribution.
///
/// Subclasses must implement at least one of [probability] or
/// [cumulativeProbability].
abstract class ContinuousDistribution extends Distribution<double> {
  const ContinuousDistribution();

  @override
  double get min => double.negativeInfinity;

  @override
  double get max => double.infinity;

  @override
  double probability(double x) => derivative(cumulativeProbability, x);

  @override
  double cumulativeProbability(double x) => integrate(probability, min, x);

  @override
  double inverseCumulativeProbability(num p) {
    double f(double x) => cumulativeProbability(x) - p;
    const factor = 10.0;
    var left = min, right = max;
    if (left.isInfinite) {
      left = math.min(-factor, right);
      while (f(left) > 0) {
        right = left;
        left *= factor;
      }
    }
    if (right.isInfinite) {
      right = math.max(factor, left);
      while (f(right) < 0) {
        left = right;
        right *= factor;
      }
    }
    return solve((x) => cumulativeProbability(x) - p, left, right);
  }
}
