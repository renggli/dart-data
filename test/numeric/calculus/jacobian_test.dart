import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('jacobian', () {
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

    test('O(n) vector evaluations independent of output dimension m', () {
      var evalCount = 0;
      // n = 3 inputs, m = 10 outputs
      Vector<double> function(Vector<double> v) {
        evalCount++;
        return Vector<double>.generate(
          10,
          (i) => (i + 1) * v[0] + v[1] * v[2],
          type: DataType.float64,
        );
      }

      final pt = Vector<double>.fromList([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float64);
      final jac = jacobian(function, pt);
      check(jac.rowCount).equals(10);
      check(jac.colCount).equals(3);
      // Exactly 1 (initial f0) + 2 * n (3 inputs) = 7 evaluations
      check(evalCount).equals(7);
    });

    test(
      'scales finite-difference step size for large coordinates |x| >= 10^8',
      () {
        Vector<double> function(Vector<double> v) =>
            Vector<double>.fromList([v[0] * v[0]], type: DataType.float64);

        final pt = Vector<double>.fromList([1e9], type: DataType.float64);
        final jac = jacobian(function, pt);
        // d/dx(x^2) at x = 1e9 is 2e9
        check((jac.get(0, 0) - 2e9).abs() / 2e9).isLessThan(1e-4);
      },
    );
  });
}
