import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('gradient', () {
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

    test(
      'scales finite-difference step size for large coordinates |x| >= 10^8',
      () {
        double function(Vector<double> v) => v[0] * v[0] + v[1] * v[1];

        final pt = Vector<double>.fromList([1e9, 2e9], type: DataType.float64);
        final grad = gradient(function, pt);
        // grad = [2e9, 4e9]
        check((grad[0] - 2e9).abs() / 2e9).isLessThan(1e-4);
        check((grad[1] - 4e9).abs() / 4e9).isLessThan(1e-4);
      },
    );
  });
}
