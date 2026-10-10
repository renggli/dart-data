import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/calculus.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Numerical & Symbolic Calculus', () {
    test('numerical derivative of scalar function', () {
      // f(x) = x^3 => f'(2) = 12
      double function(double x) => x * x * x;
      check(numericalDerivative(function, 2.0)).isCloseTo(12.0, 1e-5);
      check(numericalSecondDerivative(function, 2.0)).isCloseTo(12.0, 1e-3);

      num fNum(num x) => x * x * x;
      check(numericalDerivative(fNum, 2.0)).isCloseTo(12.0, 1e-5);
      check(numericalSecondDerivative(fNum, 2.0)).isCloseTo(12.0, 1e-3);

      check(() => numericalDerivative('invalid', 2.0)).throws<ArgumentError>();
      check(() => numericalSecondDerivative('invalid', 2.0))
          .throws<ArgumentError>();
    });

    test('derivative and second derivative of Expr symbolic AST', () {
      // f(x) = sin(x) * x
      const x = Variable('x');
      final expr = x * const Sin(x);
      // f'(x) = sin(x) + x * cos(x)
      const pt = 1.0;
      final expected = math.sin(pt) + pt * math.cos(pt);
      check(numericalDerivative(expr, pt, variable: 'x'))
          .isCloseTo(expected, 1e-6);

      // f''(x) = 2*cos(x) - x*sin(x)
      final expectedSecond = 2.0 * math.cos(pt) - pt * math.sin(pt);
      check(numericalSecondDerivative(expr, pt, variable: 'x'))
          .isCloseTo(expectedSecond, 1e-6);
    });

    test('numerical gradient of 2D function', () {
      // f(x, y) = x^2 + 3*x*y + y^3
      // grad f = [2x + 3y, 3x + 3y^2]
      // At (1, 2): grad f = [2 + 6, 3 + 12] = [8, 15]
      double function(Vector<double> vec) =>
          vec[0] * vec[0] + 3.0 * vec[0] * vec[1] + vec[1] * vec[1] * vec[1];

      final pt = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
      final grad = numericalGradient(function, pt);
      check(grad[0]).isCloseTo(8.0, 1e-4);
      check(grad[1]).isCloseTo(15.0, 1e-4);

      check(() => numericalGradient('invalid', pt)).throws<ArgumentError>();
    });

    test('symbolic gradient and Hessian of Expr', () {
      const x = Variable('x');
      const y = Variable('y');
      // f(x, y) = x^2 + 3*x*y + y^2
      final expr = x.pow(2) + const Constant(3.0) * x * y + y.pow(2);
      final pt = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);

      final grad = numericalGradient(expr, pt, variables: ['x', 'y']);
      // grad = [2x + 3y, 3x + 2y] = [8, 7]
      check(grad[0]).isCloseTo(8.0, 1e-6);
      check(grad[1]).isCloseTo(7.0, 1e-6);

      final hess = numericalHessian(expr, pt, variables: ['x', 'y']);
      // H = [[2, 3], [3, 2]]
      check(hess.get(0, 0)).isCloseTo(2.0, 1e-6);
      check(hess.get(0, 1)).isCloseTo(3.0, 1e-6);
      check(hess.get(1, 0)).isCloseTo(3.0, 1e-6);
      check(hess.get(1, 1)).isCloseTo(2.0, 1e-6);

      // Default variables inference
      final gradAuto = numericalGradient(expr, pt);
      check(gradAuto.length).equals(2);

      // Dimension mismatch
      check(() => numericalGradient(expr, pt, variables: ['x']))
          .throws<ArgumentError>();
      check(() => numericalHessian(expr, pt, variables: ['x']))
          .throws<ArgumentError>();
      check(() => numericalHessian('invalid', pt)).throws<ArgumentError>();
    });

    test('numerical Hessian of closure', () {
      // f(x, y) = x^2 + 3*x*y + y^2
      double function(Vector<double> vec) =>
          vec[0] * vec[0] + 3.0 * vec[0] * vec[1] + vec[1] * vec[1];

      final pt = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
      final hessian = numericalHessian(function, pt);
      check(hessian.get(0, 0)).isCloseTo(2.0, 1e-3);
      check(hessian.get(0, 1)).isCloseTo(3.0, 1e-3);
      check(hessian.get(1, 0)).isCloseTo(3.0, 1e-3);
      check(hessian.get(1, 1)).isCloseTo(2.0, 1e-3);
    });

    test('Jacobian matrix of vector function and Expr list', () {
      // f(x, y) = [x^2 + y, 5*x - y^2]
      // J = [[2x, 1], [5, -2y]]
      // At (2, 3): J = [[4, 1], [5, -6]]
      Vector<double> function(Vector<double> vec) => Vector<double>.fromList([
        vec[0] * vec[0] + vec[1],
        5.0 * vec[0] - vec[1] * vec[1],
      ], type: DataType.float64);

      final pt = Vector<double>.fromList([2.0, 3.0], type: DataType.float64);
      final jacobian = numericalJacobian(function, pt);
      check(jacobian.get(0, 0)).isCloseTo(4.0, 1e-4);
      check(jacobian.get(0, 1)).isCloseTo(1.0, 1e-4);
      check(jacobian.get(1, 0)).isCloseTo(5.0, 1e-4);
      check(jacobian.get(1, 1)).isCloseTo(-6.0, 1e-4);

      // Symbolic Expr list
      const x = Variable('x');
      const y = Variable('y');
      final exprs = [x.pow(2) + y, const Constant(5.0) * x - y.pow(2)];
      final jSym = numericalJacobian(exprs, pt, variables: ['x', 'y']);
      check(jSym.get(0, 0)).isCloseTo(4.0, 1e-6);
      check(jSym.get(0, 1)).isCloseTo(1.0, 1e-6);
      check(jSym.get(1, 0)).isCloseTo(5.0, 1e-6);
      check(jSym.get(1, 1)).isCloseTo(-6.0, 1e-6);

      // Auto variables inference
      final jAuto = numericalJacobian(exprs, pt);
      check(jAuto.rowCount).equals(2);

      check(() => numericalJacobian(exprs, pt, variables: ['x']))
          .throws<ArgumentError>();
      check(() => numericalJacobian('invalid', pt)).throws<ArgumentError>();
    });
  });
}
