import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/calculus.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Canonical Numerical Calculus', () {
    test('derivative and higher order derivative of scalar function', () {
      // f(x) = x^3 => f'(2) = 12, f''(2) = 12
      double function(double x) => x * x * x;
      check(derivative(function, 2.0)).isCloseTo(12.0, 1e-4);
      check(derivative(function, 2.0, order: 2)).isCloseTo(12.0, 1e-3);
      check(derivative(function, 2.0, accuracy: 4)).isCloseTo(12.0, 1e-6);
      check(derivative(function, 2.0, order: 2, accuracy: 4))
          .isCloseTo(12.0, 1e-4);

      check(() => derivative(function, 2.0, order: 3)).throws<ArgumentError>();
    });

    test('gradient of 2D function', () {
      // f(x, y) = x^2 + 3*x*y + y^3
      // grad f = [2x + 3y, 3x + 3y^2]
      // At (1, 2): grad f = [2 + 6, 3 + 12] = [8, 15]
      double function(Vector<double> vec) =>
          vec[0] * vec[0] + 3.0 * vec[0] * vec[1] + vec[1] * vec[1] * vec[1];

      final pt = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
      final grad = gradient(function, pt);
      check(grad[0]).isCloseTo(8.0, 1e-4);
      check(grad[1]).isCloseTo(15.0, 1e-4);
    });

    test('Hessian of 2D function', () {
      // f(x, y) = x^2 + 3*x*y + y^2
      double function(Vector<double> vec) =>
          vec[0] * vec[0] + 3.0 * vec[0] * vec[1] + vec[1] * vec[1];

      final pt = Vector<double>.fromList([1.0, 2.0], type: DataType.float64);
      final h = hessian(function, pt);
      check(h.get(0, 0)).isCloseTo(2.0, 1e-3);
      check(h.get(0, 1)).isCloseTo(3.0, 1e-3);
      check(h.get(1, 0)).isCloseTo(3.0, 1e-3);
      check(h.get(1, 1)).isCloseTo(2.0, 1e-3);
    });

    test('Jacobian matrix of vector function', () {
      // f(x, y) = [x^2 + y, 5*x - y^2]
      // J = [[2x, 1], [5, -2y]]
      // At (2, 3): J = [[4, 1], [5, -6]]
      Vector<double> function(Vector<double> vec) => Vector<double>.fromList([
        vec[0] * vec[0] + vec[1],
        5.0 * vec[0] - vec[1] * vec[1],
      ], type: DataType.float64);

      final pt = Vector<double>.fromList([2.0, 3.0], type: DataType.float64);
      final jac = jacobian(function, pt);
      check(jac.get(0, 0)).isCloseTo(4.0, 1e-4);
      check(jac.get(0, 1)).isCloseTo(1.0, 1e-4);
      check(jac.get(1, 0)).isCloseTo(5.0, 1e-4);
      check(jac.get(1, 1)).isCloseTo(-6.0, 1e-4);
    });
  });
}
