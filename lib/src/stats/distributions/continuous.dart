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
}
