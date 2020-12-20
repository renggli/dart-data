import 'package:more/feature.dart';

import '../distribution.dart';
import 'errors.dart';

/// Abstract discrete distribution.
///
/// Subclasses must implement at least one of [probability] or
/// [cumulativeProbability].
abstract class DiscreteDistribution extends Distribution<int> {
  const DiscreteDistribution();

  @override
  int get lowerBound => minSafeInteger;

  @override
  bool get isLowerBoundOpen => lowerBound == minSafeInteger;

  @override
  int get upperBound => maxSafeInteger;

  @override
  bool get isUpperBoundOpen => upperBound == maxSafeInteger;

  @override
  // ignore: avoid_renaming_method_parameters
  double probability(int k) =>
      cumulativeProbability(k) - cumulativeProbability(k - 1);

  @override
  // ignore: avoid_renaming_method_parameters
  double cumulativeProbability(int k) {
    if (k < lowerBound) {
      return 0.0;
    } else if (k <= upperBound) {
      var sum = 0.0;
      for (var i = lowerBound; i <= k && i <= upperBound; i++) {
        sum += probability(i);
      }
      return sum;
    } else {
      return 1.0;
    }
  }

  @override
  int inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    var sum = 0.0;
    for (var k = lowerBound; k < upperBound; k++) {
      sum += probability(k);
      if (p <= sum) {
        return k;
      }
    }
    return upperBound;
  }
}
