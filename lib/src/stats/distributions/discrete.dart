import '../distribution.dart';
import 'errors.dart';

const int minSafeInteger = -9007199254740991;
const int maxSafeInteger = 9007199254740991;

/// Abstract base class for discrete probability distributions over [int].
abstract class DiscreteDistribution extends Distribution<int> {
  const new();

  @override
  int get lowerBound => minSafeInteger;

  @override
  bool get isLowerBoundOpen => lowerBound == minSafeInteger;

  @override
  int get upperBound => maxSafeInteger;

  @override
  bool get isUpperBoundOpen => upperBound == maxSafeInteger;

  @override
  double probability(int k) =>
      cumulativeProbability(k) - cumulativeProbability(k - 1);

  @override
  double cumulativeProbability(int k) {
    if (k < lowerBound) {
      return 0.0;
    } else if (k >= upperBound) {
      return 1.0;
    } else {
      var sum = 0.0;
      for (var i = lowerBound; i <= k; i++) {
        sum += probability(i);
      }
      return sum.clamp(0.0, 1.0);
    }
  }

  @override
  int inverseCumulativeProbability(num p) {
    InvalidProbability.check(p);
    if (p == 0) {
      return lowerBound;
    } else if (p == 1) {
      return upperBound;
    } else {
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
}
