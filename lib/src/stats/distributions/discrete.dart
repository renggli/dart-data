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
  int get min => minSafeInteger;

  @override
  int get max => maxSafeInteger;

  @override
  // ignore: avoid_renaming_method_parameters
  double probability(int k) =>
      cumulativeProbability(k) - cumulativeProbability(k - 1);

  @override
  // ignore: avoid_renaming_method_parameters
  double cumulativeProbability(int k) {
    if (k < min) {
      return 0.0;
    } else if (k <= max) {
      var sum = 0.0;
      for (var i = min; i <= k && i <= max; i++) {
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
    for (var k = min; k < max; k++) {
      sum += probability(k);
      if (p <= sum) {
        return k;
      }
    }
    return max;
  }
}
