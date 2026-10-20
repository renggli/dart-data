import 'dart:math' as math;

/// Computes the derivative of [function] at [x].
///
/// Conceptually, the derivative is the instantaneous slope or rate of change of
/// a curve at a single point (such as a speedometer reading representing the
/// derivative of position). Formally, it computes the $n$-th derivative
/// $f^{(n)}(x)$ using central finite differences for the specified [order] (1
/// through 6) and stencil [accuracy] (2, 4, 6, or 8 points).
///
/// ```dart
/// final slope = derivative((x) => x * x, 3.0); // ~6.0
/// final curvature = derivative((x) => x * x * x, 2.0, order: 2); // ~12.0
/// final jerk = derivative((x) => x * x * x * x, 2.0, order: 3); // ~48.0
/// ```
double derivative(
  double Function(double) function,
  double x, {
  int order = 1,
  int accuracy = 2,
  double? step,
}) {
  final accuracyToWeights = _centralFiniteDifferences[order];
  if (accuracyToWeights == null) {
    throw ArgumentError.value(order, 'order', 'Must be between 1 and 6');
  }
  final weights = accuracyToWeights[accuracy];
  if (weights == null) {
    throw ArgumentError.value(
      accuracy,
      'accuracy',
      'Must be one of ${accuracyToWeights.keys.join(', ')} for order $order',
    );
  }
  final h =
      step ??
      switch (order) {
        1 => 1e-5,
        2 => 1e-4,
        3 => 1e-2,
        4 => 5e-2,
        5 => 1e-1,
        6 => 2e-1,
        _ => 1e-3,
      };
  final offset = weights.length ~/ 2;
  var result = 0.0;
  for (var i = 0; i < weights.length; i++) {
    result += weights[i] * function(x + (i - offset) * h);
  }
  return result / math.pow(h, order);
}

// Central finite difference table:
// https://en.wikipedia.org/wiki/Finite_difference_coefficient
const _centralFiniteDifferences = <int, Map<int, List<double>>>{
  // Derivative 1
  1: {
    2: [-1 / 2, 0, 1 / 2],
    4: [1 / 12, -2 / 3, 0, 2 / 3, -1 / 12],
    6: [-1 / 60, 3 / 20, -3 / 4, 0, 3 / 4, -3 / 20, 1 / 60],
    8: [1 / 280, -4 / 105, 1 / 5, -4 / 5, 0, 4 / 5, -1 / 5, 4 / 105, -1 / 280],
  },
  // Derivative 2
  2: {
    2: [1, -2, 1],
    4: [-1 / 12, 4 / 3, -5 / 2, 4 / 3, -1 / 12],
    6: [1 / 90, -3 / 20, 3 / 2, -49 / 18, 3 / 2, -3 / 20, 1 / 90],
    8: [
      -1 / 560,
      8 / 315,
      -1 / 5,
      8 / 5,
      -205 / 72,
      8 / 5,
      -1 / 5,
      8 / 315,
      -1 / 560,
    ],
  },
  // Derivative 3
  3: {
    2: [-1 / 2, 1, 0, -1, 1 / 2],
    4: [1 / 8, -1, 13 / 8, 0, -13 / 8, 1, -1 / 8],
    6: [
      -7 / 240,
      3 / 10,
      -169 / 120,
      61 / 30,
      0,
      -61 / 30,
      169 / 120,
      -3 / 10,
      7 / 240,
    ],
  },
  // Derivative 4
  4: {
    2: [1, -4, 6, -4, 1],
    4: [-1 / 6, 2, -13 / 2, 28 / 3, -13 / 2, 2, -1 / 6],
    6: [
      7 / 240,
      -2 / 5,
      169 / 60,
      -122 / 15,
      91 / 8,
      -122 / 15,
      169 / 60,
      -2 / 5,
      7 / 240,
    ],
  },
  // Derivative 5
  5: {
    2: [-1 / 2, 2, -5 / 2, 0, 5 / 2, -2, 1 / 2],
    4: [1 / 6, -3 / 2, 13 / 3, -29 / 6, 0, 29 / 6, -13 / 3, 3 / 2, -1 / 6],
    6: [
      -13 / 288,
      19 / 36,
      -87 / 32,
      13 / 2,
      -323 / 48,
      0,
      323 / 48,
      -13 / 2,
      87 / 32,
      -19 / 36,
      13 / 288,
    ],
  },
  // Derivative 6
  6: {
    2: [1, -6, 15, -20, 15, -6, 1],
    4: [-1 / 4, 3, -13, 29, -75 / 2, 29, -13, 3, -1 / 4],
    6: [
      13 / 240,
      -19 / 24,
      87 / 16,
      -39 / 2,
      323 / 8,
      -1023 / 20,
      323 / 8,
      -39 / 2,
      87 / 16,
      -19 / 24,
      13 / 240,
    ],
  },
};
