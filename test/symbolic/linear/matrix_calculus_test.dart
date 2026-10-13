import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const t = Variable('t');

  group('SymbolicMatrixExtension derivative', () {
    test('element-wise partial derivative of square matrix', () {
      final m = Matrix<Expr>.fromRows([
        [x.pow(2), const Sin(x)],
        [const RationalNumber(3) * x, const Exp(x)],
      ], type: exprDataType);

      final dm = m.derivative('x');
      check(dm.rowCount).equals(2);
      check(dm.colCount).equals(2);

      check(dm[0][0]).equals(const RationalNumber(2) * x);
      check(dm[0][1]).equals(const Cos(x));
      check(dm[1][0]).equals(const RationalNumber(3));
      check(dm[1][1]).equals(const Exp(x));
    });

    test('rectangular matrix dimension preservation', () {
      // 2x3 matrix
      final rect = Matrix<Expr>.fromRows([
        [x.pow(3), x * y, const Ln(x)],
        [const RationalNumber(4), y.pow(2), const Cos(x)],
      ], type: exprDataType);

      final dmDx = rect.derivative('x');
      check(dmDx.rowCount).equals(2);
      check(dmDx.colCount).equals(3);

      check(dmDx[0][0]).equals(const RationalNumber(3) * x.pow(2));
      check(dmDx[0][1]).equals(y);
      check(dmDx[0][2]).equals(RationalNumber.one / x);
      check(dmDx[1][0]).equals(RationalNumber.zero);
      check(dmDx[1][1]).equals(RationalNumber.zero);
      check(dmDx[1][2]).equals(-const Sin(x));

      final dmDy = rect.derivative('y');
      check(dmDy[0][0]).equals(RationalNumber.zero);
      check(dmDy[0][1]).equals(x);
      check(dmDy[0][2]).equals(RationalNumber.zero);
      check(dmDy[1][0]).equals(RationalNumber.zero);
      check(dmDy[1][1]).equals(const RationalNumber(2) * y);
      check(dmDy[1][2]).equals(RationalNumber.zero);
    });

    test('derivative of independent variable produces zero matrix', () {
      final m = Matrix<Expr>.fromRows([
        [x, x.pow(2)],
        [const RationalNumber(3), const Sin(x)],
      ], type: exprDataType);

      final dmDz = m.derivative('z');
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          check(dmDz[r][c]).equals(RationalNumber.zero);
        }
      }
    });

    test('second-order matrix derivative', () {
      final m = Matrix<Expr>.fromRows([
        [x.pow(4), const Sin(x)],
        [const Exp(x), const RationalNumber(7)],
      ], type: exprDataType);

      final d2m = m.derivative('x').derivative('x');
      check(d2m[0][0]).equals(const RationalNumber(12) * x.pow(2));
      check(d2m[0][1]).equals(-const Sin(x));
      check(d2m[1][0]).equals(const Exp(x));
      check(d2m[1][1]).equals(RationalNumber.zero);
    });
  });

  group('SymbolicVectorExtension derivative', () {
    test('element-wise vector derivative', () {
      final v = Vector<Expr>.fromList([
        x.pow(3),
        const Cos(x),
        Exp(const RationalNumber(2) * x),
      ], type: exprDataType);

      final dv = v.derivative('x');
      check(dv.length).equals(3);

      check(dv[0]).equals(const RationalNumber(3) * x.pow(2));
      check(dv[1]).equals(-const Sin(x));
      check(dv[2])
          .equals(const RationalNumber(2) * Exp(const RationalNumber(2) * x));
    });

    test('vector derivative of independent variable produces zero vector', () {
      final v = Vector<Expr>.fromList([
        x,
        x.pow(2),
        const Sin(x),
      ], type: exprDataType);
      final dvDy = v.derivative('y');
      for (var i = 0; i < 3; i++) {
        check(dvDy[i]).equals(RationalNumber.zero);
      }
    });
  });

  group('Matrix calculus identities', () {
    test(
      'Product rule: d/dt (A(t) * B(t)) = A\'(t) * B(t) + A(t) * B\'(t)',
      () {
        // A(t) = [[t, 1], [0, t^2]]
        final aMat = Matrix<Expr>.fromRows([
          [t, RationalNumber.one],
          [RationalNumber.zero, t.pow(2)],
        ], type: exprDataType);

        // B(t) = [[t^3, 2], [t, 1]]
        final bMat = Matrix<Expr>.fromRows([
          [t.pow(3), const RationalNumber(2)],
          [t, RationalNumber.one],
        ], type: exprDataType);

        // Direct product derivative: (A * B)'
        final prod = aMat * bMat;
        final dProd = prod.derivative('t');

        // Product rule terms: A' * B + A * B'
        final daMat = aMat.derivative('t');
        final dbMat = bMat.derivative('t');
        final term1 = daMat * bMat;
        final term2 = aMat * dbMat;

        for (var r = 0; r < 2; r++) {
          for (var c = 0; c < 2; c++) {
            final lhs = dProd[r][c].expand().simplify();
            final rhs = (term1[r][c] + term2[r][c]).expand().simplify();
            check(lhs).equals(rhs);
          }
        }
      },
    );

    test('Jacobi formula: d/dt det(X(t)) = tr(adj(X(t)) * X\'(t))', () {
      // X(t) = [[t^2, t], [1, t^3]]
      final xMat = Matrix<Expr>.fromRows([
        [t.pow(2), t],
        [RationalNumber.one, t.pow(3)],
      ], type: exprDataType);

      // det(X(t)) = t^5 - t
      final detX = xMat.determinant();
      final dDetX = detX.derivative('t').simplify();
      check(dDetX).equals((const RationalNumber(5) * t.pow(4)) - 1);

      // adj(X(t)) = [[t^3, -t], [-1, t^2]]
      final adjX = Matrix<Expr>.fromRows([
        [t.pow(3), -t],
        [RationalNumber.negativeOne, t.pow(2)],
      ], type: exprDataType);

      final dxMat = xMat.derivative('t');
      final inner = adjX * dxMat;
      final jacobiRhs = inner.trace.expand().simplify();

      check(dDetX).equals(jacobiRhs);
    });

    test('Rectangular matrix product rule: 2x3 and 3x2 matrices', () {
      // A(t) is 2x3
      final aMat = Matrix<Expr>.fromRows([
        [t.pow(2), t, RationalNumber.one],
        [RationalNumber.zero, const Sin(t), t.pow(3)],
      ], type: exprDataType);

      // B(t) is 3x2
      final bMat = Matrix<Expr>.fromRows([
        [const Exp(t), RationalNumber.one],
        [t, const Cos(t)],
        [const RationalNumber(2), t.pow(2)],
      ], type: exprDataType);

      // (A * B)'
      final prod = aMat * bMat;
      final dProd = prod.derivative('t');

      // A' * B + A * B'
      final daMat = aMat.derivative('t');
      final dbMat = bMat.derivative('t');
      final rhs = (daMat * bMat) + (aMat * dbMat);

      check(dProd.rowCount).equals(2);
      check(dProd.colCount).equals(2);

      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          final lhsVal = dProd[r][c].expand().simplify();
          final rhsVal = rhs[r][c].expand().simplify();
          check(lhsVal).equals(rhsVal);
        }
      }
    });

    test('Second-order matrix product rule: (A * B)\'\' = A\'\'*B + 2*A\'*B\' + A*B\'\'', () {
      final aMat = Matrix<Expr>.fromRows([
        [t.pow(3), RationalNumber.one],
        [t, t.pow(2)],
      ], type: exprDataType);

      final bMat = Matrix<Expr>.fromRows([
        [t.pow(2), t],
        [const RationalNumber(3), t.pow(4)],
      ], type: exprDataType);

      // LHS: (A * B)''
      final d2Lhs = (aMat * bMat).derivative('t').derivative('t');

      // RHS: A'' * B + 2 * A' * B' + A * B''
      final da = aMat.derivative('t');
      final d2a = da.derivative('t');
      final db = bMat.derivative('t');
      final d2b = db.derivative('t');

      final term1 = d2a * bMat;
      final dadb = da * db;
      final term2 = Matrix<Expr>.generate(
        2,
        2,
        (r, c) => (const RationalNumber(2) * dadb[r][c]).expand().simplify(),
        type: exprDataType,
      );
      final term3 = aMat * d2b;
      final rhs = (term1 + term2) + term3;

      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          final lVal = d2Lhs[r][c].expand().simplify();
          final rVal = rhs[r][c].expand().simplify();
          check(lVal).equals(rVal);
        }
      }
    });

    test(
      'Three-matrix product rule: (A * B * C)\' = A\'*B*C + A*B\'*C + A*B*C\'',
      () {
        final a = Matrix<Expr>.fromRows([
          [t, RationalNumber.one],
          [RationalNumber.zero, t],
        ], type: exprDataType);

        final b = Matrix<Expr>.fromRows([
          [RationalNumber.one, t],
          [t, RationalNumber.zero],
        ], type: exprDataType);

        final c = Matrix<Expr>.fromRows([
          [t.pow(2), RationalNumber.one],
          [RationalNumber.one, t],
        ], type: exprDataType);

        // (A * B * C)'
        final dLhs = ((a * b) * c).derivative('t');

        // A' * B * C + A * B' * C + A * B * C'
        final da = a.derivative('t');
        final db = b.derivative('t');
        final dc = c.derivative('t');

        final term1 = (da * b) * c;
        final term2 = (a * db) * c;
        final term3 = (a * b) * dc;
        final rhs = (term1 + term2) + term3;

        for (var r = 0; r < 2; r++) {
          for (var col = 0; col < 2; col++) {
            final lVal = dLhs[r][col].expand().simplify();
            final rVal = rhs[r][col].expand().simplify();
            check(lVal).equals(rVal);
          }
        }
      },
    );

    test(
      'Jacobi formula for 2x2 rotation matrix with trigonometric entries',
      () {
        // Rotation matrix X(t) = [[cos(t), -sin(t)], [sin(t), cos(t)]]
        // det(X(t)) = cos^2(t) + sin^2(t) = 1 => d/dt det(X(t)) = 0
        final rot = Matrix<Expr>.fromRows([
          [const Cos(t), -const Sin(t)],
          [const Sin(t), const Cos(t)],
        ], type: exprDataType);

        final detRot = rot.determinant();
        final dDetRot = detRot.derivative('t').simplify();
        check(dDetRot).equals(RationalNumber.zero);

        // adj(rot) = [[cos(t), sin(t)], [-sin(t), cos(t)]]
        final adjRot = Matrix<Expr>.fromRows([
          [const Cos(t), const Sin(t)],
          [-const Sin(t), const Cos(t)],
        ], type: exprDataType);

        final dRot = rot.derivative('t');
        final inner = adjRot * dRot;
        final jacobiRhs = inner.trace.expand().simplify();
        check(jacobiRhs).equals(RationalNumber.zero);
        check(dDetRot).equals(jacobiRhs);
      },
    );

    test(
      'Jacobi formula for 3x3 matrix using Faddeev-LeVerrier adjugate B_2',
      () {
        // X(t) = [[t, 1, 0], [0, t^2, t], [1, 0, t]]
        final xMat = Matrix<Expr>.fromRows([
          [t, RationalNumber.one, RationalNumber.zero],
          [RationalNumber.zero, t.pow(2), t],
          [RationalNumber.one, RationalNumber.zero, t],
        ], type: exprDataType);

        // det(X(t))
        final detX = xMat.determinant();
        final dDetX = detX.derivative('t').expand().simplify();

        // In Faddeev-LeVerrier for 3x3 matrix, B_2 is exactly the adjugate matrix adj(X)!
        final flResult = const FaddeevLeVerrierEngine().compute(xMat);
        final adjX = flResult.bMatrices.last; // B_{n-1} = B_2

        final dxMat = xMat.derivative('t');
        final inner = adjX * dxMat;
        final jacobiRhs = inner.trace.expand().simplify();

        check(dDetX).equals(jacobiRhs);
      },
    );
  });
}
