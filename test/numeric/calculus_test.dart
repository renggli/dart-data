import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/calculus.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Numerical & Symbolic Calculus', () {
    test('numerical derivative of scalar function', () {
      // f(x) = x^3 => f'(2) = 12
      double f(double x) => x * x * x;
      check(numericalDerivative(f, 2.0)).isCloseTo(12.0, 1e-5);
      check(numericalSecondDerivative(f, 2.0)).isCloseTo(12.0, 1e-3);
    });

    test('derivative of Expr symbolic AST', () {
      // f(x) = sin(x) * x
      const x = Variable('x');
      final f = x * const Sin(x);
      // f'(x) = sin(x) + x * cos(x)
      const pt = 1.0;
      final expected = math.sin(pt) + pt * math.cos(pt);
      check(numericalDerivative(f, pt, variable: 'x'))
          .isCloseTo(expected, 1e-6);
    });

    test('numerical gradient of 2D function', () {
      // f(x, y) = x^2 + 3*x*y + y^3
      // grad f = [2x + 3y, 3x + 3y^2]
      // At (1, 2): grad f = [2 + 6, 3 + 12] = [8, 15]
      double f(Vector<double> v) =>
          v[0] * v[0] + 3.0 * v[0] * v[1] + v[1] * v[1] * v[1];

      final pt = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
      final grad = numericalGradient(f, pt);
      check(grad[0]).isCloseTo(8.0, 1e-4);
      check(grad[1]).isCloseTo(15.0, 1e-4);
    });

    test('symbolic gradient and Hessian of Expr', () {
      const x = Variable('x');
      const y = Variable('y');
      // f(x, y) = x^2 + 3*x*y + y^2
      final f = x.pow(2) + const Constant(3.0) * x * y + y.pow(2);
      final pt = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);

      final grad = numericalGradient(f, pt, variables: ['x', 'y']);
      // grad = [2x + 3y, 3x + 2y] = [8, 7]
      check(grad[0]).isCloseTo(8.0, 1e-6);
      check(grad[1]).isCloseTo(7.0, 1e-6);

      final hess = numericalHessian(f, pt, variables: ['x', 'y']);
      // H = [[2, 3], [3, 2]]
      check(hess.get(0, 0)).isCloseTo(2.0, 1e-6);
      check(hess.get(0, 1)).isCloseTo(3.0, 1e-6);
      check(hess.get(1, 0)).isCloseTo(3.0, 1e-6);
      check(hess.get(1, 1)).isCloseTo(2.0, 1e-6);
    });

    test('Jacobian matrix of vector function', () {
      // f(x, y) = [x^2 + y, 5*x - y^2]
      // J = [[2x, 1], [5, -2y]]
      // At (2, 3): J = [[4, 1], [5, -6]]
      Vector<double> f(Vector<double> v) => Vector<double>.fromList([
        v[0] * v[0] + v[1],
        5.0 * v[0] - v[1] * v[1],
      ], type: DataType.float64);

      final pt = Vector<double>.fromList([2.0, 3.0], type: DataType.float64);
      final j = numericalJacobian(f, pt);
      check(j.get(0, 0)).isCloseTo(4.0, 1e-4);
      check(j.get(0, 1)).isCloseTo(1.0, 1e-4);
      check(j.get(1, 0)).isCloseTo(5.0, 1e-4);
      check(j.get(1, 1)).isCloseTo(-6.0, 1e-4);
    });
  });
}
