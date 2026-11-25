import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Polynomial construction and properties', () {
    test('zero, fromCoefficients, generate, isZero, and isConstant', () {
      final p0 = Polynomial<int>.zero(type: DataType.int32);
      check(p0.degree).equals(-1);
      check(p0.isZero).isTrue;
      check(p0.isConstant).isTrue;
      check(p0.leadingCoefficient).equals(0);
      check(p0[0]).equals(0);

      final pConst = Polynomial<int>.fromCoefficients([
        7,
      ], type: DataType.int32);
      check(pConst.isZero).isFalse;
      check(pConst.isConstant).isTrue;

      final p1 = Polynomial<double>.fromCoefficients([
        3.0,
        2.0,
        -5.0,
      ], type: DataType.float64);
      check(p1.degree).equals(2);
      check(p1.isConstant).isFalse;
      check(p1.leadingCoefficient).equals(-5.0);
      check(p1[3]).equals(0.0);

      final gen = Polynomial<int>.generate(2, (exp) => exp + 1);
      check(gen.coefficients).deepEquals([1, 2, 3]);
      check(Polynomial<int>.generate(-1, (exp) => exp).isZero).isTrue;
    });

    test('fromRoots expands linear, integer, complex, empty, and high-degree roots', () {
      final pEmpty = Polynomial<double>.fromRoots([], type: DataType.float64);
      check(pEmpty.coefficients).deepEquals([1.0]);

      final pInt = Polynomial<int>.fromRoots([1, 2]);
      check(pInt.coefficients).deepEquals([2, -3, 1]);

      final pComplex = Polynomial<Complex>.fromRoots([
        const Complex(0.0, 1.0),
        const Complex(0.0, -1.0),
      ]);
      check(pComplex.evaluateComplex(const Complex(0.0, 1.0)).abs())
          .isCloseTo(0.0, 1e-9);

      // Degree 70 expansion avoids FFT and evaluates cleanly at its roots
      final roots = List<double>.generate(70, (i) => (i + 1) / 100.0);
      final pHigh = Polynomial<double>.fromRoots(roots, type: DataType.float64);
      check(pHigh.degree).equals(70);
      check(pHigh.leadingCoefficient).equals(1.0);
      check(pHigh.evaluateDouble(0.01)).isCloseTo(0.0, 1e-12);
    });

    test('strips trailing zeros and exposes unmodifiable coefficients', () {
      final pWithZeros = Polynomial<double>.fromCoefficients([
        1.0,
        2.0,
        0.0,
        0.0,
      ]);
      check(pWithZeros.degree).equals(1);
      check(pWithZeros.coefficients).deepEquals([1.0, 2.0]);
      check(() => pWithZeros.coefficients[0] = 99.0).throws<UnsupportedError>();

      final allZeros = Polynomial<double>.fromCoefficients([0.0, 0.0, 0.0]);
      check(allZeros.isZero).isTrue;
      check(allZeros.coefficients.isEmpty).isTrue;
    });
  });

  group('Polynomial evaluation', () {
    test('evaluates double, BigInt, Fraction, and Complex polynomials', () {
      final poly = Polynomial<double>.fromCoefficients([
        2.0,
        -3.0,
        1.0,
      ], type: DataType.float64);
      check(poly.evaluate(1.0)).equals(0.0);
      check(poly.evaluateDouble(4)).equals(6.0);

      final cVal = poly.evaluateComplex(const Complex(1.0, 1.0));
      check(cVal.a).isCloseTo(-1.0, 1e-9);
      check(cVal.b).isCloseTo(-1.0, 1e-9);

      final pBig = Polynomial<BigInt>.fromCoefficients([
        BigInt.from(2),
        BigInt.from(-3),
        BigInt.one,
      ], type: DataType.bigInt);
      check(pBig.evaluateDouble(4)).equals(6.0);
      check(pBig.evaluateComplex(const Complex(1.0, 1.0)).a)
          .isCloseTo(-1.0, 1e-9);

      final pFrac = Polynomial<Fraction>.fromCoefficients([
        Fraction(2),
        Fraction(-3),
        Fraction(1),
      ], type: DataType.fraction);
      check(pFrac.evaluateDouble(4)).equals(6.0);
      check(pFrac.evaluateComplex(const Complex(1.0, 1.0)).a)
          .isCloseTo(-1.0, 1e-9);

      final pComp = Polynomial<Complex>.fromCoefficients([
        const Complex(2.0),
        const Complex(-3.0),
        const Complex(1.0),
      ], type: DataType.complex);
      check(pComp.evaluateDouble(4)).equals(6.0);
    });
  });

  group('Polynomial arithmetic, powers, and GCD', () {
    test('basic ring operations, monic, and pow', () {
      final polyP = Polynomial<double>.fromCoefficients([1.0, 2.0]);
      final polyQ = Polynomial<double>.fromCoefficients([3.0, -1.0, 4.0]);

      check((polyP + polyQ).coefficients).deepEquals([4.0, 1.0, 4.0]);
      check((polyP - polyQ).coefficients).deepEquals([-2.0, 3.0, -4.0]);
      check((-polyP).coefficients).deepEquals([-1.0, -2.0]);
      check(polyP.scale(3.0).coefficients).deepEquals([3.0, 6.0]);
      check((polyP * polyQ).coefficients).deepEquals([3.0, 5.0, 2.0, 8.0]);

      // monic on dense and sparse
      check(Polynomial<double>.zero().monic().isZero).isTrue;
      check(identical(polyQ.monic(), polyQ) || polyQ.monic()[2] == 1.0).isTrue;
      check(polyP.monic().coefficients).deepEquals([0.5, 1.0]);
      final sparseNonMonic = Polynomial<double>.compressed([0, 50], [6.0, 3.0]);
      final sparseMonic = sparseNonMonic.monic();
      check(sparseMonic).isA<CompressedPolynomial<double>>();
      check(sparseMonic[50]).equals(1.0);
      check(sparseMonic[0]).equals(2.0);
      check(
        () => Polynomial<int>.fromCoefficients([
          1,
          2,
        ], type: DataType.int32).monic(),
      ).throws<UnsupportedError>();

      // pow
      check(polyP.pow(0).coefficients).deepEquals([1.0]);
      check(polyP.pow(1)).equals(polyP);
      check(polyP.pow(3).coefficients).deepEquals([1.0, 6.0, 12.0, 8.0]);
      check(Polynomial<double>.zero().pow(4).isZero).isTrue;
      check(() => polyP.pow(-1)).throws<RangeError>();
    });

    test('high-degree FFT polynomial multiplication', () {
      const deg = 40;
      final coeffs1 = List.generate(deg + 1, (i) => 1.0 / (i + 1));
      final coeffs2 = List.generate(
        deg + 1,
        (i) => (i % 2 == 0 ? 1.0 : -1.0) / (i + 1),
      );
      final p1 = Polynomial<double>.fromCoefficients(coeffs1);
      final p2 = Polynomial<double>.fromCoefficients(coeffs2);
      final pProd = p1 * p2;
      check(pProd.degree).equals(80);
      for (var k = 0; k <= 80; k++) {
        var expected = 0.0;
        for (var i = 0; i <= deg; i++) {
          final j = k - i;
          if (j >= 0 && j <= deg) {
            expected += coeffs1[i] * coeffs2[j];
          }
        }
        check(pProd[k]).isCloseTo(expected, 1e-9);
      }

      final sparseA = List<double>.filled(41, 0.0)
        ..[0] = -1.0
        ..[40] = 1.0;
      final sparseB = List<double>.filled(41, 0.0)
        ..[0] = 1.0
        ..[40] = 1.0;
      final sparseProd =
          Polynomial<double>.fromCoefficients(sparseA) *
          Polynomial<double>.fromCoefficients(sparseB);
      check(sparseProd.degree).equals(80);
      check(sparseProd[0]).isCloseTo(-1.0, 1e-12);
      check(sparseProd[80]).isCloseTo(1.0, 1e-12);
      for (var k = 1; k < 80; k++) {
        check(sparseProd[k]).equals(0.0);
      }
    });

    test('division and modulo', () {
      final a = Polynomial<double>.fromCoefficients([-4.0, 0.0, -2.0, 1.0]);
      final b = Polynomial<double>.fromCoefficients([-3.0, 1.0]);
      final div = a.divide(b);
      check(div.quotient.coefficients).deepEquals([3.0, 1.0, 1.0]);
      check(div.remainder.coefficients[0]).isCloseTo(5.0, 1e-9);
      check((a / b).coefficients).deepEquals([3.0, 1.0, 1.0]);
      check((a % b).coefficients[0]).isCloseTo(5.0, 1e-9);

      final small = Polynomial<int>.fromCoefficients([1]);
      final big = Polynomial<int>.fromCoefficients([1, 2, 3]);
      final lowDiv = small.divide(big);
      check(lowDiv.quotient.isZero).isTrue;
      check(lowDiv.remainder.coefficients).deepEquals([1]);
      check(() => small.divide(Polynomial<int>.zero()))
          .throws<UnsupportedError>();
    });

    test('Euclidean GCD over float and integer polynomials', () {
      final a = Polynomial<double>.fromRoots([1.0, 2.0]);
      final b = Polynomial<double>.fromRoots([2.0, 3.0]);
      final gcd = a.gcd(b);
      check(gcd.degree).equals(1);
      check(gcd[1]).isCloseTo(1.0, 1e-9);
      check(gcd[0]).isCloseTo(-2.0, 1e-9);

      check(Polynomial<double>.zero().gcd(Polynomial<double>.zero()).isZero)
          .isTrue;
      check(
        Polynomial<double>.compressed(
          [0],
          [0.0],
        ).gcd(Polynomial<double>.compressed([0], [0.0])),
      ).isA<CompressedPolynomial<double>>();
      final sparseGcdDense = Polynomial<double>.compressed(
        [0, 2],
        [-1.0, 1.0],
      ).gcd(Polynomial<double>.fromCoefficients([-1.0, 1.0]));
      check(sparseGcdDense).isA<CompressedPolynomial<double>>();
      check(sparseGcdDense.degree).equals(1);

      final c1 = Polynomial<double>.fromRoots([1.0, 2.0, 3.0]);
      final c2 = Polynomial<double>.fromRoots([2.0, 3.0, 4.0]);
      final gcdCubic = c1.gcd(c2);
      check(gcdCubic.degree).equals(2);
      check(gcdCubic[0]).isCloseTo(6.0, 1e-9);

      // Integer ring exact and non-unit GCD
      final exactIntA = Polynomial<int>.fromCoefficients([
        0,
        2,
        2,
      ], type: DataType.int32);
      final exactIntB = Polynomial<int>.fromCoefficients([
        0,
        2,
      ], type: DataType.int32);
      check(exactIntA.gcd(exactIntB).coefficients).deepEquals([0, 2]);

      final intA = Polynomial<int>.fromCoefficients([
        0,
        1,
        1,
      ], type: DataType.int32);
      final intB = Polynomial<int>.fromCoefficients([
        0,
        2,
      ], type: DataType.int32);
      check(() => intA.gcd(intB)).throws<UnsupportedError>();
      check(() => intA.toCompressed().gcd(intB)).throws<UnsupportedError>();

      // Rejects non-finite floats and type mismatches
      check(() => Polynomial<double>.fromCoefficients([1.0, double.nan]).gcd(a))
          .throws<ArgumentError>();
      check(
        () => Polynomial<int>.fromCoefficients(
          [1],
          type: DataType.int32,
        ).gcd(Polynomial<int>.fromCoefficients([1], type: DataType.int64)),
      ).throws<ArgumentError>();
    });
  });

  group('Polynomial calculus and composition', () {
    test('differentiation and integration', () {
      final poly = Polynomial<double>.fromCoefficients([5.0, 4.0, 3.0, 2.0]);
      final deriv = poly.derivative();
      check(deriv.coefficients).deepEquals([4.0, 6.0, 6.0]);
      check(poly.derivative(order: 2).coefficients).deepEquals([6.0, 12.0]);
      check(deriv.integrate(5.0).coefficients).deepEquals([5.0, 4.0, 3.0, 2.0]);

      final symPoly = Polynomial<Expr>.sparse({
        99: IntegerNumber.of(1),
      }, type: exprDataType);
      check(symPoly.integrate()[100])
          .equals(RationalNumber.of(const Integer(1), const Integer(100)));
    });

    test('composition with polynomials and zero', () {
      final p = Polynomial<double>.fromCoefficients([2.0, 3.0, 1.0]);
      final q = Polynomial<double>.fromCoefficients([1.0, 1.0]);
      final composed = p.compose(q);
      check(composed[0]).isCloseTo(6.0, 1e-9);
      check(composed[1]).isCloseTo(5.0, 1e-9);
      check(composed[2]).isCloseTo(1.0, 1e-9);
      check(composed.evaluate(3.0)).isCloseTo(30.0, 1e-9);

      final atZero = p.compose(Polynomial<double>.zero());
      check(atZero.coefficients).deepEquals([2.0]);
      check(
        Polynomial<int>.fromCoefficients([5])
            .compose(Polynomial<int>.fromCoefficients([1, 2]))[0],
      ).equals(5);
    });
  });

  group('Polynomial roots', () {
    test('constant and zero polynomials have empty roots', () {
      check(Polynomial<double>.zero().roots).isEmpty;
      check(Polynomial<double>.fromCoefficients([5.0]).roots).isEmpty;
    });

    test('linear, quadratic real, quadratic complex, and cubic roots', () {
      final p1 = Polynomial<double>.fromCoefficients([2.0, 4.0]);
      check(p1.roots.single.a).isCloseTo(-0.5, 1e-9);

      final p2 = Polynomial<double>.fromCoefficients([6.0, -5.0, 1.0]);
      final r2 = p2.roots.map((r) => r.a).toList()..sort();
      check(r2[0]).isCloseTo(2.0, 1e-9);
      check(r2[1]).isCloseTo(3.0, 1e-9);

      final p3 = Polynomial<double>.fromCoefficients([4.0, 0.0, 1.0]);
      check(p3.roots[0].a).isCloseTo(0.0, 1e-9);
      check(p3.roots[0].b.abs()).isCloseTo(2.0, 1e-9);

      final p4 = Polynomial<double>.fromRoots([1.0, 2.0, 3.0]);
      final r4 = p4.roots.map((r) => r.a).toList()..sort();
      check(r4[0]).isCloseTo(1.0, 1e-6);
      check(r4[1]).isCloseTo(2.0, 1e-6);
      check(r4[2]).isCloseTo(3.0, 1e-6);

      // Catastrophic cancellation avoidance
      final pCancel = Polynomial<double>.fromCoefficients([1.0, 1e8, 1.0]);
      final rCancel = pCancel.roots.map((r) => r.a).toList()..sort();
      check(rCancel[0]).isCloseTo(-1e8, 1.0);
      check(rCancel[1]).isCloseTo(-1e-8, 1e-16);
    });

    test('zero-root deflation handles exact zero roots and high-degree sparse polynomials', () {
      // x^3 * (x - 2) = -2x^3 + x^4
      final pDeg4 = Polynomial<double>.fromCoefficients([
        0.0,
        0.0,
        0.0,
        -2.0,
        1.0,
      ]);
      final rDeg4 = pDeg4.roots;
      check(rDeg4.length).equals(4);
      final reals = rDeg4.map((r) => r.a).toList()..sort();
      check(reals).deepEquals([0.0, 0.0, 0.0, 2.0]);

      // x^10000 - x^9998 = x^9998 * (x^2 - 1): solvable analytically after deflation!
      final highSparse = Polynomial<double>.sparse({9998: -1.0, 10000: 1.0});
      final highRoots = highSparse.roots;
      check(highRoots.length).equals(10000);
      final nonZero =
          highRoots.where((r) => r != Complex.zero).map((r) => r.a).toList()
            ..sort();
      check(nonZero.length).equals(2);
      check(nonZero[0]).isCloseTo(-1.0, 1e-12);
      check(nonZero[1]).isCloseTo(1.0, 1e-12);

      // Pure monomial c * x^5000 has 5000 exact zero roots
      final monomial = Polynomial<double>.sparse({5000: 3.0});
      check(monomial.roots.length).equals(5000);
      check(monomial.roots.every((r) => r == Complex.zero)).isTrue;
    });

    test('overflow-safe real and complex quadratic roots', () {
      // Extreme large coefficients (b^2 would overflow without rescaling)
      final huge = Polynomial<double>.fromCoefficients([6e200, -5e200, 1e200]);
      final rHuge = huge.roots.map((r) => r.a).toList()..sort();
      check(rHuge[0]).isCloseTo(2.0, 1e-12);
      check(rHuge[1]).isCloseTo(3.0, 1e-12);

      // Extreme tiny coefficients (b^2 would underflow to 0 without rescaling)
      final tiny = Polynomial<double>.fromCoefficients([
        6e-200,
        -5e-200,
        1e-200,
      ]);
      final rTiny = tiny.roots.map((r) => r.a).toList()..sort();
      check(rTiny[0]).isCloseTo(2.0, 1e-12);
      check(rTiny[1]).isCloseTo(3.0, 1e-12);

      // Complex linear & quadratic with large coefficients and negative-real disc
      final pCompLin = Polynomial<Complex>.fromCoefficients([
        const Complex(2.0, -2.0),
        const Complex(1.0, 1.0),
      ], type: DataType.complex);
      check(pCompLin.roots.single.a).isCloseTo(0.0, 1e-9);
      check(pCompLin.roots.single.b).isCloseTo(2.0, 1e-9);

      final pCompQuad = Polynomial<Complex>.fromCoefficients([
        const Complex(1e200, 1e200),
        const Complex(-2e200, -1e200),
        const Complex(1e200, 0.0),
      ], type: DataType.complex);
      final rComp = pCompQuad.roots;
      check(rComp.length).equals(2);
      for (final root in rComp) {
        check(root.a.isFinite && root.b.isFinite).isTrue;
      }
      // Also test negative real part in _complexSqrt branch: x^2 + 4x + (4 + 4) -> disc = -16, and (z^2 + 1) with complex coeff
      final pNegDisc = Polynomial<Complex>.fromCoefficients([
        const Complex(5.0, 1.0),
        const Complex(0.0, 0.0),
        Complex.one,
      ], type: DataType.complex);
      for (final r in pNegDisc.roots) {
        final residual = r * r + const Complex(5.0, 1.0);
        check(residual.abs()).isCloseTo(0.0, 1e-12);
      }
      // Also test positive real part discriminant in _complexSqrt:
      // z^2 - (2 + 2i)z + (0 + 2i) -> disc = (2 + 2i)^2 - 8i = 8i - 8i = 0, and z^2 - 4z + (3 - i) -> disc = 4 + 4i
      final pPosDisc = Polynomial<Complex>.fromCoefficients([
        const Complex(3.0, -1.0),
        const Complex(-4.0, 0.0),
        Complex.one,
      ], type: DataType.complex);
      for (final r in pPosDisc.roots) {
        final residual =
            r * r - const Complex(4.0) * r + const Complex(3.0, -1.0);
        check(residual.abs()).isCloseTo(0.0, 1e-12);
      }
    });

    test('invalid coefficient and unsupported degree errors', () {
      final pExpr = Polynomial<Expr>.fromCoefficients(const [
        Variable('x'),
        Variable('y'),
      ], type: exprDataType);
      check(() => pExpr.roots).throws<ArgumentError>();

      final pNan = Polynomial<double>.fromCoefficients([1.0, double.nan, 1.0]);
      check(() => pNan.roots).throws<ArgumentError>();

      final pInf = Polynomial<double>.fromCoefficients([1.0, double.infinity]);
      check(() => pInf.roots).throws<ArgumentError>();

      final cubicComplex = Polynomial<Complex>.fromCoefficients([
        Complex.one,
        Complex.zero,
        const Complex(0.0, 1.0),
        Complex.one,
      ]);
      check(() => cubicComplex.roots).throws<UnsupportedError>();
    });
  });

  group('Polynomial equality, hashing, and formatting', () {
    test('equality and hashCode respect DataType and representation', () {
      final pInt = Polynomial<num>.fromCoefficients([
        1,
        2,
      ], type: DataType.int32);
      final pFloat = Polynomial<num>.fromCoefficients([
        1.0,
        2.0,
      ], type: DataType.float64);
      check(pInt == pFloat).isFalse;

      final cInt = Polynomial<num>.compressed(
        [0, 1],
        [1, 2],
        type: DataType.int32,
      );
      final cFloat = Polynomial<num>.compressed(
        [0, 1],
        [1.0, 2.0],
        type: DataType.float64,
      );
      check(cInt == cFloat).isFalse;
      check(pInt == cInt).isTrue;
      check(pInt.hashCode).equals(cInt.hashCode);

      final denseP = Polynomial<int>.fromCoefficients([1, 0, 3]);
      final compP = Polynomial<int>.compressed([0, 2], [1, 3]);
      check(denseP == compP).isTrue;
      check(compP == denseP).isTrue;
      check(denseP.hashCode).equals(compP.hashCode);
    });

    test('equality ignores IEEE-754 negative zero', () {
      final pPos = Polynomial<double>.fromCoefficients([0.0, 1.0]);
      final pNeg = Polynomial<double>.fromCoefficients([-0.0, 1.0]);
      check(pPos == pNeg).isTrue;
      check(pPos.hashCode).equals(pNeg.hashCode);

      final cPos = Polynomial<Complex>.fromCoefficients([
        Complex.zero,
        Complex.one,
      ], type: DataType.complex);
      final cNeg = Polynomial<Complex>.fromCoefficients([
        const Complex(-0.0, -0.0),
        Complex.one,
      ], type: DataType.complex);
      check(cPos == cNeg).isTrue;
      check(cPos.hashCode).equals(cNeg.hashCode);
    });

    test(
      'toString formatting handles positive, negative, and complex terms',
      () {
        check(Polynomial<double>.zero().toString()).equals('0');
        check(Polynomial<int>.fromCoefficients([5]).toString()).equals('5');
        check(Polynomial<int>.fromCoefficients([1, 1]).toString())
            .equals('x + 1');
        check(Polynomial<int>.fromCoefficients([3, 0, 2, 1]).toString())
            .equals('x^3 + 2x^2 + 3');
        check(Polynomial<int>.fromCoefficients([-2, 1]).toString())
            .equals('x - 2');
        check(Polynomial<int>.fromCoefficients([1, -1, 1]).toString())
            .equals('x^2 - x + 1');
        check(Polynomial<int>.fromCoefficients([-4, -3, -2]).toString())
            .equals('-2x^2 - 3x - 4');

        final quadComplex = Polynomial<Complex>.fromCoefficients([
          const Complex(1.0, 2.0),
          const Complex(3.0, -1.0),
          const Complex(1.0, 1.0),
        ]);
        check(quadComplex.toString()).matchesPattern(
          RegExp(
            r'^\(1(\.0)? \+ 1(\.0)?i\)x\^2 \+ \(3(\.0)? - 1(\.0)?i\)x \+ 1(\.0)? \+ 2(\.0)?i$',
          ),
        );
      },
    );
  });
}
