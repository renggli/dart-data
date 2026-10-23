import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('BilinearInterpolation', () {
    test('exact nodal evaluation', () {
      final xs = [0.0, 1.0, 2.0];
      final ys = [0.0, 2.0, 4.0];
      final values = Matrix<double>.generate(
        3,
        3,
        (r, c) => r * 10.0 + c * 1.0,
        type: DataType.float64,
      );

      final interp = BilinearInterpolation(xs, ys, values);

      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          check(interp(xs[r], ys[c]))
              .isCloseTo(values.getUnchecked(r, c), 1e-12);
        }
      }
    });

    test('exact reproduction of linear surface', () {
      // f(x, y) = 3*x - 2*y + 7
      double f(double x, double y) => 3.0 * x - 2.0 * y + 7.0;

      final xs = [0.0, 2.0, 5.0];
      final ys = [1.0, 3.0, 6.0];
      final values = Matrix<double>.generate(
        3,
        3,
        (r, c) => f(xs[r], ys[c]),
        type: DataType.float64,
      );

      final interp = BilinearInterpolation(xs, ys, values);

      // Midpoints and non-grid points
      final testPoints = [(1.0, 2.0), (3.5, 4.5), (0.5, 5.0), (4.0, 1.5)];

      for (final (x, y) in testPoints) {
        check(interp(x, y)).isCloseTo(f(x, y), 1e-10);
        final grad = interp.gradient(x, y);
        check(grad[0]).isCloseTo(3.0, 1e-10);
        check(grad[1]).isCloseTo(-2.0, 1e-10);
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

      final bilinear = BilinearInterpolation(xs, ys, values);

      // Outside bottom-left (should clamp to (0, 0))
      check(bilinear(-5.0, -5.0)).isCloseTo(values.getUnchecked(0, 0), 1e-10);

      // Outside top-right (should clamp to (1, 1))
      check(bilinear(10.0, 10.0)).isCloseTo(values.getUnchecked(1, 1), 1e-10);
    });

    test('error validation', () {
      final values = Matrix<double>.identity(2, type: DataType.float64);

      // Too few points
      check(() => BilinearInterpolation([1.0], [1.0, 2.0], values))
          .throws<ArgumentError>();
      check(() => BilinearInterpolation([1.0, 2.0], [1.0], values))
          .throws<ArgumentError>();

      // Non-monotonic points
      check(() => BilinearInterpolation([2.0, 1.0], [1.0, 2.0], values))
          .throws<ArgumentError>();
      check(() => BilinearInterpolation([1.0, 2.0], [2.0, 1.0], values))
          .throws<ArgumentError>();

      // Shape mismatch
      final mismatched = Matrix<double>.identity(3, type: DataType.float64);
      check(() => BilinearInterpolation([1.0, 2.0], [1.0, 2.0], mismatched))
          .throws<ArgumentError>();
    });
  });
}
