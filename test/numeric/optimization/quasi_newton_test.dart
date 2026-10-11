import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/optimization/quasi_newton.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('bfgs', () {
    test('minimizes 2D quadratic bowl', () {
      // f(x, y) = (x - 2)^2 + 3*(y + 1)^2 + 4, min at (2, -1), value = 4
      double f(Vector<double> v) =>
          (v[0] - 2.0) * (v[0] - 2.0) + 3.0 * (v[1] + 1.0) * (v[1] + 1.0) + 4.0;

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final res = bfgs(f, start);

      check(res.point[0]).isCloseTo(2.0, 1e-4);
      check(res.point[1]).isCloseTo(-1.0, 1e-4);
      check(res.value).isCloseTo(4.0, 1e-4);
      check(res.gradientNorm).isLessThan(1e-4);
      check(res.iterations).isGreaterThan(0);
    });

    test('supports explicit analytical gradient', () {
      double f(Vector<double> v) => v[0] * v[0] + 4.0 * v[1] * v[1];
      Vector<double> grad(Vector<double> v) => Vector<double>.fromList([
        2.0 * v[0],
        8.0 * v[1],
      ], type: DataType.float64);

      final start = Vector<double>.fromList([3.0, 3.0], type: DataType.float64);
      final res = bfgs(f, start, gradient: grad);

      check(res.point[0]).isCloseTo(0.0, 1e-5);
      check(res.point[1]).isCloseTo(0.0, 1e-5);
      check(res.value).isCloseTo(0.0, 1e-5);
    });
  });

  group('lbfgs', () {
    test('minimizes 3D quadratic form', () {
      // f(x, y, z) = (x - 1)^2 + 2*(y - 2)^2 + 3*(z - 3)^2
      double f(Vector<double> v) =>
          (v[0] - 1.0) * (v[0] - 1.0) +
          2.0 * (v[1] - 2.0) * (v[1] - 2.0) +
          3.0 * (v[2] - 3.0) * (v[2] - 3.0);

      final start = Vector<double>.fromList([
        0.0,
        0.0,
        0.0,
      ], type: DataType.float64);
      final res = lbfgs(f, start, memorySize: 5);

      check(res.point[0]).isCloseTo(1.0, 1e-5);
      check(res.point[1]).isCloseTo(2.0, 1e-5);
      check(res.point[2]).isCloseTo(3.0, 1e-5);
      check(res.value).isCloseTo(0.0, 1e-5);
      check(res.gradientNorm).isLessThan(1e-4);
    });

    test('supports memorySize truncation', () {
      double f(Vector<double> v) => v[0] * v[0] + v[1] * v[1];
      final start = Vector<double>.fromList([
        5.0,
        -5.0,
      ], type: DataType.float64);
      final res = lbfgs(f, start, memorySize: 2, maxIterations: 100);

      check(res.point[0]).isCloseTo(0.0, 1e-5);
      check(res.point[1]).isCloseTo(0.0, 1e-5);
    });
  });
}
