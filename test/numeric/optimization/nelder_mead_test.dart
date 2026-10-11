import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/optimization/nelder_mead.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('nelderMead', () {
    test('optimizes 2D paraboloid', () {
      // f(x, y) = (x - 1)^2 + (y - 2)^2
      double f(Vector<double> v) =>
          (v[0] - 1.0) * (v[0] - 1.0) + (v[1] - 2.0) * (v[1] - 2.0);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final res = nelderMead(f, start, tolerance: 1e-6);

      check(res.point[0]).isCloseTo(1.0, 1e-4);
      check(res.point[1]).isCloseTo(2.0, 1e-4);
      check(res.value).isCloseTo(0.0, 1e-4);
      check(res.iterations).isGreaterThan(0);
    });

    test('optimizes Rosenbrock banana function', () {
      double rosenbrock(Vector<double> v) {
        final x = v[0];
        final y = v[1];
        final d1 = 1.0 - x;
        final d2 = y - x * x;
        return d1 * d1 + 100.0 * d2 * d2;
      }

      final start = Vector<double>.fromList([
        -1.2,
        1.0,
      ], type: DataType.float64);
      final res = nelderMead(
        rosenbrock,
        start,
        tolerance: 1e-5,
        maxIterations: 2000,
      );

      check(res.point[0]).isCloseTo(1.0, 0.02);
      check(res.point[1]).isCloseTo(1.0, 0.02);
      check(res.value).isCloseTo(0.0, 0.01);
    });

    test('stops after maxIterations', () {
      double f(Vector<double> v) => v[0] * v[0] + v[1] * v[1];
      final start = Vector<double>.fromList([
        10.0,
        10.0,
      ], type: DataType.float64);
      final res = nelderMead(f, start, maxIterations: 5);
      check(res.iterations).isLessOrEqual(5);
    });
  });
}
