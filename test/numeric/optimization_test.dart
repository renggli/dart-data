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
}
