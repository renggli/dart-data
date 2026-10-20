import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('BicubicInterpolation', () {
    test('exact nodal evaluation', () {
      final xs = [0.0, 1.0, 2.0, 3.0];
      final ys = [0.0, 1.0, 2.0, 3.0];
      final values = Matrix<double>.generate(
        4,
        4,
        (r, c) => (r + 1) * 5.0 + (c + 1) * 2.0,
        type: DataType.float64,
      );

      final interp = BicubicInterpolation(xs, ys, values);

      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          check(interp.evaluate(xs[r], ys[c]))
              .isCloseTo(values.getUnchecked(r, c), 1e-12);
          check(interp(xs[r], ys[c]))
              .isCloseTo(values.getUnchecked(r, c), 1e-12);
        }
      }
    });

    test('sin(x)*cos(y) surface and gradient accuracy', () {
      double f(double x, double y) => math.sin(x) * math.cos(y);
      double dfDx(double x, double y) => math.cos(x) * math.cos(y);
      double dfDy(double x, double y) => -math.sin(x) * math.sin(y);

      const n = 11;
      final xs = List<double>.generate(n, (i) => i * math.pi / (n - 1));
      final ys = List<double>.generate(n, (j) => j * math.pi / (n - 1));

      final values = Matrix<double>.generate(
        n,
        n,
        (r, c) => f(xs[r], ys[c]),
        type: DataType.float64,
      );

      final bicubic = BicubicInterpolation(xs, ys, values);

      // Test at intermediate points inside the grid
      final testCoords = [(0.5, 0.8), (1.2, 1.5), (2.0, 0.4), (2.5, 2.2)];

      for (final (x, y) in testCoords) {
        final exactVal = f(x, y);

        check(bicubic(x, y)).isCloseTo(exactVal, 0.005);

        // Gradient accuracy
        final grad = bicubic.gradient(x, y);
        check(grad[0]).isCloseTo(dfDx(x, y), 0.05);
        check(grad[1]).isCloseTo(dfDy(x, y), 0.05);
      }
    });

    test('clamping at grid boundaries', () {
      final xs = [0.0, 1.0];
      final ys = [0.0, 1.0];
      final values = Matrix<double>.generate(
        2,
        2,
        (r, c) => (r + c).toDouble(),
        type: DataType.float64,
      );

      final bicubic = BicubicInterpolation(xs, ys, values);

      // Outside bottom-left (should clamp to (0, 0))
      check(bicubic(-5.0, -5.0)).isCloseTo(values.getUnchecked(0, 0), 1e-10);

      // Outside top-right (should clamp to (1, 1))
      check(bicubic(10.0, 10.0)).isCloseTo(values.getUnchecked(1, 1), 1e-10);
    });

    test('error validation', () {
      final values = Matrix<double>.identity(2, type: DataType.float64);

      // Too few points
      check(() => BicubicInterpolation([1.0], [1.0, 2.0], values))
          .throws<ArgumentError>();
      check(() => BicubicInterpolation([1.0, 2.0], [1.0], values))
          .throws<ArgumentError>();

      // Non-monotonic points
      check(() => BicubicInterpolation([2.0, 1.0], [1.0, 2.0], values))
          .throws<ArgumentError>();
      check(() => BicubicInterpolation([1.0, 2.0], [2.0, 1.0], values))
          .throws<ArgumentError>();

      // Shape mismatch
      final mismatched = Matrix<double>.identity(3, type: DataType.float64);
      check(() => BicubicInterpolation([1.0, 2.0], [1.0, 2.0], mismatched))
          .throws<ArgumentError>();
    });
  });
}
