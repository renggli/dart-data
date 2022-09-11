import 'package:meta/meta.dart';

import '../distribution.dart';

/// Abstract interface of all continuous distributions.
abstract class ContinuousDistribution extends Distribution<double> {
  const ContinuousDistribution();

  @override
  @nonVirtual
  double get lowerBound => support.lower.isBounded
      ? support.lower.endpoint
      : double.negativeInfinity;

  @override
  @nonVirtual
  double get upperBound =>
      support.upper.isBounded ? support.upper.endpoint : double.infinity;
}
