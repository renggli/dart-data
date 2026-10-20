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
  });
}
