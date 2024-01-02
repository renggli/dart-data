import '../distribution.dart';

/// Abstract interface of all continuous distributions.
abstract class ContinuousDistribution extends Distribution<double> {
  const ContinuousDistribution();

  @override
  double get lowerBound => double.negativeInfinity;

  @override
  double get upperBound => double.infinity;
}
