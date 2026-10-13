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
      check(h.rowCount).equals(2);
      check(h.colCount).equals(2);
      check(h[0].length).equals(2);
      check(h[1].length).equals(2);

      // Clairaut's theorem: exact reference identity on mixed partials
      check(identical(h[0][1], h[1][0])).isTrue();

      // d^2/dx^2 = 2
      check(h[0][0].evaluate({'x': 1.0, 'y': 2.0})).equals(2.0);
      // d^2/dxdy = 3
      check(h[0][1].evaluate({'x': 1.0, 'y': 2.0})).equals(3.0);
      // d^2/dydx = 3 (Schwarz's theorem: symmetric)
      check(h[1][0].evaluate({'x': 1.0, 'y': 2.0})).equals(3.0);
      // d^2/dy^2 = 6y -> at y = 2: 12.0
      check(h[1][1].evaluate({'x': 1.0, 'y': 2.0})).equals(12.0);
    });

    test('3-variable Clairaut symmetry and reference identity', () {
      const z = Variable('z');
      // f = x^3 * y + y^3 * z + z^3 * x + x * y * z
      final f = x.pow(3) * y + y.pow(3) * z + z.pow(3) * x + x * y * z;
      final h = f.hessian(['x', 'y', 'z']);
      check(h.rowCount).equals(3);
      check(h.colCount).equals(3);

      check(identical(h[0][1], h[1][0])).isTrue();
      check(identical(h[0][2], h[2][0])).isTrue();
      check(identical(h[1][2], h[2][1])).isTrue();
    });

    test('empty variables list produces empty vector and matrix', () {
      final f = x * x + y * y;
      final grad = f.gradient([]);
      check(grad.length).equals(0);

      final h = f.hessian([]);
      check(h.rowCount).equals(0);
      check(h.colCount).equals(0);
    });
  });

  group('MultivariableIterableExtension - jacobian', () {
    test('computes Jacobian matrix of vector-valued function', () {
      // F(x, y) = [x * y, x + y]
      // J = [[y, x], [1, 1]]
      final system = [x * y, x + y];
      final jac = system.jacobian(['x', 'y']);
      check(jac.rowCount).equals(2);
      check(jac.colCount).equals(2);
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
      check(jac.rowCount).equals(3);
      check(jac.colCount).equals(2);
      for (var r = 0; r < jac.rowCount; r++) {
        check(jac[r].length).equals(2);
      }
      check(jac[0][0].evaluate({'x': 2.0})).equals(4.0);
      check(jac[0][1]).equals(RationalNumber.zero);
      check(jac[1][0]).equals(RationalNumber.zero);
      check(jac[1][1].evaluate({'y': 3.0})).equals(6.0);
      check(jac[2][0].evaluate({'y': 4.0})).equals(4.0);
      check(jac[2][1].evaluate({'x': 5.0})).equals(5.0);
    });

    test('adversarial Jacobian shapes: empty, tall, and wide dimensions', () {
      // Empty system with variables: 0 x 3
      final emptySystem = <Expr>[];
      final jEmptySys = emptySystem.jacobian(['x', 'y', 'z']);
      check(jEmptySys.rowCount).equals(0);
      check(jEmptySys.colCount).equals(3);
      check(jEmptySys.type).equals(exprDataType);

      // System with empty variables: 3 x 0
      final jEmptyVars = [x, y, z].jacobian([]);
      check(jEmptyVars.rowCount).equals(3);
      check(jEmptyVars.colCount).equals(0);
      check(jEmptyVars.type).equals(exprDataType);

      // Both empty: 0 x 0
      final jEmptyAll = <Expr>[].jacobian([]);
      check(jEmptyAll.rowCount).equals(0);
      check(jEmptyAll.colCount).equals(0);
      check(jEmptyAll.type).equals(exprDataType);

      // Tall: 4 x 1
      final jTall = [x, x.pow(2), x.pow(3), const Sin(x)].jacobian(['x']);
      check(jTall.rowCount).equals(4);
      check(jTall.colCount).equals(1);
      check(jTall.type).equals(exprDataType);
      check(jTall[0][0]).equals(RationalNumber.one);
      check(jTall[1][0]).equals(const RationalNumber(2) * x);
      check(jTall[2][0]).equals(const RationalNumber(3) * x.pow(2));
      check(jTall[3][0]).equals(const Cos(x));

      // Wide: 1 x 4
      const w = Variable('w');
      final jWide = [x * y * z * w].jacobian(['x', 'y', 'z', 'w']);
      check(jWide.rowCount).equals(1);
      check(jWide.colCount).equals(4);
      check(jWide.type).equals(exprDataType);
      check(jWide[0][0]).equals(y * z * w);
      check(jWide[0][1]).equals(x * z * w);
      check(jWide[0][2]).equals(x * y * w);
      check(jWide[0][3]).equals(x * y * z);
    });
  });

  group('Adversarial Clairaut symmetry & memory identity stress tests', () {
    const w = Variable('w');
    const u = Variable('u');

    test('4-variable transcendental Hessian exact reference identity across all 6 pairs', () {
      // Non-trivial transcendental multivariable function:
      // f(x, y, z, w) = sin(x*y)*cos(z*w) + exp(x + y + z + w) + x^3*y^2*z*w + (x*y)/(z + w + 1)
      final f =
          Sin(x * y) * Cos(z * w) +
          Exp(x + y + z + w) +
          (x.pow(3) * y.pow(2) * z * w) +
          ((x * y) / (z + w + 1));

      final vars = ['x', 'y', 'z', 'w'];
      final h = f.hessian(vars);

      check(h.rowCount).equals(4);
      check(h.colCount).equals(4);
      check(h.type).equals(exprDataType);

      // Verify all 6 pairs of off-diagonal elements in the 4x4 matrix
      final pairs = [
        (0, 1), // (x, y)
        (0, 2), // (x, z)
        (0, 3), // (x, w)
        (1, 2), // (y, z)
        (1, 3), // (y, w)
        (2, 3), // (z, w)
      ];

      for (final (i, j) in pairs) {
        // 1. Exact heap object identity via indexer [r][c]
        check(identical(h[i][j], h[j][i])).isTrue();

        // 2. Exact heap object identity via matrix.get(r, c)
        check(identical(h.get(i, j), h.get(j, i))).isTrue();

        // 3. Exact heap object identity via matrix.getUnchecked(r, c)
        check(identical(h.getUnchecked(i, j), h.getUnchecked(j, i))).isTrue();

        // 4. Value equality
        check(h[i][j]).equals(h[j][i]);
      }

      // Check numerical evaluation consistency at sample point
      final point = {'x': 0.5, 'y': 0.8, 'z': 0.3, 'w': 0.2};
      for (final (i, j) in pairs) {
        final valIJ = h[i][j].evaluate(point);
        final valJI = h[j][i].evaluate(point);
        check(valIJ).equals(valJI);
      }
    });

    test('5-variable polynomial Hessian exact reference identity across all 10 pairs', () {
      // f(x, y, z, w, u) = x*y^2*z^3*w^4*u^5 + (x + y + z + w + u)^3
      final sum = x + y + z + w + u;
      final f = (x * y.pow(2) * z.pow(3) * w.pow(4) * u.pow(5)) + sum.pow(3);

      final vars = ['x', 'y', 'z', 'w', 'u'];
      final h = f.hessian(vars);

      check(h.rowCount).equals(5);
      check(h.colCount).equals(5);

      var pairCount = 0;
      for (var i = 0; i < 5; i++) {
        for (var j = i + 1; j < 5; j++) {
          check(identical(h[i][j], h[j][i])).isTrue();
          check(h[i][j]).equals(h[j][i]);
          pairCount++;
        }
      }
      check(pairCount).equals(10);
    });

    test('gradient return type and shape contracts', () {
      final f = x.pow(2) + y.pow(2) + z.pow(2) + w.pow(2);

      // 4 variables
      final grad4 = f.gradient(['x', 'y', 'z', 'w']);
      check(grad4.length).equals(4);
      check(grad4.type).equals(exprDataType);
      check(grad4[0]).equals(const RationalNumber(2) * x);
      check(grad4[1]).equals(const RationalNumber(2) * y);
      check(grad4[2]).equals(const RationalNumber(2) * z);
      check(grad4[3]).equals(const RationalNumber(2) * w);

      // 1 variable
      final grad1 = f.gradient(['x']);
      check(grad1.length).equals(1);
      check(grad1.type).equals(exprDataType);
      check(grad1[0]).equals(const RationalNumber(2) * x);

      // 0 variables
      final grad0 = f.gradient([]);
      check(grad0.length).equals(0);
      check(grad0.type).equals(exprDataType);
    });
  });
}
