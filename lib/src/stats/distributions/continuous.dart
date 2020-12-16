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
  double inverseCumulativeDistribution(double p) =>
      solve((x) => cumulativeDistribution(x) - p, min, max);
}
