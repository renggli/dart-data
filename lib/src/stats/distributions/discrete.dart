import 'package:more/feature.dart';

import '../distribution.dart';

/// Abstract discrete distribution.
///
/// Subclasses must implement at least one of [probabilityDistribution] or
/// [cumulativeDistribution].
abstract class DiscreteDistribution extends Distribution<int> {
  const DiscreteDistribution();

  @override
  int get min => minSafeInteger;

  @override
  int get max => maxSafeInteger;

  @override
  // ignore: avoid_renaming_method_parameters
  double probabilityDistribution(int k) =>
      cumulativeDistribution(k) - cumulativeDistribution(k - 1);

  @override
  // ignore: avoid_renaming_method_parameters
  double cumulativeDistribution(int k) {
    if (k < min) {
      return 0.0;
    } else if (k <= max) {
      var sum = 0.0;
      for (var i = min; i <= k && i <= max; i++) {
        sum += probabilityDistribution(i);
      }
      return sum;
    } else {
      return 1.0;
    }
  }

  @override
  int inverseCumulativeDistribution(double p) {
    return 0;
  }
}
