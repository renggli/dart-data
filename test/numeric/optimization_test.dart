import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/optimization.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Optimization Algorithms', () {
    test('1D Brent minimization of quadratic function', () {
      // f(x) = (x - 3)^2 + 5, minimum at x = 3, f(3) = 5
      double function(double x) => (x - 3.0) * (x - 3.0) + 5.0;

      final result = brentMinimize(function, a: 0.0, b: 6.0);
      check(result.point).isCloseTo(3.0, 1e-6);
      check(result.value).isCloseTo(5.0, 1e-6);
    });

    test('1D Brent minimization with Expr', () {
      const x = Variable('x');
      // f(x) = (x - 2)^2 - 4
      final expr = (x - const Constant(2.0)).pow(2) - const Constant(4.0);

      final result = brentMinimize(expr, a: -1.0, b: 5.0, variable: 'x');
      check(result.point).isCloseTo(2.0, 1e-6);
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
      final result = nelderMead(
        rosenbrock,
        start,
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
      final result = bfgs(f, start);

      check(result.point[0]).isCloseTo(2.0, 1e-5);
      check(result.point[1]).isCloseTo(-1.0, 1e-5);
      check(result.value).isCloseTo(4.0, 1e-5);
    });

    test('BFGS seamlessly accepting symbolic Expr', () {
      const x = Variable('x');
      const y = Variable('y');
      // f(x, y) = x^2 + y^2 - 4*x - 6*y + 13 = (x-2)^2 + (y-3)^2
      final expr =
          x.pow(2) +
          y.pow(2) -
          const Constant(4.0) * x -
          const Constant(6.0) * y +
          const Constant(13.0);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = bfgs(expr, start, variables: ['x', 'y']);

      check(result.point[0]).isCloseTo(2.0, 1e-5);
      check(result.point[1]).isCloseTo(3.0, 1e-5);
      check(result.value).isCloseTo(0.0, 1e-5);
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
      final result = lbfgs(quadratic, start, memorySize: 5);

      check(result.point[0]).isCloseTo(1.0, 1e-5);
      check(result.point[1]).isCloseTo(2.0, 1e-5);
      check(result.point[2]).isCloseTo(3.0, 1e-5);
      check(result.value).isCloseTo(0.0, 1e-5);

      // L-BFGS with Expr
      const x = Variable('x');
      const y = Variable('y');
      final fExpr =
          (x - const Constant(1.0)).pow(2) + (y - const Constant(2.0)).pow(2);
      final lbfgsExprRes = lbfgs(
        fExpr,
        Vector<double>.fromList([0.0, 0.0], type: DataType.float64),
        variables: ['x', 'y'],
      );
      check(lbfgsExprRes.point[0]).isCloseTo(1.0, 1e-5);
      check(lbfgsExprRes.point[1]).isCloseTo(2.0, 1e-5);
    });

    test(
      'Optimization error checking on unsupported types and num functions',
      () {
        num fnNum(num val) => (val - 4) * (val - 4);
        final brentNum = brentMinimize(fnNum, a: 0.0, b: 10.0);
        check(brentNum.point).isCloseTo(4.0, 1e-6);

        // Nelder-Mead with Expr
        const x = Variable('x');
        const y = Variable('y');
        final fExpr =
            (x - const Constant(3.0)).pow(2) + (y - const Constant(4.0)).pow(2);
        final nmRes = nelderMead(
          fExpr,
          Vector<double>.fromList([0.0, 0.0], type: DataType.float64),
          variables: ['x', 'y'],
        );
        check(nmRes.point[0]).isCloseTo(3.0, 1e-4);
        check(nmRes.point[1]).isCloseTo(4.0, 1e-4);

        // Invalid types
        final start = Vector<double>.fromList([0.0], type: DataType.float64);
        check(() => brentMinimize('invalid', a: 0.0, b: 1.0))
            .throws<ArgumentError>();
        check(() => nelderMead('invalid', start)).throws<ArgumentError>();
        check(() => bfgs('invalid', start)).throws<ArgumentError>();
        check(() => lbfgs('invalid', start)).throws<ArgumentError>();

        // BFGS with Expr
        final bfgsExpr = bfgs(
          fExpr,
          Vector<double>.fromList([0.0, 0.0], type: DataType.float64),
          variables: ['x', 'y'],
        );
        check(bfgsExpr.point[0]).isCloseTo(3.0, 1e-4);
        check(bfgsExpr.point[1]).isCloseTo(4.0, 1e-4);

        // Max iterations hit
        final brentLimited = brentMinimize(
          (num x) => (x * x).toDouble(),
          a: -1.0,
          b: 1.0,
          maxIterations: 1,
        );
        check(brentLimited.iterations).equals(1);

        final nmLimited = nelderMead(
          (Vector<double> vec) => vec[0] * vec[0],
          start,
          maxIterations: 1,
        );
        check(nmLimited.iterations).equals(1);

        final bfgsLimited = bfgs(
          (Vector<double> vec) => vec[0] * vec[0] + 10.0,
          Vector<double>.fromList([10.0], type: DataType.float64),
          maxIterations: 1,
        );
        check(bfgsLimited.iterations).equals(1);

        final lbfgsLimited = lbfgs(
          (Vector<double> vec) => vec[0] * vec[0] + 10.0,
          Vector<double>.fromList([10.0], type: DataType.float64),
          maxIterations: 1,
        );
        check(lbfgsLimited.iterations).equals(1);
      },
    );
  });

  group('Constrained Optimization (minimizeConstrained)', () {
    test('1D scalar minimization with two-sided box bounds', () {
      // f(x) = (x - 5)^2 + 2, unconstrained min at x = 5.
      // With bounds [0, 2], constrained min at x = 2, f(2) = 11.
      double f(double x) => (x - 5.0) * (x - 5.0) + 2.0;

      final start = Vector<double>.fromList([0.0], type: DataType.float64);
      final result = minimizeConstrained(
        f,
        start,
        bounds: const [BoxBound(lower: 0.0, upper: 2.0)],
      );

      check(result.point[0]).isCloseTo(2.0, 1e-4);
      check(result.value).isCloseTo(11.0, 1e-4);
      check(result.converged).isTrue();
    });

    test('1D scalar minimization with lower-only bound', () {
      // f(x) = (x - 1)^2, unconstrained min at x = 1.
      // With lower bound x >= 3, constrained min at x = 3, f(3) = 4.
      double f(double x) => (x - 1.0) * (x - 1.0);

      final start = Vector<double>.fromList([4.0], type: DataType.float64);
      final result = minimizeConstrained(
        f,
        start,
        bounds: const [BoxBound(lower: 3.0)],
      );

      check(result.point[0]).isCloseTo(3.0, 1e-4);
      check(result.value).isCloseTo(4.0, 1e-4);
      check(result.converged).isTrue();
    });

    test('1D scalar minimization with upper-only bound', () {
      // f(x) = (x + 2)^2, unconstrained min at x = -2.
      // With upper bound x <= -5, constrained min at x = -5, f(-5) = 9.
      double f(double x) => (x + 2.0) * (x + 2.0);

      final start = Vector<double>.fromList([-6.0], type: DataType.float64);
      final result = minimizeConstrained(
        f,
        start,
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
      final result = minimizeConstrained(
        f,
        start,
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
      final result = minimizeConstrained(
        f,
        start,
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
        final result = minimizeConstrained(
          rosenbrock,
          start,
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
      final result = minimizeConstrained(
        rosenbrock,
        start,
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
      final result = minimizeConstrained(
        rosenbrock,
        start,
        bounds: const [
          BoxBound(lower: 1.5, upper: 3.0),
          BoxBound(lower: 0.0, upper: 5.0),
        ],
      );

      check(result.point[0]).isCloseTo(1.5, 1e-4);
      check(result.point[1]).isCloseTo(2.25, 1e-4);
      check(result.value).isCloseTo(0.25, 1e-4);
    });

    test('Symbolic Expr objective with box bounds', () {
      const x = Variable('x');
      const y = Variable('y');
      // f(x, y) = (1 - x)^2 + 100 * (y - x^2)^2
      final expr =
          (const Constant(1.0) - x).pow(2) +
          const Constant(100.0) * (y - x.pow(2)).pow(2);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimizeConstrained(
        expr,
        start,
        variables: ['x', 'y'],
        bounds: const [
          BoxBound(lower: -2.0, upper: 0.5),
          BoxBound(lower: -1.0, upper: 2.0),
        ],
      );

      check(result.point[0]).isCloseTo(0.5, 1e-4);
      check(result.point[1]).isCloseTo(0.25, 1e-4);
      check(result.value).isCloseTo(0.25, 1e-4);
    });

    test(
      'Inequality constraint via Augmented Lagrangian (linear constraint)',
      () {
        // Minimize f(x, y) = x^2 + y^2 subject to x + y >= 2, i.e. 2 - x - y <= 0.
        // Minimum at (1, 1), value 2.
        double f(Vector<double> v) => v[0] * v[0] + v[1] * v[1];
        double ineq(Vector<double> v) => 2.0 - (v[0] + v[1]);

        final start = Vector<double>.fromList([
          0.0,
          0.0,
        ], type: DataType.float64);
        final result = minimizeConstrained(f, start, inequalities: [ineq]);

        check(result.point[0]).isCloseTo(1.0, 1e-3);
        check(result.point[1]).isCloseTo(1.0, 1e-3);
        check(result.value).isCloseTo(2.0, 1e-3);
        check(ineq(result.point)).isLessThan(1e-4);
      },
    );

    test('Non-linear inequality constraint on unit disk', () {
      // Minimize f(x, y) = (x - 2)^2 + (y - 2)^2 subject to x^2 + y^2 <= 1.
      // Constrained min at (1/sqrt(2), 1/sqrt(2)) = (0.707106, 0.707106).
      double f(Vector<double> v) =>
          (v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 2.0) * (v[1] - 2.0);
      double ineq(Vector<double> v) => v[0] * v[0] + v[1] * v[1] - 1.0;

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimizeConstrained(f, start, inequalities: [ineq]);

      final expected = 1.0 / math.sqrt(2.0);
      check(result.point[0]).isCloseTo(expected, 1e-3);
      check(result.point[1]).isCloseTo(expected, 1e-3);
      check(ineq(result.point)).isLessThan(1e-4);
    });

    test('Equality constraint via Augmented Lagrangian', () {
      // Minimize f(x, y) = (x - 2)^2 + (y - 3)^2 subject to x + y = 1.
      // Constrained min at (0, 1), value 4 + 4 = 8.
      double f(Vector<double> v) =>
          (v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 3.0) * (v[1] - 3.0);
      double eq(Vector<double> v) => v[0] + v[1] - 1.0;

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimizeConstrained(f, start, equalities: [eq]);

      check(result.point[0]).isCloseTo(0.0, 1e-3);
      check(result.point[1]).isCloseTo(1.0, 1e-3);
      check(result.value).isCloseTo(8.0, 1e-3);
      check(eq(result.point).abs()).isLessThan(1e-3);
    });

    test('Combined box bounds and inequality constraint', () {
      // Minimize (x - 3)^2 + (y - 3)^2 on x, y in [0, 2] and x + y <= 3.
      // Optimal point is at (1.5, 1.5), value (1.5-3)^2 + (1.5-3)^2 = 4.5.
      double f(Vector<double> v) =>
          (v[0] - 3.0) * (v[0] - 3.0) + (v[1] - 3.0) * (v[1] - 3.0);
      double ineq(Vector<double> v) => (v[0] + v[1]) - 3.0;

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimizeConstrained(
        f,
        start,
        bounds: const [
          BoxBound(lower: 0.0, upper: 2.0),
          BoxBound(lower: 0.0, upper: 2.0),
        ],
        inequalities: [ineq],
      );

      check(result.point[0]).isCloseTo(1.5, 1e-3);
      check(result.point[1]).isCloseTo(1.5, 1e-3);
      check(result.value).isCloseTo(4.5, 1e-3);
    });

    test('Symbolic inequality constraint with Expr', () {
      const x = Variable('x');
      const y = Variable('y');
      // Objective f(x, y) = x^2 + y^2
      final obj = x.pow(2) + y.pow(2);
      // Constraint 2 - (x + y) <= 0
      final ineq = const Constant(2.0) - x - y;

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimizeConstrained(
        obj,
        start,
        variables: ['x', 'y'],
        inequalities: [ineq],
      );

      check(result.point[0]).isCloseTo(1.0, 1e-3);
      check(result.point[1]).isCloseTo(1.0, 1e-3);
      check(result.value).isCloseTo(2.0, 1e-3);
    });

    test('Explicit custom gradient callback in minimizeConstrained', () {
      // f(x, y) = (x - 3)^2 + (y - 4)^2
      double f(Vector<double> v) =>
          (v[0] - 3.0) * (v[0] - 3.0) + (v[1] - 4.0) * (v[1] - 4.0);
      Vector<double> grad(Vector<double> v) => Vector<double>.fromList([
        2.0 * (v[0] - 3.0),
        2.0 * (v[1] - 4.0),
      ], type: DataType.float64);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimizeConstrained(
        f,
        start,
        gradient: grad,
        bounds: const [
          BoxBound(lower: 0.0, upper: 2.0),
          BoxBound(lower: 0.0, upper: 2.0),
        ],
      );

      check(result.point[0]).isCloseTo(2.0, 1e-4);
      check(result.point[1]).isCloseTo(2.0, 1e-4);
      check(result.value).isCloseTo(5.0, 1e-4);
    });

    test('Mixed bounds: bounded and unbounded coordinates', () {
      // f(x, y) = (x - 5)^2 + (y - 5)^2
      // x in [0, 2], y unbounded (null)
      double f(Vector<double> v) =>
          (v[0] - 5.0) * (v[0] - 5.0) + (v[1] - 5.0) * (v[1] - 5.0);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = minimizeConstrained(
        f,
        start,
        bounds: const [BoxBound(lower: 0.0, upper: 2.0), BoxBound()],
      );

      check(result.point[0]).isCloseTo(2.0, 1e-4);
      check(result.point[1]).isCloseTo(5.0, 1e-4);
      check(result.value).isCloseTo(9.0, 1e-4);
    });

    test('Out-of-bounds initial point cleanly projected into feasible box', () {
      // Bounds [0, 1], start at 10.0
      double f(double x) => (x - 0.5) * (x - 0.5);

      final start = Vector<double>.fromList([10.0], type: DataType.float64);
      final result = minimizeConstrained(
        f,
        start,
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
      final result = minimizeConstrained(
        f,
        start,
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

    test('1D symbolic Expr with bounds', () {
      const x = Variable('x');
      final expr = (x - const Constant(4.0)).pow(2) + const Constant(1.0);

      final start = Vector<double>.fromList([0.0], type: DataType.float64);
      final result = minimizeConstrained(
        expr,
        start,
        variables: ['x'],
        bounds: const [BoxBound(lower: 0.0, upper: 2.0)],
      );

      check(result.point[0]).isCloseTo(2.0, 1e-4);
      check(result.value).isCloseTo(5.0, 1e-4);
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
        () =>
            minimizeConstrained((v) => 0.0, start, bounds: const [BoxBound()]),
      ).throws<ArgumentError>();

      // Variables length mismatch
      check(() => minimizeConstrained((v) => 0.0, start, variables: ['x']))
          .throws<ArgumentError>();

      // Lower >= upper
      check(
        () => minimizeConstrained(
          (v) => 0.0,
          start,
          bounds: const [BoxBound(lower: 5.0, upper: 2.0), BoxBound()],
        ),
      ).throws<ArgumentError>();

      // Empty initial point
      check(
        () => minimizeConstrained(
          (v) => 0.0,
          Vector<double>.fromList([], type: DataType.float64),
        ),
      ).throws<ArgumentError>();

      // Non-positive tolerance or maxIterations
      check(() => minimizeConstrained((v) => 0.0, start, tolerance: 0.0))
          .throws<ArgumentError>();
      check(() => minimizeConstrained((v) => 0.0, start, maxIterations: -1))
          .throws<ArgumentError>();

      // Unsupported function type
      check(() => minimizeConstrained('not a function', start))
          .throws<ArgumentError>();
    });
  });
}
