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

    test(
      'exploits symmetry to evaluate off-diagonal entries once per pair',
      () {
        var evalCount = 0;
        double function(Vector<double> v) {
          evalCount++;
          return v[0] * v[1] + v[1] * v[2] + v[0] * v[2];
        }

        // dim = 3: 3 diagonal entries (2 evals each = 6) + 3 off-diagonal pairs (4 evals each = 12) + f0 (1 eval) = 19
        final pt = Vector<double>.fromList([
          1.0,
          2.0,
          3.0,
        ], type: DataType.float64);
        final h = hessian(function, pt);
        check(h.rowCount).equals(3);
        check(h.colCount).equals(3);
        check(evalCount).equals(19);
      },
    );

    test(
      'scales finite-difference step size for large coordinates |x| >= 10^8',
      () {
        double function(Vector<double> v) => v[0] * v[0] * v[0];

        final pt = Vector<double>.fromList([1e8], type: DataType.float64);
        final h = hessian(function, pt);
        // d^2/dx^2 (x^3) at x = 1e8 is 6 * 1e8 = 6e8
        check((h.get(0, 0) - 6e8).abs() / 6e8).isLessThan(1e-3);
      },
    );
  });
}
