import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/optimization.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Canonical Numerical Optimization (minimize)', () {
    test('1D Brent minimization of quadratic function', () {
      // f(x) = (x - 3)^2 + 5, minimum at x = 3, f(3) = 5
      double function(Vector<double> v) => (v[0] - 3.0) * (v[0] - 3.0) + 5.0;

      final result = minimize(function, a: 0.0, b: 6.0);
      check(result.point1D).isCloseTo(3.0, 1e-6);
      check(result.value).isCloseTo(5.0, 1e-6);
      check(result.converged).isTrue();
    });

    test('1D Brent minimization with initialPoint and bounds', () {
      double function(Vector<double> v) => (v[0] - 2.0) * (v[0] - 2.0) - 4.0;

      final result = minimize(
        function,
        initialPoint: Vector<double>.fromList([0.0]),
        bounds: const [BoxBound(lower: -1.0, upper: 5.0)],
        method: OptimizationMethod.brent,
      );
      check(result.point1D).isCloseTo(2.0, 1e-6);
      check(result.value).isCloseTo(-4.0, 1e-6);
    });

    test('Nelder-Mead simplex optimization on Rosenbrock banana function', () {
      // Rosenbrock: f(x, y) = (1 - x)^2 + 100*(y - x^2)^2
      // Global minimum at (1, 1), f(1, 1) = 0
      double rosenbrock(Vector<double> vec) {
        final x = vec[0];
        final y = vec[1];
        final d1 = 1.0 - x;
        final d2 = y - x * x;
        return d1 * d1 + 100.0 * d2 * d2;
      }

      final start = Vector<double>.fromList([
        -1.2,
        1.0,
      ], type: DataType.float64);
      final result = minimize(
        rosenbrock,
        initialPoint: start,
        method: OptimizationMethod.nelderMead,
        tolerance: 1e-5,
        maxIterations: 2000,
      );

      check(result.point[0]).isCloseTo(1.0, 0.02);
      check(result.point[1]).isCloseTo(1.0, 0.02);
      check(result.value).isCloseTo(0.0, 0.01);
    });

    test('BFGS optimization on quadratic bowl', () {
      // f(x, y) = (x - 2)^2 + 3*(y + 1)^2 + 4
      // Minimum at (2, -1) with value 4
      double f(Vector<double> v) =>
          (v[0] - 2.0) * (v[0] - 2.0) + 3.0 * (v[1] + 1.0) * (v[1] + 1.0) + 4.0;

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimize(
        f,
        initialPoint: start,
        method: OptimizationMethod.bfgs,
      );

      check(result.point[0]).isCloseTo(2.0, 1e-5);
      check(result.point[1]).isCloseTo(-1.0, 1e-5);
      check(result.value).isCloseTo(4.0, 1e-5);
      check(result.converged).isTrue();
    });

    test('L-BFGS optimization on 3D quadratic form', () {
      // f(x, y, z) = (x-1)^2 + 2*(y-2)^2 + 3*(z-3)^2
      double quadratic(Vector<double> vec) =>
          (vec[0] - 1.0) * (vec[0] - 1.0) +
          2.0 * (vec[1] - 2.0) * (vec[1] - 2.0) +
          3.0 * (vec[2] - 3.0) * (vec[2] - 3.0);

      final start = Vector<double>.fromList([
        0.0,
        0.0,
        0.0,
      ], type: DataType.float64);
      final result = minimize(
        quadratic,
        initialPoint: start,
        method: OptimizationMethod.lbfgs,
        memorySize: 5,
      );

      check(result.point[0]).isCloseTo(1.0, 1e-5);
      check(result.point[1]).isCloseTo(2.0, 1e-5);
      check(result.point[2]).isCloseTo(3.0, 1e-5);
      check(result.value).isCloseTo(0.0, 1e-5);
    });

    test('1D scalar minimization with two-sided box bounds', () {
      // f(x) = (x - 5)^2 + 2, unconstrained min at x = 5.
      // With bounds [0, 2], constrained min at x = 2, f(2) = 11.
      double f(Vector<double> v) => (v[0] - 5.0) * (v[0] - 5.0) + 2.0;

      final start = Vector<double>.fromList([0.0], type: DataType.float64);
      final result = minimize(
        f,
        initialPoint: start,
        bounds: const [BoxBound(lower: 0.0, upper: 2.0)],
      );

      check(result.point[0]).isCloseTo(2.0, 1e-4);
      check(result.value).isCloseTo(11.0, 1e-4);
      check(result.converged).isTrue();
    });

    test('1D scalar minimization with lower-only bound', () {
      // f(x) = (x - 1)^2, unconstrained min at x = 1.
      // With lower bound x >= 3, constrained min at x = 3, f(3) = 4.
      double f(Vector<double> v) => (v[0] - 1.0) * (v[0] - 1.0);

      final start = Vector<double>.fromList([4.0], type: DataType.float64);
      final result = minimize(
        f,
        initialPoint: start,
        bounds: const [BoxBound(lower: 3.0)],
      );

      check(result.point[0]).isCloseTo(3.0, 1e-4);
      check(result.value).isCloseTo(4.0, 1e-4);
      check(result.converged).isTrue();
    });

    test('1D scalar minimization with upper-only bound', () {
      // f(x) = (x + 2)^2, unconstrained min at x = -2.
      // With upper bound x <= -5, constrained min at x = -5, f(-5) = 9.
      double f(Vector<double> v) => (v[0] + 2.0) * (v[0] + 2.0);

      final start = Vector<double>.fromList([-6.0], type: DataType.float64);
      final result = minimize(
        f,
        initialPoint: start,
        bounds: const [BoxBound(upper: -5.0)],
      );

      check(result.point[0]).isCloseTo(-5.0, 1e-4);
      check(result.value).isCloseTo(9.0, 1e-4);
      check(result.converged).isTrue();
    });

    test('2D quadratic bowl with active box bounds', () {
      // f(x, y) = (x - 2)^2 + (y - 3)^2, unconstrained min at (2, 3).
      // With bounds [0, 1] x [0, 1], constrained min at (1, 1), value (1-2)^2 + (1-3)^2 = 5.
      double f(Vector<double> v) =>
          (v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 3.0) * (v[1] - 3.0);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimize(
        f,
        initialPoint: start,
        bounds: const [
          BoxBound(lower: 0.0, upper: 1.0),
          BoxBound(lower: 0.0, upper: 1.0),
        ],
      );

      check(result.point[0]).isCloseTo(1.0, 1e-4);
      check(result.point[1]).isCloseTo(1.0, 1e-4);
      check(result.value).isCloseTo(5.0, 1e-4);
      check(result.converged).isTrue();
    });

    test('2D quadratic bowl with inactive box bounds', () {
      // f(x, y) = (x - 2)^2 + (y - 3)^2.
      // Bounds [0, 5] x [0, 5] contain the minimum (2, 3).
      double f(Vector<double> v) =>
          (v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 3.0) * (v[1] - 3.0);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimize(
        f,
        initialPoint: start,
        bounds: const [
          BoxBound(lower: 0.0, upper: 5.0),
          BoxBound(lower: 0.0, upper: 5.0),
        ],
      );

      check(result.point[0]).isCloseTo(2.0, 1e-5);
      check(result.point[1]).isCloseTo(3.0, 1e-5);
      check(result.value).isCloseTo(0.0, 1e-5);
      check(result.converged).isTrue();
    });

    test(
      'Rosenbrock function with unconstrained minimum inside box bounds',
      () {
        // Rosenbrock min at (1, 1), value 0.
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
        final result = minimize(
          rosenbrock,
          initialPoint: start,
          bounds: const [
            BoxBound(lower: -2.0, upper: 2.0),
            BoxBound(lower: -2.0, upper: 2.0),
          ],
        );

        check(result.point[0]).isCloseTo(1.0, 1e-4);
        check(result.point[1]).isCloseTo(1.0, 1e-4);
        check(result.value).isCloseTo(0.0, 1e-4);
        check(result.converged).isTrue();
      },
    );

    test('Rosenbrock function with active upper bound on x', () {
      // Global min at (1, 1) is excluded by x <= 0.5.
      // Constrained min at x = 0.5, y = x^2 = 0.25, f(0.5, 0.25) = (1-0.5)^2 = 0.25.
      double rosenbrock(Vector<double> v) {
        final x = v[0];
        final y = v[1];
        final d1 = 1.0 - x;
        final d2 = y - x * x;
        return d1 * d1 + 100.0 * d2 * d2;
      }

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimize(
        rosenbrock,
        initialPoint: start,
        bounds: const [
          BoxBound(lower: -2.0, upper: 0.5),
          BoxBound(lower: -1.0, upper: 2.0),
        ],
      );

      check(result.point[0]).isCloseTo(0.5, 1e-4);
      check(result.point[1]).isCloseTo(0.25, 1e-4);
      check(result.value).isCloseTo(0.25, 1e-4);
    });

    test('Rosenbrock function with active lower bound on x', () {
      // Global min at (1, 1) is excluded by x >= 1.5.
      // Constrained min at x = 1.5, y = 1.5^2 = 2.25, f(1.5, 2.25) = (1-1.5)^2 = 0.25.
      double rosenbrock(Vector<double> v) {
        final x = v[0];
        final y = v[1];
        final d1 = 1.0 - x;
        final d2 = y - x * x;
        return d1 * d1 + 100.0 * d2 * d2;
      }

      final start = Vector<double>.fromList([1.6, 2.5], type: DataType.float64);
      final result = minimize(
        rosenbrock,
        initialPoint: start,
        bounds: const [
          BoxBound(lower: 1.5, upper: 3.0),
          BoxBound(lower: 0.0, upper: 5.0),
        ],
      );

      check(result.point[0]).isCloseTo(1.5, 1e-4);
      check(result.point[1]).isCloseTo(2.25, 1e-4);
      check(result.value).isCloseTo(0.25, 1e-4);
    });

    test('Mixed bounds: bounded and unbounded coordinates', () {
      // f(x, y) = (x - 5)^2 + (y - 5)^2
      // x in [0, 2], y unbounded (null)
      double f(Vector<double> v) =>
          (v[0] - 5.0) * (v[0] - 5.0) + (v[1] - 5.0) * (v[1] - 5.0);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimize(
        f,
        initialPoint: start,
        bounds: const [BoxBound(lower: 0.0, upper: 2.0), BoxBound()],
      );

      check(result.point[0]).isCloseTo(2.0, 1e-4);
      check(result.point[1]).isCloseTo(5.0, 1e-4);
      check(result.value).isCloseTo(9.0, 1e-4);
    });

    test('Out-of-bounds initial point cleanly projected into feasible box', () {
      // Bounds [0, 1], start at 10.0
      double f(Vector<double> v) => (v[0] - 0.5) * (v[0] - 0.5);

      final start = Vector<double>.fromList([10.0], type: DataType.float64);
      final result = minimize(
        f,
        initialPoint: start,
        bounds: const [BoxBound(lower: 0.0, upper: 1.0)],
      );

      check(result.point[0]).isCloseTo(0.5, 1e-4);
      check(result.value).isCloseTo(0.0, 1e-4);
    });

    test('Equality constraint combined with box bounds', () {
      // f(x, y) = x^2 + y^2
      // Subject to x + y = 3 and x in [0, 1], y in [0, 5]
      // Unconstrained min on x + y = 3 is (1.5, 1.5).
      // Since x <= 1, constrained min is at (1.0, 2.0), value 1 + 4 = 5.
      double f(Vector<double> v) => v[0] * v[0] + v[1] * v[1];
      double eq(Vector<double> v) => v[0] + v[1] - 3.0;

      final start = Vector<double>.fromList([0.5, 2.5], type: DataType.float64);
      final result = minimize(
        f,
        initialPoint: start,
        bounds: const [
          BoxBound(lower: 0.0, upper: 1.0),
          BoxBound(lower: 0.0, upper: 5.0),
        ],
        equalities: [eq],
      );

      check(result.point[0]).isCloseTo(1.0, 1e-3);
      check(result.point[1]).isCloseTo(2.0, 1e-3);
      check(result.value).isCloseTo(5.0, 1e-3);
      check(eq(result.point).abs()).isLessThan(1e-3);
    });

    test('BoxBound equality, hashCode, and toString', () {
      const b1 = BoxBound(lower: 0.0, upper: 1.0);
      const b2 = BoxBound(lower: 0.0, upper: 1.0);
      const b3 = BoxBound(lower: -1.0, upper: 1.0);

      check(b1).equals(b2);
      check(b1.hashCode).equals(b2.hashCode);
      check(b1 == b3).isFalse();
      check(b1.toString()).startsWith('BoxBound(');
      check(b1.toString()).contains('lower:');
      check(b1.toString()).contains('upper:');
    });

    test('Error validation for invalid bounds and arguments', () {
      final start = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);

      // Bounds length mismatch
      check(
        () => minimize(
          (v) => 0.0,
          initialPoint: start,
          bounds: const [BoxBound()],
        ),
      ).throws<ArgumentError>();

      // Lower >= upper
      check(
        () => minimize(
          (v) => 0.0,
          initialPoint: start,
          bounds: const [BoxBound(lower: 5.0, upper: 2.0), BoxBound()],
        ),
      ).throws<ArgumentError>();

      // Empty initial point
      check(
        () => minimize(
          (v) => 0.0,
          initialPoint: Vector<double>.fromList([], type: DataType.float64),
        ),
      ).throws<ArgumentError>();

      // Non-positive tolerance or maxIterations
      check(() => minimize((v) => 0.0, initialPoint: start, tolerance: 0.0))
          .throws<ArgumentError>();
      check(() => minimize((v) => 0.0, initialPoint: start, maxIterations: -1))
          .throws<ArgumentError>();

      // Missing initialPoint and interval
      check(() => minimize((v) => 0.0)).throws<ArgumentError>();
    });
  });
}
