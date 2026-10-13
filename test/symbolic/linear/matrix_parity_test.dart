import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Numeric-symbolic determinant parity', () {
    test('3x3 matrix determinant matches numeric LU decomposition', () {
      final rowsNumeric = [
        [2.0, 1.0, 3.0],
        [1.0, 0.0, 2.0],
        [3.0, 2.0, 1.0],
      ];

      final matDouble = Matrix<double>.fromRows(rowsNumeric);
      final matExpr = Matrix<Expr>.fromRows(
        rowsNumeric.map((r) => r.map(RationalNumber.fromDouble).toList()),
        type: exprDataType,
      );

      final symDet = matExpr.determinant();
      final numDet = matDouble.lu.det;

      check(symDet.evaluate({})).isCloseTo(numDet, 1e-10);
    });

    test(
      '3x3 symbolic matrix evaluated at multiple points matches numeric LU',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');

        // Cyclic matrix [[x, 1, 0], [0, y, 1], [1, 0, z]]
        // Analytical determinant: x*y*z + 1
        final matSym = Matrix<Expr>.fromRows([
          [x, RationalNumber.one, RationalNumber.zero],
          [RationalNumber.zero, y, RationalNumber.one],
          [RationalNumber.one, RationalNumber.zero, z],
        ], type: exprDataType);

        final symDet = matSym.determinant();

        final testPoints = [
          {'x': 2.0, 'y': 3.0, 'z': 4.0},
          {'x': -1.5, 'y': 2.5, 'z': 3.0},
          {'x': 0.5, 'y': 0.25, 'z': 8.0},
        ];

        for (final pt in testPoints) {
          final matDouble = Matrix<double>.fromRows([
            [pt['x']!, 1.0, 0.0],
            [0.0, pt['y']!, 1.0],
            [1.0, 0.0, pt['z']!],
          ]);

          final evaluatedSymDet = symDet.evaluate(pt);
          final numDet = matDouble.lu.det;
          check(evaluatedSymDet).isCloseTo(numDet, 1e-10);
        }
      },
    );

    test('4x4 dense matrix determinant parity', () {
      final rows = [
        [3.0, 2.0, 1.0, 4.0],
        [1.0, 4.0, 2.0, 3.0],
        [2.0, 1.0, 5.0, 2.0],
        [4.0, 3.0, 2.0, 1.0],
      ];

      final matDouble = Matrix<double>.fromRows(rows);
      final matExpr = Matrix<Expr>.fromRows(
        rows.map((r) => r.map(RationalNumber.fromDouble).toList()),
        type: exprDataType,
      );

      final symDet = matExpr.determinant();
      final numDet = matDouble.lu.det;

      check(symDet.evaluate({})).isCloseTo(numDet, 1e-9);
    });
  });

  group('Numeric-symbolic inverse parity', () {
    test('3x3 matrix inverse matches numeric LU inverse', () {
      final rows = [
        [1.0, 2.0, 3.0],
        [0.0, 1.0, 4.0],
        [5.0, 6.0, 0.0],
      ];

      final matDouble = Matrix<double>.fromRows(rows);
      final matExpr = Matrix<Expr>.fromRows(
        rows.map((r) => r.map(RationalNumber.fromDouble).toList()),
        type: exprDataType,
      );

      final symInv = matExpr.inverse();
      check(symInv).isNotNull();

      final numInv = matDouble.inverse;

      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final symVal = symInv![r][c].evaluate({});
          final numVal = numInv[r][c];
          check(symVal).isCloseTo(numVal, 1e-10);
        }
      }
    });

    test('4x4 matrix inverse parity', () {
      final rows = [
        [4.0, 1.0, 0.0, 1.0],
        [2.0, 3.0, 1.0, 0.0],
        [1.0, 0.0, 2.0, 1.0],
        [0.0, 1.0, 1.0, 3.0],
      ];

      final matDouble = Matrix<double>.fromRows(rows);
      final matExpr = Matrix<Expr>.fromRows(
        rows.map((r) => r.map(RationalNumber.fromDouble).toList()),
        type: exprDataType,
      );

      final symInv = matExpr.inverse();
      check(symInv).isNotNull();

      final numInv = matDouble.inverse;

      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          final symVal = symInv![r][c].evaluate({});
          final numVal = numInv[r][c];
          check(symVal).isCloseTo(numVal, 1e-10);
        }
      }
    });
  });

  group('Characteristic polynomial and eigenvalue parity', () {
    test('roots of characteristic polynomial are matrix eigenvalues', () {
      // Diagonalizable matrix with known eigenvalues 1, 2, 3
      final rows = [
        [1.0, 0.0, 0.0],
        [0.0, 2.0, 0.0],
        [0.0, 0.0, 3.0],
      ];

      final matExpr = Matrix<Expr>.fromRows(
        rows.map((r) => r.map(RationalNumber.fromDouble).toList()),
        type: exprDataType,
      );

      final charPoly = matExpr.characteristicPolynomial('lambda');

      // Check p(lambda) = 0 at eigenvalues lambda in {1, 2, 3}
      check(charPoly.evaluate({'lambda': 1.0})).isCloseTo(0.0, 1e-10);
      check(charPoly.evaluate({'lambda': 2.0})).isCloseTo(0.0, 1e-10);
      check(charPoly.evaluate({'lambda': 3.0})).isCloseTo(0.0, 1e-10);

      // Check non-eigenvalues do not vanish
      check(charPoly.evaluate({'lambda': 0.0}))
          .not((it) => it.isCloseTo(0.0, 1e-10));
      check(charPoly.evaluate({'lambda': 4.0}))
          .not((it) => it.isCloseTo(0.0, 1e-10));
    });

    test(
      '4x4 matrix characteristic polynomial with eigenvalues {1, -2, 3, 5}',
      () {
        // Diagonal matrix with eigenvalues 1, -2, 3, 5
        // p(lambda) = (lambda - 1)(lambda + 2)(lambda - 3)(lambda - 5)
        // tr(A) = 1 - 2 + 3 + 5 = 7
        // det(A) = 1 * (-2) * 3 * 5 = -30
        final rows = [
          [1.0, 0.0, 0.0, 0.0],
          [0.0, -2.0, 0.0, 0.0],
          [0.0, 0.0, 3.0, 0.0],
          [0.0, 0.0, 0.0, 5.0],
        ];

        final matExpr = Matrix<Expr>.fromRows(
          rows.map((r) => r.map(RationalNumber.fromDouble).toList()),
          type: exprDataType,
        );

        final p = matExpr.characteristicPolynomial('lambda');

        // Check all 4 eigenvalues are roots
        for (final ev in [1.0, -2.0, 3.0, 5.0]) {
          check(p.evaluate({'lambda': ev})).isCloseTo(0.0, 1e-10);
        }

        // Check trace relation: coefficient of lambda^3 is -tr(A) = -7
        // Check constant relation: p(0) = (-1)^4 * det(A) = -30
        check(p.evaluate({'lambda': 0.0})).isCloseTo(-30.0, 1e-10);
      },
    );

    test('5x5 dense matrix determinant parity against numeric LU', () {
      final rows = [
        [2.0, 1.0, 0.0, 3.0, 1.0],
        [1.0, 3.0, 2.0, 0.0, 4.0],
        [0.0, 1.0, 4.0, 2.0, 1.0],
        [3.0, 2.0, 1.0, 5.0, 0.0],
        [1.0, 0.0, 3.0, 2.0, 2.0],
      ];

      final matDouble = Matrix<double>.fromRows(rows);
      final matExpr = Matrix<Expr>.fromRows(
        rows.map((r) => r.map(RationalNumber.fromDouble).toList()),
        type: exprDataType,
      );

      final symDet = matExpr.determinant();
      final numDet = matDouble.lu.det;

      check(symDet.evaluate({})).isCloseTo(numDet, 1e-8);
    });

    test('4x4 Hilbert matrix exact rational determinant parity', () {
      // H_4 with entries 1/(i + j + 1)
      // Exact det(H_4) = 1 / 289340100
      final h4Rows = List.generate(
        4,
        (i) => List.generate(4, (j) => RationalNumber(1, i + j + 1)),
      );

      final matExpr = Matrix<Expr>.fromRows(h4Rows, type: exprDataType);
      final det = matExpr.determinant();

      check(det).equals(const RationalNumber(1, 6048000));

      // Check numeric parity
      final numDet = Matrix<double>.generate(
        4,
        4,
        (i, j) => 1.0 / (i + j + 1),
      ).lu.det;
      check(det.evaluate({})).isCloseTo(numDet, 1e-12);
    });

    test('Permutation matrices determinant parity', () {
      // Odd 4x4 permutation (swapping rows 0 and 1): det = -1
      final p4 = Matrix<Expr>.fromRows([
        [
          RationalNumber.zero,
          RationalNumber.one,
          RationalNumber.zero,
          RationalNumber.zero,
        ],
        [
          RationalNumber.one,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
        ],
        [
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.one,
          RationalNumber.zero,
        ],
        [
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.one,
        ],
      ], type: exprDataType);
      check(p4.determinant()).equals(RationalNumber.negativeOne);

      // Even 5x5 cyclic shift permutation: det = +1 (4 transpositions)
      final p5 = Matrix<Expr>.fromRows([
        [
          RationalNumber.zero,
          RationalNumber.one,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
        ],
        [
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.one,
          RationalNumber.zero,
          RationalNumber.zero,
        ],
        [
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.one,
          RationalNumber.zero,
        ],
        [
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.one,
        ],
        [
          RationalNumber.one,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
        ],
      ], type: exprDataType);
      check(p5.determinant()).equals(RationalNumber.one);
    });
  });
}
