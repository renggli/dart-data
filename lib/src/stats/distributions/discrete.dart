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
      final guess = mean + z * sqrt(variance);
      if (guess.isFinite) {
        k0 = guess.clamp(lowerBound.toDouble(), upperBound.toDouble()).round();
      }
    } else if (lowerBound > 0) {
      k0 = lowerBound;
    } else if (upperBound < 0) {
      k0 = upperBound;
    }

    var low = lowerBound;
    var high = upperBound;

    final target = probability * (1.0 - 1e-14);
    if (cumulativeProbability(k0) >= target) {
      high = k0;
      var step = 1;
      while (high - lowerBound > step) {
        final next = high - step;
        if (cumulativeProbability(next) < target) {
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
        if (cumulativeProbability(next) >= target) {
          high = next;
          break;
        }
        low = next;
        if (step > (1 << 30)) break;
        step *= 2;
      }
    }

    while (low < high) {
      final mid = _midpoint(low, high);
      if (cumulativeProbability(mid) >= target) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return high;
  }

  @override
  int inverseSurvival(num probability) {
    InvalidProbability.check(probability);
    if (probability >= 0.5) {
      return inverseCumulativeProbability(1.0 - probability);
    }
    if (probability == 0 && isUpperBoundOpen) {
      return upperBound;
    }

    var k0 = 0;
    if (probability == 0) {
      k0 = upperBound;
    } else if (mean.isFinite && variance.isFinite && variance > 0) {
      final z = const NormalDistribution.standard().inverseSurvival(
        probability,
      );
      final guess = mean + z * sqrt(variance);
      if (guess.isFinite) {
        k0 = guess.clamp(lowerBound.toDouble(), upperBound.toDouble()).round();
      }
    } else if (lowerBound > 0) {
      k0 = lowerBound;
    } else if (upperBound < 0) {
      k0 = upperBound;
    }

    var low = lowerBound;
    var high = upperBound;

    final target = probability * (1.0 + 1e-14);
    if (survival(k0) <= target) {
      high = k0;
      var step = 1;
      while (high - lowerBound > step) {
        final next = high - step;
        if (survival(next) > target) {
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
        if (survival(next) <= target) {
          high = next;
          break;
        }
        low = next;
        if (step > (1 << 30)) break;
        step *= 2;
      }
    }

    while (low < high) {
      final mid = _midpoint(low, high);
      if (survival(mid) <= target) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return high;
  }

  static int _midpoint(int low, int high) =>
      low < 0 && high > 0 ? (low + high) ~/ 2 : low + ((high - low) ~/ 2);
}
