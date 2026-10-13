import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const engine = BareissEngine();
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');
  const w = Variable('w');

  group('BareissEngine determinant dimensions & basic cases', () {
    test('non-square matrix throws ArgumentError', () {
      final rect = Matrix<Expr>.fromRows([
        [x, y, z],
        [RationalNumber.one, RationalNumber.zero, RationalNumber.one],
      ], type: exprDataType);
      check(() => engine.determinant(rect)).throws<ArgumentError>();
      check(rect.determinant).throws<ArgumentError>();
    });

    test('0x0 matrix determinant is 1', () {
      final empty = Matrix<Expr>.filled(
        0,
        0,
        RationalNumber.zero,
        type: exprDataType,
      );
      check(engine.determinant(empty)).equals(RationalNumber.one);
      check(empty.determinant()).equals(RationalNumber.one);
    });

    test('1x1 matrix determinant', () {
      final mConst = Matrix<Expr>.fromRows([
        [const RationalNumber(5)],
      ], type: exprDataType);
      check(engine.determinant(mConst)).equals(const RationalNumber(5));

      final mVar = Matrix<Expr>.fromRows([
        [x],
      ], type: exprDataType);
      check(engine.determinant(mVar)).equals(x);

      final mZero = Matrix<Expr>.fromRows([
        [RationalNumber.zero],
      ], type: exprDataType);
      check(engine.determinant(mZero)).equals(RationalNumber.zero);
    });

    test('2x2 matrix determinant', () {
      // [[3, 8], [4, 6]] -> 3*6 - 8*4 = 18 - 32 = -14
      final mNum = Matrix<Expr>.fromRows([
        [const RationalNumber(3), const RationalNumber(8)],
        [const RationalNumber(4), const RationalNumber(6)],
      ], type: exprDataType);
      check(mNum.determinant()).equals(const RationalNumber(-14));

      // Symbolic [[a, b], [c, d]]
      const a = Variable('a');
      const b = Variable('b');
      const c = Variable('c');
      const d = Variable('d');
      final mSym = Matrix<Expr>.fromRows([
        [a, b],
        [c, d],
      ], type: exprDataType);
      check(mSym.determinant()).equals(a * d - b * c);

      // Upper triangular
      final mTri = Matrix<Expr>.fromRows([
        [x, const RationalNumber(2)],
        [RationalNumber.zero, y],
      ], type: exprDataType);
      check(mTri.determinant()).equals(x * y);

      // Singular [[2x, 4x], [1, 2]] -> 4x - 4x = 0
      final mSingular = Matrix<Expr>.fromRows([
        [const RationalNumber(2) * x, const RationalNumber(4) * x],
        [RationalNumber.one, const RationalNumber(2)],
      ], type: exprDataType);
      check(mSingular.determinant()).equals(RationalNumber.zero);
    });
  });

  group('BareissEngine 3x3 matrices', () {
    test('3x3 numeric matrix', () {
      // [[2, 1, 3], [1, 0, 2], [3, 2, 1]] -> 3
      final m = Matrix<Expr>.fromRows([
        [const RationalNumber(2), RationalNumber.one, const RationalNumber(3)],
        [RationalNumber.one, RationalNumber.zero, const RationalNumber(2)],
        [const RationalNumber(3), const RationalNumber(2), RationalNumber.one],
      ], type: exprDataType);
      check(m.determinant()).equals(const RationalNumber(3));
    });

    test('3x3 cyclic symbolic matrix', () {
      // [[x, 1, 0], [0, x, 1], [1, 0, x]] -> x^3 + 1
      final m = Matrix<Expr>.fromRows([
        [x, RationalNumber.one, RationalNumber.zero],
        [RationalNumber.zero, x, RationalNumber.one],
        [RationalNumber.one, RationalNumber.zero, x],
      ], type: exprDataType);
      check(m.determinant()).equals(x.pow(3) + 1);
    });

    test('3x3 singular matrices', () {
      // Rank 1
      final rank1 = Matrix<Expr>.fromRows([
        [x, y, z],
        [x * 2, y * 2, z * 2],
        [x * 3, y * 3, z * 3],
      ], type: exprDataType);
      check(rank1.determinant()).equals(RationalNumber.zero);

      // Rank 2 (sum of rows)
      final rank2 = Matrix<Expr>.fromRows([
        [x, y, RationalNumber.one],
        [RationalNumber.one, x, y],
        [x + 1, x + y, y + 1],
      ], type: exprDataType);
      check(rank2.determinant()).equals(RationalNumber.zero);
    });

    test('3x3 Vandermonde matrix', () {
      // [[1, x, x^2], [1, y, y^2], [1, z, z^2]]
      // det = (y - x)(z - x)(z - y) = -x^2*y + x^2*z + x*y^2 - x*z^2 - y^2*z + y*z^2
      final vander = Matrix<Expr>.fromRows([
        [RationalNumber.one, x, x.pow(2)],
        [RationalNumber.one, y, y.pow(2)],
        [RationalNumber.one, z, z.pow(2)],
      ], type: exprDataType);

      final expected = ((y - x) * (z - x) * (z - y)).expand().simplify();
      check(vander.determinant()).equals(expected);
    });
  });

  group('BareissEngine 4x4 matrices & zero denominator swell', () {
    test('4x4 diagonal matrix', () {
      final diag = Matrix<Expr>.fromRows([
        [x, RationalNumber.zero, RationalNumber.zero, RationalNumber.zero],
        [RationalNumber.zero, y, RationalNumber.zero, RationalNumber.zero],
        [RationalNumber.zero, RationalNumber.zero, z, RationalNumber.zero],
        [RationalNumber.zero, RationalNumber.zero, RationalNumber.zero, w],
      ], type: exprDataType);
      check(diag.determinant()).equals(w * x * y * z);
    });

    test('4x4 dense numeric matrix', () {
      // [[1, 2, 3, 4], [5, 6, 7, 8], [2, 6, 4, 8], [3, 1, 1, 2]]
      final m = Matrix<Expr>.fromRows([
        [
          RationalNumber.one,
          const RationalNumber(2),
          const RationalNumber(3),
          const RationalNumber(4),
        ],
        [
          const RationalNumber(5),
          const RationalNumber(6),
          const RationalNumber(7),
          const RationalNumber(8),
        ],
        [
          const RationalNumber(2),
          const RationalNumber(6),
          const RationalNumber(4),
          const RationalNumber(8),
        ],
        [
          const RationalNumber(3),
          RationalNumber.one,
          RationalNumber.one,
          const RationalNumber(2),
        ],
      ], type: exprDataType);
      // Standard calculation: 72
      check(m.determinant()).equals(const RationalNumber(72));
    });

    test('4x4 polynomial matrix has zero uncancelled Div nodes', () {
      final polyMat = Matrix<Expr>.fromRows([
        [x, RationalNumber.one, RationalNumber.zero, RationalNumber.zero],
        [RationalNumber.one, x, RationalNumber.one, RationalNumber.zero],
        [RationalNumber.zero, RationalNumber.one, x, RationalNumber.one],
        [RationalNumber.zero, RationalNumber.zero, RationalNumber.one, x],
      ], type: exprDataType);
      // Tridiagonal 1s and x on diagonal: determinant is x^4 - 3x^2 + 1
      final det = polyMat.determinant();
      check(det).equals(x.pow(4) - (const RationalNumber(3) * x.pow(2)) + 1);
      // Verify no Div node exists anywhere in det
      bool hasDiv(Expr e) => switch (e) {
        Div() => true,
        UnaryExpr(:final expr) => hasDiv(expr),
        BinaryExpr(:final left, :final right) => hasDiv(left) || hasDiv(right),
        _ => false,
      };
      check(hasDiv(det)).isFalse();
    });
  });

  group('BareissEngine row pivoting & permutations', () {
    test('diagonal zero requiring 2x2 row swap', () {
      // [[0, 1], [1, 0]] -> det = -1
      final m = Matrix<Expr>.fromRows([
        [RationalNumber.zero, RationalNumber.one],
        [RationalNumber.one, RationalNumber.zero],
      ], type: exprDataType);
      check(m.determinant()).equals(RationalNumber.negativeOne);
    });

    test('diagonal zero in 3x3 matrix requiring row swap', () {
      // [[0, x, 1], [x, 1, 0], [1, 0, x]]
      // det = -(x^3 + 1)
      final m = Matrix<Expr>.fromRows([
        [RationalNumber.zero, x, RationalNumber.one],
        [x, RationalNumber.one, RationalNumber.zero],
        [RationalNumber.one, RationalNumber.zero, x],
      ], type: exprDataType);
      check(m.determinant()).equals(-(x.pow(3) + 1));
    });

    test(
      'column-deficient matrix with vanishing pivot candidates returns 0',
      () {
        // First column is all zeros
        final m = Matrix<Expr>.fromRows([
          [RationalNumber.zero, x, y],
          [RationalNumber.zero, y, z],
          [RationalNumber.zero, z, x],
        ], type: exprDataType);
        check(m.determinant()).equals(RationalNumber.zero);
      },
    );
  });

  group('BareissEngine adversarial stress tests: zeros, pivoting, deficient columns', () {
    test('3x3 matrix with zeros on entire diagonal', () {
      // [[0, 1, 2], [3, 0, 4], [5, 6, 0]] -> det = 56
      final m = Matrix<Expr>.fromRows([
        [RationalNumber.zero, RationalNumber.one, const RationalNumber(2)],
        [const RationalNumber(3), RationalNumber.zero, const RationalNumber(4)],
        [const RationalNumber(5), const RationalNumber(6), RationalNumber.zero],
      ], type: exprDataType);
      check(m.determinant()).equals(const RationalNumber(56));
    });

    test('4x4 permutation matrix (4-cycle, odd permutation)', () {
      // [[0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1], [1, 0, 0, 0]] -> det = -1
      final m = Matrix<Expr>.fromRows([
        [
          RationalNumber.zero,
          RationalNumber.one,
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
        [
          RationalNumber.one,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
        ],
      ], type: exprDataType);
      check(m.determinant()).equals(RationalNumber.negativeOne);
    });

    test('4x4 reverse identity matrix (antidiagonal 1s)', () {
      // [[0, 0, 0, 1], [0, 0, 1, 0], [0, 1, 0, 0], [1, 0, 0, 0]] -> det = (-1)^(4*3/2) = 1
      final m = Matrix<Expr>.fromRows([
        [
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.one,
        ],
        [
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.one,
          RationalNumber.zero,
        ],
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
      ], type: exprDataType);
      check(m.determinant()).equals(RationalNumber.one);
    });

    test(
      '4x4 matrix with zero at (0,0) and (1,1) requiring multiple row pivots',
      () {
        final m = Matrix<Expr>.fromRows([
          [
            RationalNumber.zero,
            const RationalNumber(2),
            RationalNumber.one,
            const RationalNumber(3),
          ],
          [
            const RationalNumber(1),
            RationalNumber.zero,
            const RationalNumber(4),
            const RationalNumber(2),
          ],
          [
            const RationalNumber(3),
            const RationalNumber(1),
            const RationalNumber(2),
            const RationalNumber(5),
          ],
          [
            const RationalNumber(2),
            const RationalNumber(4),
            const RationalNumber(1),
            const RationalNumber(1),
          ],
        ], type: exprDataType);
        // det([[0, 2, 1, 3], [1, 0, 4, 2], [3, 1, 2, 5], [2, 4, 1, 1]])
        // -2 * det([[1, 4, 2], [3, 2, 5], [2, 1, 1]]) + 1 * det([[1, 0, 2], [3, 1, 5], [2, 4, 1]]) - 3 * det([[1, 0, 4], [3, 1, 2], [2, 4, 1]])
        // [1*(2-5) - 4*(3-10) + 2*(3-4)] = -3 + 28 - 2 = 23 -> -2 * 23 = -46
        // [1*(1-20) - 0 + 2*(12-2)] = -19 + 20 = 1 -> 1 * 1 = 1
        // [1*(1-8) - 0 + 4*(12-2)] = -7 + 40 = 33 -> -3 * 33 = -99
        // -46 + 1 - 99 = -144
        check(m.determinant()).equals(const RationalNumber(-144));
      },
    );

    test('4x4 singular matrix with row of zeros or column of zeros', () {
      final colZero = Matrix<Expr>.fromRows([
        [x, RationalNumber.zero, y, z],
        [y, RationalNumber.zero, z, x],
        [z, RationalNumber.zero, x, y],
        [w, RationalNumber.zero, y, z],
      ], type: exprDataType);
      check(colZero.determinant()).equals(RationalNumber.zero);

      final rowZero = Matrix<Expr>.fromRows([
        [x, y, z, w],
        [
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.zero,
        ],
        [z, x, y, w],
        [w, z, x, y],
      ], type: exprDataType);
      check(rowZero.determinant()).equals(RationalNumber.zero);
    });

    test('4x4 singular matrix with linearly dependent column', () {
      // Col 3 = Col 0 + Col 1
      final m = Matrix<Expr>.fromRows([
        [x, y, z, x + y],
        [
          const RationalNumber(2),
          const RationalNumber(3),
          RationalNumber.one,
          const RationalNumber(5),
        ],
        [
          RationalNumber.one,
          RationalNumber.zero,
          const RationalNumber(4),
          RationalNumber.one,
        ],
        [y, x, w, y + x],
      ], type: exprDataType);
      check(m.determinant()).equals(RationalNumber.zero);
    });

    test('various non-square matrices throw ArgumentError', () {
      for (final (r, c) in [
        (1, 2),
        (2, 1),
        (2, 3),
        (3, 2),
        (3, 4),
        (4, 3),
        (1, 4),
        (4, 1),
      ]) {
        final rect = Matrix<Expr>.filled(r, c, x, type: exprDataType);
        check(() => engine.determinant(rect)).throws<ArgumentError>();
      }
    });
  });

  group('BareissEngine adversarial stress tests: Vandermonde & fraction-free polynomial matrices', () {
    test('4x4 symbolic Vandermonde matrix has zero Div nodes', () {
      const a = Variable('a');
      const b = Variable('b');
      const c = Variable('c');
      const d = Variable('d');
      final vander4 = Matrix<Expr>.fromRows([
        [RationalNumber.one, a, a.pow(2), a.pow(3)],
        [RationalNumber.one, b, b.pow(2), b.pow(3)],
        [RationalNumber.one, c, c.pow(2), c.pow(3)],
        [RationalNumber.one, d, d.pow(2), d.pow(3)],
      ], type: exprDataType);

      final det = vander4.determinant();
      final expected =
          ((b - a) * (c - a) * (d - a) * (c - b) * (d - b) * (d - c))
              .expand()
              .simplify();
      check(det).equals(expected);
      check(_hasDiv(det)).isFalse();
    });

    test('3x3 polynomial matrix with non-monomial pivot x^2 + 1 has zero Div nodes', () {
      final polyMat = Matrix<Expr>.fromRows([
        [x.pow(2) + 1, x, RationalNumber.one],
        [x, x.pow(2) + 1, x],
        [RationalNumber.one, x, x.pow(2) + 1],
      ], type: exprDataType);

      final det = polyMat.determinant();
      // Expansion:
      // (x^2 + 1)*((x^2 + 1)^2 - x^2) - x*(x*(x^2 + 1) - x) + 1*(x^2 - (x^2 + 1))
      // = (x^2 + 1)(x^4 + 2x^2 + 1 - x^2) - x*(x^3 + x - x) + (x^2 - x^2 - 1)
      // = (x^2 + 1)(x^4 + x^2 + 1) - x^4 - 1
      // = x^6 + x^4 + x^2 + x^4 + x^2 + 1 - x^4 - 1
      // = x^6 + x^4 + 2x^2
      final expected =
          (x.pow(6) + x.pow(4) + (const RationalNumber(2) * x.pow(2)))
              .simplify();
      check(det).equals(expected);
      check(_hasDiv(det)).isFalse();
    });

    test('3x3 circulant polynomial matrix has zero Div nodes', () {
      // [[x, y, z], [z, x, y], [y, z, x]] -> x^3 + y^3 + z^3 - 3*x*y*z
      final circ = Matrix<Expr>.fromRows([
        [x, y, z],
        [z, x, y],
        [y, z, x],
      ], type: exprDataType);

      final det = circ.determinant();
      final expected =
          (x.pow(3) +
                  y.pow(3) +
                  z.pow(3) -
                  (const RationalNumber(3) * x * y * z))
              .expand()
              .simplify();
      check(det).equals(expected);
      check(_hasDiv(det)).isFalse();
    });

    test('4x4 block-polynomial matrix has zero Div nodes', () {
      // [[x + 1, y, 0, 0], [0, x + 1, y, 0], [0, 0, x + 1, y], [y, 0, 0, x + 1]]
      // Determinant of cyclic matrix of order 4: (x + 1)^4 - y^4
      final m = Matrix<Expr>.fromRows([
        [x + 1, y, RationalNumber.zero, RationalNumber.zero],
        [RationalNumber.zero, x + 1, y, RationalNumber.zero],
        [RationalNumber.zero, RationalNumber.zero, x + 1, y],
        [y, RationalNumber.zero, RationalNumber.zero, x + 1],
      ], type: exprDataType);

      final det = m.determinant();
      final expected = ((x + 1).pow(4) - y.pow(4)).expand().simplify();
      check(det).equals(expected);
      check(_hasDiv(det)).isFalse();
    });
  });
}

bool _hasDiv(Expr e) => switch (e) {
  Div() => true,
  UnaryExpr(:final expr) => _hasDiv(expr),
  BinaryExpr(:final left, :final right) => _hasDiv(left) || _hasDiv(right),
  _ => false,
};
