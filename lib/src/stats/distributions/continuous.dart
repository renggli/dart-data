import '../distribution.dart';

/// Abstract interface of all continuous distributions.
abstract class ContinuousDistribution extends Distribution<double> {
  const new();

  @override
  double get lowerBound => double.negativeInfinity;

  @override
  double get upperBound => double.infinity;
}
