import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('CompressedPolynomial construction', () {
    test('construction, properties, and zero representation', () {
      final zero = CompressedPolynomial<double>.zero(type: DataType.float64);
      check(zero.degree).equals(-1);
      check(zero.leadingCoefficient).equals(0.0);
      check(zero.termCount).equals(0);
      check(zero.nonZeroTerms.toList()).isEmpty();
      check(zero.toMap()).isEmpty();
      check(zero.coefficients).isEmpty();
      check(zero[0]).equals(0.0);
      check(zero[100]).equals(0.0);
      check(zero.toString()).equals('0');

      // Zero via factory constructor on Polynomial
      final zeroPoly = Polynomial<double>.zero(type: DataType.float64);
      check(zero == zeroPoly).isTrue();
    });

    test('construction from map and lists', () {
      // Map constructor with unsorted keys and zero filtering
      final p1 = CompressedPolynomial<double>.fromMap({
        1000: 5.0,
        0: -2.0,
        50: 0.0, // should be stripped
        10: 3.0,
      }, type: DataType.float64);

      check(p1.degree).equals(1000);
      check(p1.leadingCoefficient).equals(5.0);
      check(p1.termCount).equals(3);
      check(p1[0]).equals(-2.0);
      check(p1[10]).equals(3.0);
      check(p1[1000]).equals(5.0);
      check(p1[50]).equals(0.0);
      check(p1[999]).equals(0.0);
      check(p1[-1]).equals(0.0);

      // Parallel list constructor with duplicates that combine
      final p2 = CompressedPolynomial<int>(
        [0, 10, 10, 20],
        [1, 2, 3, 4],
        type: DataType.int32,
      );
      check(p2.degree).equals(20);
      check(p2[10]).equals(5); // 2 + 3 combined
      check(p2.termCount).equals(3);

      // Duplicates that cancel to zero
      final p3 = CompressedPolynomial<int>(
        [5, 5],
        [3, -3],
        type: DataType.int32,
      );
      check(p3.degree).equals(-1);
      check(p3.termCount).equals(0);

      // Error on mismatched lengths
      check(() => CompressedPolynomial<int>([1, 2], [1]))
          .throws<ArgumentError>();

      // Error on negative exponent
      check(() => CompressedPolynomial<int>([-1], [1])).throws<RangeError>();
      check(() => CompressedPolynomial<int>.fromMap({-5: 1}))
          .throws<RangeError>();
    });

    test('factories on Polynomial interface', () {
      final pSparse = Polynomial<double>.sparse({
        0: -1.0,
        10000: 1.0,
      }, type: DataType.float64);
      check(pSparse).isA<CompressedPolynomial<double>>();
      check(pSparse.degree).equals(10000);

      final pComp = Polynomial<double>.compressed(
        [0, 10000],
        [-1.0, 1.0],
        type: DataType.float64,
      );
      check(pComp).isA<CompressedPolynomial<double>>();
      check(pComp == pSparse).isTrue();
    });
  });

  group('CompressedPolynomial evaluation and calculus', () {
    test('high-degree sparse evaluation: x^10000 - 1', () {
      // P(x) = x^10000 - 1
      final p = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        10000: 1.0,
      }, type: DataType.float64);

      check(p.degree).equals(10000);
      check(p.leadingCoefficient).equals(1.0);
      check(p.termCount).equals(2);

      // Integer roots
      check(p.evaluate(0.0)).equals(-1.0);
      check(p.evaluate(1.0)).equals(0.0);
      check(p.evaluate(-1.0)).equals(0.0);
      check(p.evaluateDouble(0)).equals(-1.0);
      check(p.evaluateDouble(1)).equals(0.0);
      check(p.evaluateDouble(-1)).equals(0.0);

      // (1 + 1/10000)^10000 ≈ e ≈ 2.7182818 =>
      // P(1.0001) ≈ e - 1 ≈ 1.71828
      final valE = p.evaluateDouble(1.0001);
      check(valE).isCloseTo(math.e - 1.0, 1e-3);

      // Complex evaluation: i^10000 = (i^4)^2500 = 1^2500 = 1 => P(i) = 0
      final valI = p.evaluateComplex(Complex.i);
      check(valI.a).isCloseTo(0.0, 1e-9);
      check(valI.b).isCloseTo(0.0, 1e-9);
    });

    test('high-degree calculus: differentiation and integration', () {
      // P(x) = x^10000 - 1
      final p = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        10000: 1.0,
      }, type: DataType.float64);

      // P'(x) = 10000 * x^9999
      final dp = p.derivative();
      check(dp.degree).equals(9999);
      check(dp.leadingCoefficient).equals(10000.0);
      check(dp.termCount).equals(1);
      check(dp[9999]).equals(10000.0);
      check(dp.evaluate(1.0)).equals(10000.0);
      check(p.derivative() == dp).isTrue();

      // ∫ P'(x) dx = x^10000
      final intDp = dp.integrate();
      check(intDp.degree).equals(10000);
      check(intDp.leadingCoefficient).equals(1.0);
      check(intDp[10000]).equals(1.0);
      check(intDp[0]).equals(0.0);

      // ∫ P(x) dx with constant 5: x^10001 / 10001 - x + 5
      final intP = p.integrate(5.0);
      check(intP.degree).equals(10001);
      check(intP[0]).equals(5.0);
      check(intP[1]).equals(-1.0);
      check(intP[10001]).isCloseTo(1.0 / 10001.0, 1e-12);
    });

    test(
      'high-degree arithmetic: addition, subtraction, multiplication, scale',
      () {
        // P = x^10000 - 1
        final p = CompressedPolynomial<double>.fromMap({
          0: -1.0,
          10000: 1.0,
        }, type: DataType.float64);

        // Q = x^10000 + 1
        final q = CompressedPolynomial<double>.fromMap({
          0: 1.0,
          10000: 1.0,
        }, type: DataType.float64);

        // P + Q = 2 * x^10000
        final sum = p + q;
        check(sum.degree).equals(10000);
        check(sum.leadingCoefficient).equals(2.0);
        check(sum.termCount).equals(1);
        check(sum[0]).equals(0.0);

        // P - P = 0
        final diff = p - p;
        check(diff.degree).equals(-1);
        check(diff.termCount).equals(0);

        // P - Q = -2
        final diff2 = p - q;
        check(diff2.degree).equals(0);
        check(diff2[0]).equals(-2.0);

        // P * Q = (x^10000 - 1)(x^10000 + 1) = x^20000 - 1
        final prod = p * q;
        check(prod.degree).equals(20000);
        check(prod.leadingCoefficient).equals(1.0);
        check(prod[0]).equals(-1.0);
        check(prod.termCount).equals(2);

        // Scaling
        final scaled = p.scale(3.0);
        check(scaled.degree).equals(10000);
        check(scaled[10000]).equals(3.0);
        check(scaled[0]).equals(-3.0);

        final zeroScale = p.scale(0.0);
        check(zeroScale.degree).equals(-1);

        // Negation
        final neg = -p;
        check(neg[10000]).equals(-1.0);
        check(neg[0]).equals(1.0);
      },
    );
  });

  group('CompressedPolynomial algebra and interoperability', () {
    test('sparse polynomial division and GCD', () {
      // Dividend: A(x) = x^20000 - 1
      // Divisor:  B(x) = x^10000 - 1
      // Quotient: x^10000 + 1, Remainder: 0
      final a = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        20000: 1.0,
      }, type: DataType.float64);
      final b = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        10000: 1.0,
      }, type: DataType.float64);

      final div = a.divide(b);
      check(div.quotient.degree).equals(10000);
      check(div.quotient[10000]).equals(1.0);
      check(div.quotient[0]).equals(1.0);
      check(div.remainder.degree).equals(-1);

      check((a / b).degree).equals(10000);
      check((a % b).degree).equals(-1);

      // Non-zero remainder: x^20000 / (x^10000 - 1) = x^10000 + 1 rem 1
      final a2 = CompressedPolynomial<double>.fromMap({
        20000: 1.0,
      }, type: DataType.float64);
      final div2 = a2.divide(b);
      check(div2.quotient.degree).equals(10000);
      check(div2.remainder.degree).equals(0);
      check(div2.remainder[0]).equals(1.0);

      // GCD
      final gcd = a.gcd(b);
      check(gcd.degree).equals(10000);
      check(gcd[10000]).equals(1.0);
      check(gcd[0]).equals(-1.0);

      // Division by zero throws
      final zero = CompressedPolynomial<double>.zero();
      check(() => a.divide(zero)).throws<UnsupportedError>();

      // Division by DensePolynomial
      final denseDiv = Polynomial<double>.fromCoefficients([-1.0, 1.0]);
      final divDense = a.divide(denseDiv);
      check(divDense.quotient.degree).equals(19999);

      // Compressed addition and subtraction with trailing terms and cross-types
      final cShort = CompressedPolynomial<int>([1], [2], type: DataType.int32);
      final cLong = CompressedPolynomial<int>(
        [1, 5],
        [3, 4],
        type: DataType.int32,
      );
      final sumTrailing = cShort + cLong;
      check(sumTrailing[5]).equals(4);
      final diffTrailing = cShort - cLong;
      check(diffTrailing[5]).equals(-4);

      // Compressed - Dense
      final denseSub = Polynomial<int>.fromCoefficients([1, 2]);
      final diffDense = cLong - denseSub;
      check(diffDense[5]).equals(4);

      // Multiplication combining overlapping exponent
      final xPlusOne = CompressedPolynomial<int>(
        [0, 1],
        [1, 1],
        type: DataType.int32,
      );
      final sq = xPlusOne * xPlusOne;
      check(sq[1]).equals(2);

      // Integer ring division where leading term cannot be eliminated
      final x = CompressedPolynomial<int>.fromMap({1: 1}, type: DataType.int32);
      final twoX = CompressedPolynomial<int>.fromMap({
        1: 2,
      }, type: DataType.int32);
      final intDiv = x.divide(twoX);
      check(intDiv.quotient.degree).equals(-1);
      check(intDiv.remainder).equals(x);
    });

    test('composition and power', () {
      // P(x) = x^2 - 1
      final p = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        2: 1.0,
      }, type: DataType.float64);

      // Q(x) = x^5000
      final q = CompressedPolynomial<double>.fromMap({
        5000: 1.0,
      }, type: DataType.float64);

      // P(Q(x)) = (x^5000)^2 - 1 = x^10000 - 1
      final comp = p.compose(q);
      check(comp.degree).equals(10000);
      check(comp[10000]).equals(1.0);
      check(comp[0]).equals(-1.0);
      check(comp.termCount).equals(2);
    });

    test('interoperability between Dense and Compressed representations', () {
      final sparseP = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        1000: 1.0,
      }, type: DataType.float64);
      final denseQ = Polynomial<double>.fromCoefficients([2.0, 3.0]); // 3x + 2

      // Sparse + Dense
      final sum1 = sparseP + denseQ;
      check(sum1.degree).equals(1000);
      check(sum1[1000]).equals(1.0);
      check(sum1[1]).equals(3.0);
      check(sum1[0]).equals(1.0);

      // Dense + Sparse
      final sum2 = denseQ + sparseP;
      check(sum2.degree).equals(1000);
      check(sum2 == sum1).isTrue();

      // Sparse * Dense
      final prod = sparseP * denseQ;
      check(prod.degree).equals(1001);
      check(prod[1001]).equals(3.0);
      check(prod[1000]).equals(2.0);
      check(prod[1]).equals(-3.0);
      check(prod[0]).equals(-2.0);

      // Dense == Sparse
      final pDense = Polynomial<double>.fromCoefficients([1.0, 0.0, 4.0]);
      final pSparseEquivalent = Polynomial<double>.sparse({
        0: 1.0,
        2: 4.0,
      }, type: DataType.float64);
      check(pDense == pSparseEquivalent).isTrue();
      check(pSparseEquivalent == pDense).isTrue();
      check(pDense.hashCode).equals(pSparseEquivalent.hashCode);

      // Conversions: toCompressed and toDense
      final convSparse = pDense.toCompressed();
      check(convSparse).isA<CompressedPolynomial<double>>();
      check(convSparse == pDense).isTrue();

      final convDense = pSparseEquivalent.toDense();
      check(convDense).isA<DensePolynomial<double>>();
      check(convDense == pSparseEquivalent).isTrue();
    });

    test('dense coefficients buffer limit on high-degree polynomials', () {
      final pHigh = CompressedPolynomial<double>.fromMap({
        0: 1.0,
        200000: 1.0,
      }, type: DataType.float64);
      check(() => pHigh.coefficients).throws<StateError>();

      final pLow = CompressedPolynomial<double>.fromMap({
        0: 1.0,
        5: 1.0,
      }, type: DataType.float64);
      check(pLow.coefficients).deepEquals([1.0, 0.0, 0.0, 0.0, 0.0, 1.0]);
    });
  });

  group('CompressedPolynomial formatting and integration', () {
    test('toString formatting and roots', () {
      final p = CompressedPolynomial<int>.fromMap({
        0: -1,
        10000: 1,
      }, type: DataType.int32);
      check(p.toString()).equals('x^10000 - 1');

      final constP = CompressedPolynomial<int>.fromMap({
        0: 7,
      }, type: DataType.int32);
      check(constP.toString()).equals('7');

      final mixedP = CompressedPolynomial<int>.fromMap({
        1: 1,
        2: 3,
        5: 1,
      }, type: DataType.int32);
      check(mixedP.toString()).equals('x^5 + 3x^2 + x');
      check(mixedP.nonZeroTerms.toList()).deepEquals([
        (exponent: 1, coefficient: 1),
        (exponent: 2, coefficient: 3),
        (exponent: 5, coefficient: 1),
      ]);
      check(mixedP.hashCode).equals(mixedP.toCompressed().hashCode);

      // Multiply by zero
      final zeroP = CompressedPolynomial<int>.zero(type: DataType.int32);
      check((mixedP * zeroP).degree).equals(-1);

      // Division where degree(dividend) < degree(divisor)
      final divRes = constP.divide(mixedP);
      check(divRes.quotient.degree).equals(-1);
      check(divRes.remainder).equals(constP);

      // Addition and subtraction with non-overlapping exponents
      final pA = CompressedPolynomial<int>.fromMap({
        5: 1,
        1: 2,
      }, type: DataType.int32);
      final pB = CompressedPolynomial<int>.fromMap({
        4: 3,
        0: 4,
      }, type: DataType.int32);
      check((pA + pB).toString()).equals('x^5 + 3x^4 + 2x + 4');
      check((pA - pB).toString()).equals('x^5 - 3x^4 + 2x - 4');

      // Analytical linear root
      final lin = CompressedPolynomial<double>.fromMap({
        0: -6.0,
        1: 2.0,
      }, type: DataType.float64);
      check(lin.roots.length).equals(1);
      check(lin.roots[0].a).isCloseTo(3.0, 1e-9);

      // Analytical quadratic roots
      final quad = CompressedPolynomial<double>.fromMap({
        0: -4.0,
        2: 1.0,
      }, type: DataType.float64);
      final quadRoots = quad.roots;
      check(quadRoots.length).equals(2);
      check(quadRoots.map((r) => r.a).toList()).unorderedEquals([2.0, -2.0]);

      // Companion roots error on degree > 1000
      check(() => p.roots).throws<UnsupportedError>();

      final pBig = CompressedPolynomial<BigInt>.fromMap({
        0: BigInt.from(2),
        1: BigInt.from(-3),
        2: BigInt.one,
      }, type: DataType.bigInt);
      check(pBig.evaluateDouble(4)).equals(6.0);
      check(pBig.evaluateComplex(const Complex(1.0, 1.0)).a)
          .isCloseTo(-1.0, 1e-9);
      check(pBig.roots.length).equals(2);

      final pFrac = CompressedPolynomial<Fraction>.fromMap({
        0: Fraction(2),
        1: Fraction(-3),
        2: Fraction(1),
      }, type: DataType.fraction);
      check(pFrac.evaluateDouble(4)).equals(6.0);
      check(pFrac.evaluateComplex(const Complex(1.0, 1.0)).a)
          .isCloseTo(-1.0, 1e-9);
      check(pFrac.roots.length).equals(2);
    });

    test('RationalFunction integration with CompressedPolynomial', () {
      // R(x) = (x^20000 - 1) / (x^10000 - 1)
      final num = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        20000: 1.0,
      }, type: DataType.float64);
      final den = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        10000: 1.0,
      }, type: DataType.float64);

      final r = RationalFunction(num, den);
      final simplified = r.simplify();
      check(simplified.numerator.degree).equals(10000);
      check(simplified.numerator[10000]).equals(1.0);
      check(simplified.numerator[0]).equals(1.0);
      check(simplified.denominator.degree).equals(0);
      check(simplified.denominator[0]).equals(1.0);

      // Evaluate at x = 2
      // R(2) = (2^20000 - 1) / (2^10000 - 1) = 2^10000 + 1 (overflows in
      // double, but at x = 0: (0-1)/(0-1) = 1)
      check(simplified.evaluateDouble(0.0)).equals(1.0);
    });
  });
}
