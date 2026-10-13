import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const engine = FaddeevLeVerrierEngine();
  const x = Variable('x');
  const y = Variable('y');
  const a = Variable('a');
  const b = Variable('b');
  const c = Variable('c');
  const d = Variable('d');
  const l = Variable('lambda');

  group('FaddeevLeVerrierEngine characteristic polynomials', () {
    test('non-square matrix throws ArgumentError', () {
      final rect = Matrix<Expr>.fromRows([
        [x, y, RationalNumber.one],
        [RationalNumber.zero, x, y],
      ], type: exprDataType);
      check(() => engine.characteristicPolynomial(rect))
          .throws<ArgumentError>();
      check(() => engine.inverse(rect)).throws<ArgumentError>();
    });

    test('0x0 matrix characteristic polynomial', () {
      final empty = Matrix<Expr>.filled(
        0,
        0,
        RationalNumber.zero,
        type: exprDataType,
      );
      check(empty.characteristicPolynomial()).equals(RationalNumber.one);
    });

    test('1x1 matrix characteristic polynomial', () {
      final m1 = Matrix<Expr>.fromRows([
        [a],
      ], type: exprDataType);
      check(m1.characteristicPolynomial()).equals(l - a);
      check(m1.characteristicPolynomial('t')).equals(const Variable('t') - a);
    });

    test('2x2 numeric matrix characteristic polynomial', () {
      // [[2, 1], [0, 3]] -> lambda^2 - 5*lambda + 6
      final m2 = Matrix<Expr>.fromRows([
        [const RationalNumber(2), RationalNumber.one],
        [RationalNumber.zero, const RationalNumber(3)],
      ], type: exprDataType);
      final p = m2.characteristicPolynomial();
      final expected = (l.pow(2) - (const RationalNumber(5) * l) + 6)
          .simplify();
      check(p).equals(expected);
    });

    test('2x2 symbolic matrix characteristic polynomial', () {
      // [[a, b], [c, d]] -> lambda^2 - (a + d)*lambda + (a*d - b*c)
      final mSym = Matrix<Expr>.fromRows([
        [a, b],
        [c, d],
      ], type: exprDataType);
      final p = mSym.characteristicPolynomial();
      final expected = (l.pow(2) - ((a + d) * l) + (a * d - b * c))
          .expand()
          .simplify();
      check(p).equals(expected);
    });

    test('3x3 diagonal matrix characteristic polynomial', () {
      // diag(1, 2, 3) -> (lambda - 1)(lambda - 2)(lambda - 3)
      // = lambda^3 - 6*lambda^2 + 11*lambda - 6
      final m3 = Matrix<Expr>.fromRows([
        [RationalNumber.one, RationalNumber.zero, RationalNumber.zero],
        [RationalNumber.zero, const RationalNumber(2), RationalNumber.zero],
        [RationalNumber.zero, RationalNumber.zero, const RationalNumber(3)],
      ], type: exprDataType);
      final p = m3.characteristicPolynomial();
      final expected = ((l - 1) * (l - 2) * (l - 3)).expand().simplify();
      check(p).equals(expected);
    });

    test('Cayley-Hamilton theorem: p(A) = 0 for 2x2 matrix', () {
      // A = [[2, 1], [4, 3]]
      // tr(A) = 5, det(A) = 6 - 4 = 2 => p(lambda) = lambda^2 - 5*lambda + 2
      // A^2 - 5*A + 2*I = 0
      final matA = Matrix<Expr>.fromRows([
        [const RationalNumber(2), RationalNumber.one],
        [const RationalNumber(4), const RationalNumber(3)],
      ], type: exprDataType);

      final p = matA.characteristicPolynomial();
      check(p)
          .equals((l.pow(2) - (const RationalNumber(5) * l) + 2).simplify());

      // Evaluate matA * matA - 5 * matA + 2 * I
      final aSquared = matA * matA;
      for (var r = 0; r < 2; r++) {
        for (var cIdx = 0; cIdx < 2; cIdx++) {
          final entry =
              aSquared[r][cIdx] -
              (const RationalNumber(5) * matA[r][cIdx]) +
              (r == cIdx ? const RationalNumber(2) : RationalNumber.zero);
          check(entry.simplify()).equals(RationalNumber.zero);
        }
      }
    });
  });

  group('FaddeevLeVerrierEngine matrix inverses', () {
    test('1x1 matrix inverse', () {
      final m1 = Matrix<Expr>.fromRows([
        [const RationalNumber(4)],
      ], type: exprDataType);
      final inv = m1.inverse();
      check(inv).isNotNull();
      check(inv![0][0]).equals(const RationalNumber(1, 4));

      final mZero = Matrix<Expr>.fromRows([
        [RationalNumber.zero],
      ], type: exprDataType);
      check(mZero.inverse()).isNull();
    });

    test('2x2 numeric matrix inverse', () {
      // A = [[4, 7], [2, 6]], det = 24 - 14 = 10
      // A^-1 = [[6/10, -7/10], [-2/10, 4/10]] = [[3/5, -7/10], [-1/5, 2/5]]
      final aMat = Matrix<Expr>.fromRows([
        [const RationalNumber(4), const RationalNumber(7)],
        [const RationalNumber(2), const RationalNumber(6)],
      ], type: exprDataType);

      final inv = aMat.inverse();
      check(inv).isNotNull();
      check(inv![0][0]).equals(const RationalNumber(3, 5));
      check(inv[0][1]).equals(const RationalNumber(-7, 10));
      check(inv[1][0]).equals(const RationalNumber(-1, 5));
      check(inv[1][1]).equals(const RationalNumber(2, 5));

      // Product identity A * A^-1 = I
      final prod = aMat * inv;
      check(prod[0][0].simplify()).equals(RationalNumber.one);
      check(prod[0][1].simplify()).equals(RationalNumber.zero);
      check(prod[1][0].simplify()).equals(RationalNumber.zero);
      check(prod[1][1].simplify()).equals(RationalNumber.one);
    });

    test('2x2 symbolic diagonal matrix inverse', () {
      final diag = Matrix<Expr>.fromRows([
        [a, RationalNumber.zero],
        [RationalNumber.zero, b],
      ], type: exprDataType);

      final inv = diag.inverse();
      check(inv).isNotNull();
      check(inv![0][0].simplify()).equals(RationalNumber.one / a);
      check(inv[0][1].simplify()).equals(RationalNumber.zero);
      check(inv[1][0].simplify()).equals(RationalNumber.zero);
      check(inv[1][1].simplify()).equals(RationalNumber.one / b);
    });

    test('3x3 numeric matrix inverse and reciprocal check', () {
      // [[1, 2, 3], [0, 1, 4], [5, 6, 0]]
      // det = 1*(0 - 24) - 2*(0 - 20) + 3*(0 - 5) = -24 + 40 - 15 = 1
      final aMat = Matrix<Expr>.fromRows([
        [RationalNumber.one, const RationalNumber(2), const RationalNumber(3)],
        [RationalNumber.zero, RationalNumber.one, const RationalNumber(4)],
        [const RationalNumber(5), const RationalNumber(6), RationalNumber.zero],
      ], type: exprDataType);

      final inv = aMat.inverse();
      check(inv).isNotNull();

      final prod1 = aMat * inv!;
      final prod2 = inv * aMat;

      for (var r = 0; r < 3; r++) {
        for (var cIdx = 0; cIdx < 3; cIdx++) {
          final expected = r == cIdx ? RationalNumber.one : RationalNumber.zero;
          check(prod1[r][cIdx].simplify()).equals(expected);
          check(prod2[r][cIdx].simplify()).equals(expected);
        }
      }
    });

    test('singular matrix returns null', () {
      // [[1, 2], [2, 4]] -> det = 0
      final singular = Matrix<Expr>.fromRows([
        [RationalNumber.one, const RationalNumber(2)],
        [const RationalNumber(2), const RationalNumber(4)],
      ], type: exprDataType);
      check(singular.inverse()).isNull();
    });
  });

  group('FaddeevLeVerrierEngine adversarial stress tests: Cayley-Hamilton, inverses, singular null', () {
    test('Cayley-Hamilton theorem: p(A) = 0 for 3x3 matrix', () {
      // A = [[1, 2, 3], [0, 1, 4], [5, 6, 0]]
      final aMat = Matrix<Expr>.fromRows([
        [RationalNumber.one, const RationalNumber(2), const RationalNumber(3)],
        [RationalNumber.zero, RationalNumber.one, const RationalNumber(4)],
        [const RationalNumber(5), const RationalNumber(6), RationalNumber.zero],
      ], type: exprDataType);

      final result = engine.compute(aMat);
      final c1 = result.coefficients[0];
      final c2 = result.coefficients[1];
      final c3 = result.coefficients[2];

      final a2 = aMat * aMat;
      final a3 = a2 * aMat;
      final id3 = Matrix<Expr>.identity(3, type: exprDataType);

      // A^3 - c1*A^2 - c2*A - c3*I = 0
      for (var r = 0; r < 3; r++) {
        for (var cIdx = 0; cIdx < 3; cIdx++) {
          final entry =
              a3[r][cIdx] -
              (c1 * a2[r][cIdx]) -
              (c2 * aMat[r][cIdx]) -
              (c3 * id3[r][cIdx]);
          check(entry.simplify()).equals(RationalNumber.zero);
        }
      }
    });

    test('Cayley-Hamilton theorem: p(A) = 0 for 4x4 tridiagonal matrix', () {
      final aMat = Matrix<Expr>.fromRows([
        [
          const RationalNumber(2),
          RationalNumber.one,
          RationalNumber.zero,
          RationalNumber.zero,
        ],
        [
          RationalNumber.one,
          const RationalNumber(2),
          RationalNumber.one,
          RationalNumber.zero,
        ],
        [
          RationalNumber.zero,
          RationalNumber.one,
          const RationalNumber(2),
          RationalNumber.one,
        ],
        [
          RationalNumber.zero,
          RationalNumber.zero,
          RationalNumber.one,
          const RationalNumber(2),
        ],
      ], type: exprDataType);

      final result = engine.compute(aMat);
      final c = result.coefficients;
      final a2 = aMat * aMat;
      final a3 = a2 * aMat;
      final a4 = a3 * aMat;
      final id4 = Matrix<Expr>.identity(4, type: exprDataType);

      // A^4 - c1*A^3 - c2*A^2 - c3*A - c4*I = 0
      for (var r = 0; r < 4; r++) {
        for (var cIdx = 0; cIdx < 4; cIdx++) {
          final entry =
              a4[r][cIdx] -
              (c[0] * a3[r][cIdx]) -
              (c[1] * a2[r][cIdx]) -
              (c[2] * aMat[r][cIdx]) -
              (c[3] * id4[r][cIdx]);
          check(entry.simplify()).equals(RationalNumber.zero);
        }
      }
    });

    test('Nilpotent 3x3 matrix characteristic polynomial and power', () {
      final nMat = Matrix<Expr>.fromRows([
        [RationalNumber.zero, RationalNumber.one, const RationalNumber(2)],
        [RationalNumber.zero, RationalNumber.zero, const RationalNumber(3)],
        [RationalNumber.zero, RationalNumber.zero, RationalNumber.zero],
      ], type: exprDataType);

      final poly = nMat.characteristicPolynomial();
      check(poly).equals(l.pow(3));

      // N^3 == 0
      final n3 = (nMat * nMat) * nMat;
      for (var r = 0; r < 3; r++) {
        for (var cIdx = 0; cIdx < 3; cIdx++) {
          check(n3[r][cIdx].simplify()).equals(RationalNumber.zero);
        }
      }
    });

    test(
      '4x4 numeric matrix inverse satisfies A * A^-1 = I and A^-1 * A = I',
      () {
        final aMat = Matrix<Expr>.fromRows([
          [
            const RationalNumber(2),
            RationalNumber.one,
            RationalNumber.zero,
            RationalNumber.zero,
          ],
          [
            RationalNumber.one,
            const RationalNumber(2),
            RationalNumber.one,
            RationalNumber.zero,
          ],
          [
            RationalNumber.zero,
            RationalNumber.one,
            const RationalNumber(2),
            RationalNumber.one,
          ],
          [
            RationalNumber.zero,
            RationalNumber.zero,
            RationalNumber.one,
            const RationalNumber(2),
          ],
        ], type: exprDataType);

        final inv = aMat.inverse();
        check(inv).isNotNull();

        final p1 = aMat * inv!;
        final p2 = inv * aMat;
        for (var r = 0; r < 4; r++) {
          for (var cIdx = 0; cIdx < 4; cIdx++) {
            final expected = r == cIdx
                ? RationalNumber.one
                : RationalNumber.zero;
            check(p1[r][cIdx].simplify()).equals(expected);
            check(p2[r][cIdx].simplify()).equals(expected);
          }
        }
      },
    );

    test('2x2 symbolic matrix inverse satisfies A * A^-1 = I', () {
      final sMat = Matrix<Expr>.fromRows([
        [x, RationalNumber.one],
        [RationalNumber.zero, y],
      ], type: exprDataType);

      final inv = sMat.inverse();
      check(inv).isNotNull();
      final prod = sMat * inv!;
      check(prod[0][0].simplify()).equals(RationalNumber.one);
      check(prod[0][1].simplify()).equals(RationalNumber.zero);
      check(prod[1][0].simplify()).equals(RationalNumber.zero);
      check(prod[1][1].simplify()).equals(RationalNumber.one);
    });

    test(
      '3x3 upper triangular symbolic matrix inverse satisfies A * A^-1 = I',
      () {
        const z = Variable('z');
        final sMat = Matrix<Expr>.fromRows([
          [x, RationalNumber.one, RationalNumber.zero],
          [RationalNumber.zero, y, RationalNumber.one],
          [RationalNumber.zero, RationalNumber.zero, z],
        ], type: exprDataType);

        final inv = sMat.inverse();
        check(inv).isNotNull();
        final prod = sMat * inv!;
        for (var r = 0; r < 3; r++) {
          for (var cIdx = 0; cIdx < 3; cIdx++) {
            final expected = r == cIdx
                ? RationalNumber.one
                : RationalNumber.zero;
            check(prod[r][cIdx].simplify()).equals(expected);
          }
        }
      },
    );

    test('symmetric 2x2 symbolic matrix inverse: A * A^-1 = I', () {
      final symMat = Matrix<Expr>.fromRows([
        [x, RationalNumber.one],
        [RationalNumber.one, y],
      ], type: exprDataType);

      final inv = symMat.inverse();
      check(inv).isNotNull();
      final prod1 = symMat * inv!;
      final prod2 = inv * symMat;
      for (var r = 0; r < 2; r++) {
        for (var cIdx = 0; cIdx < 2; cIdx++) {
          final expected = r == cIdx ? RationalNumber.one : RationalNumber.zero;
          check(prod1[r][cIdx].simplify()).equals(expected);
          check(prod2[r][cIdx].simplify()).equals(expected);
        }
      }
    });

    test('general 2x2 symbolic matrix inverse: A * A^-1 = I', () {
      final genMat = Matrix<Expr>.fromRows([
        [a, b],
        [c, d],
      ], type: exprDataType);

      final inv = genMat.inverse();
      check(inv).isNotNull();
      final prod1 = genMat * inv!;
      final prod2 = inv * genMat;
      for (var r = 0; r < 2; r++) {
        for (var cIdx = 0; cIdx < 2; cIdx++) {
          final expected = r == cIdx ? RationalNumber.one : RationalNumber.zero;
          check(prod1[r][cIdx].simplify()).equals(expected);
          check(prod2[r][cIdx].simplify()).equals(expected);
        }
      }
    });

    test('cyclic 3x3 symbolic matrix inverse: A * A^-1 = I', () {
      const z = Variable('z');
      final cyclicMat = Matrix<Expr>.fromRows([
        [x, RationalNumber.one, RationalNumber.zero],
        [RationalNumber.zero, y, RationalNumber.one],
        [RationalNumber.one, RationalNumber.zero, z],
      ], type: exprDataType);

      final inv = cyclicMat.inverse();
      check(inv).isNotNull();
      final prod1 = cyclicMat * inv!;
      final prod2 = inv * cyclicMat;
      for (var r = 0; r < 3; r++) {
        for (var cIdx = 0; cIdx < 3; cIdx++) {
          final expected = r == cIdx ? RationalNumber.one : RationalNumber.zero;
          check(prod1[r][cIdx].simplify()).equals(expected);
          check(prod2[r][cIdx].simplify()).equals(expected);
        }
      }
    });

    test('symmetric 2x2 with negative entries inverse: A * A^-1 = I and A^-1 * A = I', () {
      final negMat = Matrix<Expr>.fromRows([
        [-x, RationalNumber.one],
        [RationalNumber.one, -y],
      ], type: exprDataType);

      final inv = negMat.inverse();
      check(inv).isNotNull();
      final prod1 = negMat * inv!;
      final prod2 = inv * negMat;
      for (var r = 0; r < 2; r++) {
        for (var cIdx = 0; cIdx < 2; cIdx++) {
          final expected = r == cIdx ? RationalNumber.one : RationalNumber.zero;
          check(prod1[r][cIdx].simplify()).equals(expected);
          check(prod2[r][cIdx].simplify()).equals(expected);
        }
      }
    });

    test(
      'unimodular 2x2 polynomial matrix inverse: A * A^-1 = I and A^-1 * A = I',
      () {
        final uniMat = Matrix<Expr>.fromRows([
          [x.pow(2) + 1, x],
          [x, RationalNumber.one],
        ], type: exprDataType);

        final inv = uniMat.inverse();
        check(inv).isNotNull();
        final prod1 = uniMat * inv!;
        final prod2 = inv * uniMat;
        for (var r = 0; r < 2; r++) {
          for (var cIdx = 0; cIdx < 2; cIdx++) {
            final expected = r == cIdx
                ? RationalNumber.one
                : RationalNumber.zero;
            check(prod1[r][cIdx].expand().simplify()).equals(expected);
            check(prod2[r][cIdx].expand().simplify()).equals(expected);
          }
        }
      },
    );

    test('weighted permutation 3x3 symbolic matrix inverse: P * P^-1 = I and P^-1 * P = I', () {
      const z = Variable('z');
      final pMat = Matrix<Expr>.fromRows([
        [RationalNumber.zero, x, RationalNumber.zero],
        [RationalNumber.zero, RationalNumber.zero, y],
        [z, RationalNumber.zero, RationalNumber.zero],
      ], type: exprDataType);

      final inv = pMat.inverse();
      check(inv).isNotNull();
      final prod1 = pMat * inv!;
      final prod2 = inv * pMat;
      for (var r = 0; r < 3; r++) {
        for (var cIdx = 0; cIdx < 3; cIdx++) {
          final expected = r == cIdx ? RationalNumber.one : RationalNumber.zero;
          check(prod1[r][cIdx].simplify()).equals(expected);
          check(prod2[r][cIdx].simplify()).equals(expected);
        }
      }
    });

    test('singular matrices of various sizes return null', () {
      // 1x1 zero
      final m1 = Matrix<Expr>.fromRows([
        [RationalNumber.zero],
      ], type: exprDataType);
      check(m1.inverse()).isNull();

      // 3x3 rank 1
      final r1 = Matrix<Expr>.fromRows([
        [RationalNumber.one, const RationalNumber(2), const RationalNumber(3)],
        [
          const RationalNumber(2),
          const RationalNumber(4),
          const RationalNumber(6),
        ],
        [
          const RationalNumber(3),
          const RationalNumber(6),
          const RationalNumber(9),
        ],
      ], type: exprDataType);
      check(r1.inverse()).isNull();

      // 3x3 rank 2
      final r2 = Matrix<Expr>.fromRows([
        [RationalNumber.one, const RationalNumber(2), const RationalNumber(3)],
        [
          const RationalNumber(4),
          const RationalNumber(5),
          const RationalNumber(6),
        ],
        [
          const RationalNumber(5),
          const RationalNumber(7),
          const RationalNumber(9),
        ],
      ], type: exprDataType);
      check(r2.inverse()).isNull();

      // 4x4 row 3 = row 0 + row 1 + row 2
      final r4 = Matrix<Expr>.fromRows([
        [
          RationalNumber.one,
          RationalNumber.zero,
          RationalNumber.zero,
          const RationalNumber(2),
        ],
        [
          RationalNumber.zero,
          RationalNumber.one,
          const RationalNumber(3),
          RationalNumber.zero,
        ],
        [
          const RationalNumber(2),
          RationalNumber.zero,
          RationalNumber.one,
          RationalNumber.one,
        ],
        [
          const RationalNumber(3),
          RationalNumber.one,
          const RationalNumber(4),
          const RationalNumber(3),
        ],
      ], type: exprDataType);
      check(r4.inverse()).isNull();
    });

    test(
      'various non-square matrices throw ArgumentError on all engine methods',
      () {
        for (final (r, c) in [(1, 2), (2, 1), (3, 2), (2, 3), (3, 4), (4, 3)]) {
          final rect = Matrix<Expr>.filled(r, c, x, type: exprDataType);
          check(() => engine.compute(rect)).throws<ArgumentError>();
          check(() => engine.characteristicPolynomial(rect))
              .throws<ArgumentError>();
          check(() => engine.inverse(rect)).throws<ArgumentError>();
        }
      },
    );
  });
}
