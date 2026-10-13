import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  group('MultivariableExtension - gradient', () {
    test('computes gradient covector', () {
      // f(x, y) = x^2 + y^2 -> [2x, 2y]
      final f1 = x * x + y * y;
      final grad1 = f1.gradient(['x', 'y']);
      check(grad1.length).equals(2);
      check(grad1[0].evaluate({'x': 3.0, 'y': 4.0})).equals(6.0);
      check(grad1[1].evaluate({'x': 3.0, 'y': 4.0})).equals(8.0);

      // f(x, y, z) = x * y * z -> [y * z, x * z, x * y]
      final f2 = x * y * z;
      final grad2 = f2.gradient(['x', 'y', 'z']);
      check(grad2.length).equals(3);
      check(grad2[0].evaluate({'x': 2.0, 'y': 3.0, 'z': 4.0})).equals(12.0);
      check(grad2[1].evaluate({'x': 2.0, 'y': 3.0, 'z': 4.0})).equals(8.0);
      check(grad2[2].evaluate({'x': 2.0, 'y': 3.0, 'z': 4.0})).equals(6.0);
    });

    test('gradient of independent variable is zero', () {
      final f = x * x;
      final grad = f.gradient(['x', 'y']);
      check(grad[0].evaluate({'x': 3.0})).equals(6.0);
      check(grad[1]).equals(RationalNumber.zero);
    });
  });

  group('MultivariableExtension - hessian', () {
    test('computes symmetric Hessian matrix', () {
      // f(x, y) = x^2 + 3 * x * y + y^3
      final f = x * x + (const RationalNumber(3) * (x * y)) + y.pow(3);
      final h = f.hessian(['x', 'y']);
      check(h.length).equals(2);
      check(h[0].length).equals(2);
      check(h[1].length).equals(2);

      // d^2/dx^2 = 2
      check(h[0][0].evaluate({'x': 1.0, 'y': 2.0})).equals(2.0);
      // d^2/dxdy = 3
      check(h[0][1].evaluate({'x': 1.0, 'y': 2.0})).equals(3.0);
      // d^2/dydx = 3 (Schwarz's theorem: symmetric)
      check(h[1][0].evaluate({'x': 1.0, 'y': 2.0})).equals(3.0);
      // d^2/dy^2 = 6y -> at y = 2: 12.0
      check(h[1][1].evaluate({'x': 1.0, 'y': 2.0})).equals(12.0);
    });
  });

  group('MultivariableIterableExtension - jacobian', () {
    test('computes Jacobian matrix of vector-valued function', () {
      // F(x, y) = [x * y, x + y]
      // J = [[y, x], [1, 1]]
      final system = [x * y, x + y];
      final jac = system.jacobian(['x', 'y']);
      check(jac.length).equals(2);
      check(jac[0].length).equals(2);
      check(jac[1].length).equals(2);

      check(jac[0][0].evaluate({'y': 5.0})).equals(5.0);
      check(jac[0][1].evaluate({'x': 3.0})).equals(3.0);
      check(jac[1][0]).equals(RationalNumber.one);
      check(jac[1][1]).equals(RationalNumber.one);
    });

    test('rectangular Jacobian matrix (m != n)', () {
      // 3 outputs, 2 inputs
      final system = [x * x, y * y, x * y];
      final jac = system.jacobian(['x', 'y']);
      check(jac.length).equals(3);
      for (final row in jac) {
        check(row.length).equals(2);
      }
      check(jac[0][0].evaluate({'x': 2.0})).equals(4.0);
      check(jac[0][1]).equals(RationalNumber.zero);
      check(jac[1][0]).equals(RationalNumber.zero);
      check(jac[1][1].evaluate({'y': 3.0})).equals(6.0);
      check(jac[2][0].evaluate({'y': 4.0})).equals(4.0);
      check(jac[2][1].evaluate({'x': 5.0})).equals(5.0);
    });
  });
}
