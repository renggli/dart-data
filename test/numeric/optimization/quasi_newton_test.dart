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

    test(
      'minimizes 10D quadratic form efficiently using O(n^2) rank-2 update',
      () {
        // f(x) = sum_{i=0..9} (i + 1) * (x_i - (i + 1))^2
        double f(Vector<double> v) {
          var sum = 0.0;
          for (var i = 0; i < 10; i++) {
            final diff = v[i] - (i + 1.0);
            sum += (i + 1.0) * diff * diff;
          }
          return sum;
        }

        Vector<double> grad(Vector<double> v) => Vector<double>.generate(
          10,
          (i) => 2.0 * (i + 1.0) * (v[i] - (i + 1.0)),
          type: DataType.float64,
        );

        final start = Vector<double>.filled(10, 0.0, type: DataType.float64);
        final res = bfgs(f, start, gradient: grad);

        for (var i = 0; i < 10; i++) {
          check(res.point[i]).isCloseTo(i + 1.0, 1e-4);
        }
        check(res.value).isCloseTo(0.0, 1e-4);
        check(res.gradientNorm).isLessThan(1e-4);
      },
    );

    test('eliminates redundant function evaluations in line search', () {
      var evalCount = 0;
      double f(Vector<double> v) {
        evalCount++;
        return v[0] * v[0] + v[1] * v[1];
      }

      Vector<double> grad(Vector<double> v) => Vector<double>.fromList([
        2.0 * v[0],
        2.0 * v[1],
      ], type: DataType.float64);

      final start = Vector<double>.fromList([2.0, 2.0], type: DataType.float64);
      final res = bfgs(f, start, gradient: grad);
      // Quadratic function with exact gradient:
      // Initial f(x) [1] + line search step alpha=1 [1] + alpha=0.5 [1] = 3 evals
      // (Without reuse of fxCandidate, an extra redundant eval fn(xNext) occurred = 4 evals)
      check(res.iterations).equals(1);
      check(evalCount).equals(3);
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
