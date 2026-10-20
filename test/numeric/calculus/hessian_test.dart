import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('hessian', () {
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
  });
}
