import '../distribution.dart';

/// Abstract base class for continuous probability distributions over [double].
abstract class ContinuousDistribution extends Distribution<double> {
  /// Abstract constant constructor for subclassing [ContinuousDistribution].
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
