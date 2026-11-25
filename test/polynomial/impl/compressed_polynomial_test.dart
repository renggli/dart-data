import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('CompressedPolynomial construction', () {
    test('construction, properties, zero, and negative-zero normalization', () {
      final zero = CompressedPolynomial<double>.zero(type: DataType.float64);
      check(zero.degree).equals(-1);
      check(zero.isZero).isTrue;
      check(zero.isConstant).isTrue;
      check(zero.leadingCoefficient).equals(0.0);
      check(zero.termCount).equals(0);
      check(zero.nonZeroTerms.toList()).isEmpty;
      check(zero.toMap()).isEmpty;
      check(zero.coefficients).isEmpty;
      check(zero[0]).equals(0.0);
      check(zero[100]).equals(0.0);
      check(zero.toString()).equals('0');
      check((-zero).isZero).isTrue;

      final zeroPoly = Polynomial<double>.zero(type: DataType.float64);
      check(zero == zeroPoly).isTrue;

      final negZero = CompressedPolynomial<double>(
        [0, 5],
        [-0.0, 2.0],
        type: DataType.float64,
      );
      check(negZero.termCount).equals(1);
      check(negZero[0].isNegative).isFalse;
    });

    test('construction from map and parallel lists', () {
      final p1 = CompressedPolynomial<double>.fromMap({
        1000: 5.0,
        0: -2.0,
        50: 0.0,
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

      final p2 = CompressedPolynomial<int>(
        [0, 10, 10, 20],
        [1, 2, 3, 4],
        type: DataType.int32,
      );
      check(p2.degree).equals(20);
      check(p2[10]).equals(5);
      check(p2.termCount).equals(3);

      final p3 = CompressedPolynomial<int>(
        [5, 5],
        [3, -3],
        type: DataType.int32,
      );
      check(p3.degree).equals(-1);
      check(p3.termCount).equals(0);

      check(() => CompressedPolynomial<int>([1, 2], [1]))
          .throws<ArgumentError>();
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
      check(pComp == pSparse).isTrue;
    });
  });

  group('CompressedPolynomial evaluation and calculus', () {
    test('high-degree sparse evaluation including Complex.zero', () {
      final p = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        10000: 1.0,
      }, type: DataType.float64);

      check(p.evaluate(0.0)).equals(-1.0);
      check(p.evaluate(1.0)).equals(0.0);
      check(p.evaluate(-1.0)).equals(0.0);
      check(p.evaluateDouble(0)).equals(-1.0);
      check(p.evaluateDouble(1)).equals(0.0);
      check(p.evaluateDouble(-1)).equals(0.0);
      check(p.evaluateDouble(1.0001)).isCloseTo(math.e - 1.0, 1e-3);

      // Zero base handles both x^0 == 1 and x^10000 == 0 cleanly
      final valZero = p.evaluateComplex(Complex.zero);
      check(valZero.a).equals(-1.0);
      check(valZero.b).equals(0.0);

      final valI = p.evaluateComplex(Complex.i);
      check(valI.a).isCloseTo(0.0, 1e-12);
      check(valI.b).isCloseTo(0.0, 1e-12);

      // Zero polynomial evaluation returns zero
      final zeroP = CompressedPolynomial<double>.zero();
      check(zeroP.evaluate(5.0)).equals(0.0);
      check(zeroP.evaluateDouble(5.0)).equals(0.0);
      check(zeroP.evaluateComplex(Complex.i)).equals(Complex.zero);
    });

    test('high-degree differentiation (with order) and integration', () {
      final p = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        10000: 1.0,
      }, type: DataType.float64);

      final dp = p.derivative();
      check(dp.degree).equals(9999);
      check(dp[9999]).equals(10000.0);
      check(p.derivative(order: 0)).equals(p);
      check(p.derivative(order: 2)[9998]).equals(10000.0 * 9999.0);
      check(p.derivative(order: 10001).isZero).isTrue;
      check(() => p.derivative(order: -1)).throws<RangeError>();

      final intDp = dp.integrate();
      check(intDp.degree).equals(10000);
      check(intDp[10000]).equals(1.0);
      check(intDp[0]).equals(0.0);

      final intP = p.integrate(5.0);
      check(intP.degree).equals(10001);
      check(intP[0]).equals(5.0);
      check(intP[1]).equals(-1.0);
      check(intP[10001]).isCloseTo(1.0 / 10001.0, 1e-12);
    });

    test('high-degree arithmetic, scaling, and negation', () {
      final p = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        10000: 1.0,
      }, type: DataType.float64);
      final q = CompressedPolynomial<double>.fromMap({
        0: 1.0,
        10000: 1.0,
      }, type: DataType.float64);

      final sum = p + q;
      check(sum.degree).equals(10000);
      check(sum.leadingCoefficient).equals(2.0);
      check(sum.termCount).equals(1);

      check((p - p).isZero).isTrue;
      check((p - q).coefficients).deepEquals([-2.0]);

      final prod = p * q;
      check(prod.degree).equals(20000);
      check(prod[20000]).equals(1.0);
      check(prod[0]).equals(-1.0);
      check(prod.termCount).equals(2);

      check(p.scale(3.0)[10000]).equals(3.0);
      check(identical(p.scale(1.0), p)).isTrue;
      check(p.scale(0.0).isZero).isTrue;
      final neg = -p;
      check(neg[10000]).equals(-1.0);
      check(neg[0]).equals(1.0);
    });
  });

  group('CompressedPolynomial division, composition, and interoperability', () {
    test('sparse division and dynamic-range preservation', () {
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
      check(div.remainder.isZero).isTrue;
      check((a / b).degree).equals(10000);
      check((a % b).isZero).isTrue;

      // Wide dynamic range: untouched 1e-5 term survives alongside 1e10 * x^100
      final wide = CompressedPolynomial<double>.fromMap({
        0: 1e-5,
        100: 1e10,
      }, type: DataType.float64);
      final x50 = CompressedPolynomial<double>.fromMap({
        50: 1.0,
      }, type: DataType.float64);
      final wideDiv = wide.divide(x50);
      check(wideDiv.quotient[50]).equals(1e10);
      check(wideDiv.remainder.degree).equals(0);
      check(wideDiv.remainder[0]).equals(1e-5);

      check(() => a.divide(CompressedPolynomial<double>.zero()))
          .throws<UnsupportedError>();
    });

    test('sparse GCD and integer ring division', () {
      final highA = CompressedPolynomial<double>.fromMap({
        0: -2.0,
        1: -1.0,
        150000: 2.0,
        150001: 1.0,
      }, type: DataType.float64);
      final highB = CompressedPolynomial<double>.fromMap({
        0: -3.0,
        1: -1.0,
        150000: 3.0,
        150001: 1.0,
      }, type: DataType.float64);
      final highGcd = highA.gcd(highB);
      check(highGcd).isA<CompressedPolynomial<double>>();
      check(highGcd.degree).equals(150000);
      check(highGcd[150000]).equals(1.0);
      check(highGcd[0]).equals(-1.0);

      final coprimeA = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        150000: 1.0,
      }, type: DataType.float64);
      final coprimeB = CompressedPolynomial<double>.fromMap({
        0: -2.0,
        150000: 1.0,
      }, type: DataType.float64);
      final coprimeGcd = coprimeA.gcd(coprimeB);
      check(coprimeGcd).isA<CompressedPolynomial<double>>();
      check(coprimeGcd.degree).equals(0);
      check(coprimeGcd[0]).equals(1.0);

      // Integer ring exact division with CompressedPolynomial
      final intNum = CompressedPolynomial<int>.fromMap({
        0: -1,
        2: 1,
      }, type: DataType.int32);
      final intDen = CompressedPolynomial<int>.fromMap({
        0: -1,
        1: 1,
      }, type: DataType.int32);
      final exactIntDiv = intNum.divide(intDen);
      check(exactIntDiv.quotient).equals(
        CompressedPolynomial<int>.fromMap({0: 1, 1: 1}, type: DataType.int32),
      );
      check(exactIntDiv.remainder.isZero).isTrue;

      final x = CompressedPolynomial<int>.fromMap({1: 1}, type: DataType.int32);
      final twoX = CompressedPolynomial<int>.fromMap({
        1: 2,
      }, type: DataType.int32);
      final intDiv = x.divide(twoX);
      check(intDiv.quotient.isZero).isTrue;
      check(intDiv.remainder).equals(x);
      check(intDen.divide(intNum).quotient.isZero).isTrue;
    });

    test('composition and powers preserve sparse representation', () {
      final p = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        2: 1.0,
      }, type: DataType.float64);
      final q = CompressedPolynomial<double>.fromMap({
        5000: 1.0,
      }, type: DataType.float64);

      final comp = p.compose(q);
      check(comp).isA<CompressedPolynomial<double>>();
      check(comp.degree).equals(10000);
      check(comp[10000]).equals(1.0);
      check(comp[0]).equals(-1.0);
      check(comp.termCount).equals(2);

      // Composing with zero polynomial keeps constant term
      check(p.compose(CompressedPolynomial<double>.zero()).coefficients)
          .deepEquals([-1.0]);
      check(CompressedPolynomial<double>.zero().compose(q).isZero).isTrue;

      // Powers preserve CompressedPolynomial
      check(p.pow(0)).isA<CompressedPolynomial<double>>();
      check(p.pow(0).coefficients).deepEquals([1.0]);
      final cubed = p.pow(3);
      check(cubed).isA<CompressedPolynomial<double>>();
      check(cubed.degree).equals(6);
      check(cubed[0]).equals(-1.0);
      check(cubed[2]).equals(3.0);
      check(cubed[4]).equals(-3.0);
      check(cubed[6]).equals(1.0);
      check(p.toCompressed()).equals(p);
    });

    test('interoperability between Dense and Compressed representations', () {
      final sparseP = CompressedPolynomial<double>.fromMap({
        0: -1.0,
        1000: 1.0,
      }, type: DataType.float64);
      final denseQ = Polynomial<double>.fromCoefficients([2.0, 3.0]);

      final sum1 = sparseP + denseQ;
      final sum2 = denseQ + sparseP;
      check(sum1 == sum2).isTrue;
      check(sum1.degree).equals(1000);
      check(sum1[1]).equals(3.0);
      check(sum1[0]).equals(1.0);

      final sparseLeft = CompressedPolynomial<int>.fromMap({
        1: 2,
        10: 5,
      }, type: DataType.int32);
      final denseRight = Polynomial<int>.fromCoefficients([
        3,
        2,
        0,
        4,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        6,
      ]);
      final diffCross = sparseLeft - denseRight;
      check(diffCross[0]).equals(-3);
      check(diffCross[1]).equals(0);
      check(diffCross[3]).equals(-4);
      check(diffCross[10]).equals(5);
      check(diffCross[11]).equals(-6);
      check(
        sparseLeft.compose(Polynomial<int>.fromCoefficients([1, 1])),
      ).equals(
        CompressedPolynomial<int>.fromMap({
          1: 2,
          10: 5,
        }, type: DataType.int32).compose(
          CompressedPolynomial<int>.fromMap({0: 1, 1: 1}, type: DataType.int32),
        ),
      );

      final prod = sparseP * denseQ;
      check(prod.degree).equals(1001);
      check(prod[1001]).equals(3.0);
      check(prod[1000]).equals(2.0);

      final pDense = Polynomial<double>.fromCoefficients([1.0, 0.0, 4.0]);
      final pSparse = Polynomial<double>.sparse({
        0: 1.0,
        2: 4.0,
      }, type: DataType.float64);
      check(pDense == pSparse).isTrue;
      check(pSparse == pDense).isTrue;
      check(pDense.hashCode).equals(pSparse.hashCode);
      check(pSparse.toDense()).isA<DensePolynomial<double>>();
      check(pSparse.toDense() == pDense).isTrue;
    });

    test('dense coefficients buffer limit and DataType mismatch errors', () {
      final pHigh = CompressedPolynomial<double>.fromMap({
        0: 1.0,
        200000: 1.0,
      }, type: DataType.float64);
      check(() => pHigh.coefficients).throws<StateError>();

      final cInt32 = CompressedPolynomial<int>([1], [2], type: DataType.int32);
      final cInt64 = CompressedPolynomial<int>([1], [2], type: DataType.int64);
      check(() => cInt32 + cInt64).throws<ArgumentError>();
      check(() => cInt32 - cInt64).throws<ArgumentError>();
      check(() => cInt32 * cInt64).throws<ArgumentError>();
      check(() => cInt32.compose(cInt64)).throws<ArgumentError>();
      check(() => cInt32.divide(cInt64)).throws<ArgumentError>();
    });
  });

  group('CompressedPolynomial formatting and roots', () {
    test('toString formatting and roots', () {
      final p = CompressedPolynomial<int>.fromMap({
        0: -1,
        10000: 1,
      }, type: DataType.int32);
      check(p.toString()).equals('x^10000 - 1');
      check(() => p.roots).throws<UnsupportedError>();

      final lin = CompressedPolynomial<double>.fromMap({
        0: -6.0,
        1: 2.0,
      }, type: DataType.float64);
      check(lin.roots[0].a).isCloseTo(3.0, 1e-9);

      final quad = CompressedPolynomial<double>.fromMap({
        0: -4.0,
        2: 1.0,
      }, type: DataType.float64);
      check(quad.roots.map((r) => r.a).toList()).unorderedEquals([2.0, -2.0]);
    });

    test('BigInt and Fraction sparse evaluation and roots', () {
      final pBig = CompressedPolynomial<BigInt>.fromMap({
        0: BigInt.from(2),
        1: BigInt.from(-3),
        2: BigInt.one,
      }, type: DataType.bigInt);
      check(pBig.evaluate(BigInt.from(4))).equals(BigInt.from(6));
      check(pBig.evaluateDouble(4)).equals(6.0);
      check(pBig.evaluateComplex(const Complex(1.0, 1.0)).a)
          .isCloseTo(-1.0, 1e-9);
      check(pBig.roots.length).equals(2);

      final pFrac = CompressedPolynomial<Fraction>.fromMap({
        0: Fraction(2),
        1: Fraction(-3),
        2: Fraction(1),
      }, type: DataType.fraction);
      check(pFrac.evaluate(Fraction(4))).equals(Fraction(6));
      check(pFrac.evaluateDouble(4)).equals(6.0);
      check(pFrac.evaluateComplex(const Complex(1.0, 1.0)).a)
          .isCloseTo(-1.0, 1e-9);
      check(pFrac.roots.length).equals(2);
    });
  });
}
