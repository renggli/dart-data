import '../distribution.dart';

/// Abstract base class for continuous probability distributions over [double].
abstract class ContinuousDistribution extends Distribution<double> {
  const new();

  @override
  double get lowerBound => double.negativeInfinity;

  @override
  bool get isLowerBoundOpen => lowerBound == double.negativeInfinity;

  @override
  double get upperBound => double.infinity;

  @override
  bool get isUpperBoundOpen => upperBound == double.infinity;
}
