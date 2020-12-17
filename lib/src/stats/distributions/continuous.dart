import 'dart:math' as math;

import '../../../numeric.dart';
import '../distribution.dart';

/// Abstract continuous distribution.
///
/// Subclasses must implement at least one of [probabilityDistribution] or
/// [cumulativeDistribution].
abstract class ContinuousDistribution extends Distribution<double> {
  const ContinuousDistribution();

  @override
  double get min => double.negativeInfinity;

  @override
  double get max => double.infinity;

  @override
  double probabilityDistribution(double x) =>
      derivative(cumulativeDistribution, x);

  @override
  double cumulativeDistribution(double x) =>
      integrate(probabilityDistribution, min, x);

  @override
  double inverseCumulativeDistribution(double p) {
    double f(double x) => cumulativeDistribution(x) - p;
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
    return solve((x) => cumulativeDistribution(x) - p, left, right);
  }
}
