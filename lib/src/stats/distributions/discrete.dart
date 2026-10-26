import 'dart:math';

import '../../type/data_type.dart';
import '../distribution.dart';
import 'continuous/normal.dart';
import 'errors.dart';

/// Abstract base class for discrete probability distributions over [int].
abstract class DiscreteDistribution extends Distribution<int> {
  /// Abstract constant constructor for subclassing [DiscreteDistribution].
  const new();

  @override
  int get lowerBound => DataType.integer.safeMin;

  @override
  bool get isLowerBoundOpen => lowerBound == DataType.integer.safeMin;

  @override
  int get upperBound => DataType.integer.safeMax;

  @override
  bool get isUpperBoundOpen => upperBound == DataType.integer.safeMax;

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
  int inverseCumulativeProbability(num probability) {
    InvalidProbability.check(probability);
    if (probability == 0) {
      return lowerBound;
    } else if (probability == 1 && isUpperBoundOpen) {
      return upperBound;
    }

    var k0 = 0;
    if (probability == 1) {
      k0 = upperBound;
    } else if (mean.isFinite && variance.isFinite && variance > 0) {
      final z = const NormalDistribution.standard()
          .inverseCumulativeProbability(probability);
      final guess = (mean + z * sqrt(variance)).round();
      k0 = guess.clamp(lowerBound, upperBound);
    } else if (lowerBound > 0) {
      k0 = lowerBound;
    } else if (upperBound < 0) {
      k0 = upperBound;
    }

    var low = lowerBound;
    var high = upperBound;

    const eps = 1e-14;
    if (cumulativeProbability(k0) + eps >= probability) {
      high = k0;
      var step = 1;
      while (high - lowerBound > step) {
        final next = high - step;
        if (cumulativeProbability(next) + eps < probability) {
          low = next;
          break;
        }
        high = next;
        if (step > (1 << 30)) break;
        step *= 2;
      }
    } else {
      low = k0;
      var step = 1;
      while (upperBound - low > step) {
        final next = low + step;
        if (cumulativeProbability(next) + eps >= probability) {
          high = next;
          break;
        }
        low = next;
        if (step > (1 << 30)) break;
        step *= 2;
      }
    }

    while (low < high) {
      final mid = low + ((high - low) ~/ 2);
      if (cumulativeProbability(mid) + eps >= probability) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return high;
  }
}
