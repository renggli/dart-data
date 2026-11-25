import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('DensePolynomial construction and properties', () {
    test('zero, trailing-zero trimming, and negative-zero normalization', () {
      final zero = DensePolynomial<double>.fromCoefficients(
        const [],
        type: DataType.float64,
      );
      check(zero.degree).equals(-1);
      check(zero.isZero).isTrue;
      check(zero.isConstant).isTrue;
      check(zero.leadingCoefficient).equals(0.0);
      check(zero.termCount).equals(0);
      check(zero.coefficients).isEmpty;
      check(zero[0]).equals(0.0);
      check(zero[10]).equals(0.0);
      check(zero.toString()).equals('0');

      final trimmed = DensePolynomial<int>.fromCoefficients([
        1,
        2,
        0,
        0,
      ], type: DataType.int32);
      check(trimmed.degree).equals(1);
      check(trimmed.isZero).isFalse;
      check(trimmed.isConstant).isFalse;
      check(trimmed.coefficients).deepEquals([1, 2]);
      check(trimmed.leadingCoefficient).equals(2);
      check(trimmed.termCount).equals(2);

      final negZero = DensePolynomial<double>.fromCoefficients([
        -0.0,
        1.0,
      ], type: DataType.float64);
      check(negZero[0].isNegative).isFalse;
      check(negZero.toString()).equals('x');
    });

    test('indexing and nonZeroTerms', () {
      final poly = DensePolynomial<double>.fromCoefficients([
        3.0,
        0.0,
        -5.0,
      ], type: DataType.float64);
      check(poly.degree).equals(2);
      check(poly[0]).equals(3.0);
      check(poly[1]).equals(0.0);
      check(poly[2]).equals(-5.0);
      check(poly[3]).equals(0.0);
      check(poly[-1]).equals(0.0);
      check(poly.termCount).equals(2);
      check(poly.coefficients).deepEquals([3.0, 0.0, -5.0]);
      check(poly.nonZeroTerms.map((t) => (t.exponent, t.coefficient)).toList())
          .deepEquals([(0, 3.0), (2, -5.0)]);
    });
  });

  group('DensePolynomial evaluation', () {
    test('evaluates real, double, and complex values', () {
      final poly = DensePolynomial<double>.fromCoefficients([
        2.0,
        -3.0,
        1.0,
      ], type: DataType.float64);
      check(poly.evaluate(0.0)).equals(2.0);
      check(poly.evaluate(1.0)).equals(0.0);
      check(poly.evaluate(2.0)).equals(0.0);
      check(poly.evaluate(3.0)).equals(2.0);
      check(poly.evaluateDouble(4)).equals(6.0);

      final cVal = poly.evaluateComplex(const Complex(1.0, 1.0));
      check(cVal.a).isCloseTo(-1.0, 1e-10);
      check(cVal.b).isCloseTo(-1.0, 1e-10);
    });
  });

  group('DensePolynomial arithmetic and division', () {
    test('addition, subtraction, negation, scaling, multiplication', () {
      final a = DensePolynomial<int>.fromCoefficients([
        1,
        2,
        3,
      ], type: DataType.int32);
      final b = DensePolynomial<int>.fromCoefficients([
        3,
        -2,
      ], type: DataType.int32);

      check((a + b).coefficients).deepEquals([4, 0, 3]);
      check((a - b).coefficients).deepEquals([-2, 4, 3]);
      check((-a).coefficients).deepEquals([-1, -2, -3]);
      check(
        (-DensePolynomial<int>.fromCoefficients(
          const [],
          type: DataType.int32,
        )).isZero,
      ).isTrue;
      check(a.scale(2).coefficients).deepEquals([2, 4, 6]);
      check(identical(a.scale(1), a)).isTrue;
      check(a.scale(0).degree).equals(-1);
      check(
        (DensePolynomial<double>.fromCoefficients([1.0, 2.0]) *
                DensePolynomial<double>.fromCoefficients([3.0, -1.0]))
            .coefficients,
      ).deepEquals([3.0, 5.0, -2.0]);
    });

    test(
      'interoperability with CompressedPolynomial and type mismatch errors',
      () {
        final dense = DensePolynomial<double>.fromCoefficients([
          1.0,
          2.0,
        ], type: DataType.float64);
        final sparse = CompressedPolynomial<double>.fromMap({
          0: 3.0,
          5: 4.0,
        }, type: DataType.float64);

        check((dense + sparse)[5]).equals(4.0);
        check((dense - sparse)[5]).equals(-4.0);
        check((dense * sparse)[6]).equals(8.0);
        check(dense.toCompressed()).isA<CompressedPolynomial<double>>();

        final int64Poly = DensePolynomial<int>.fromCoefficients([
          1,
          2,
        ], type: DataType.int64);
        final int32Poly = DensePolynomial<int>.fromCoefficients([
          1,
          2,
        ], type: DataType.int32);
        check(() => int32Poly + int64Poly).throws<ArgumentError>();
        check(() => int32Poly - int64Poly).throws<ArgumentError>();
        check(() => int32Poly * int64Poly).throws<ArgumentError>();
        check(() => int32Poly.compose(int64Poly)).throws<ArgumentError>();
        check(() => int32Poly.divide(int64Poly)).throws<ArgumentError>();
      },
    );

    test(
      'FFT multiplication preserves non-finite coefficients via fallback',
      () {
        final coeffs1 = List<double>.filled(35, 1.0);
        coeffs1[5] = double.infinity;
        final coeffs2 = List<double>.filled(35, 1.0);
        final p1 = DensePolynomial<double>.fromCoefficients(coeffs1);
        final p2 = DensePolynomial<double>.fromCoefficients(coeffs2);
        final prod = p1 * p2;
        check(prod.degree).equals(68);
        check(prod[5].isInfinite).isTrue;
      },
    );

    test('division cancels leading residual and preserves untouched small terms', () {
      // Exact leading elimination even when dividing by non-dyadic float 3.0
      final dividend = DensePolynomial<double>.fromCoefficients([
        -1.0,
        0.0,
        1.0,
      ], type: DataType.float64);
      final divisor = DensePolynomial<double>.fromCoefficients([
        -3.0,
        3.0,
      ], type: DataType.float64);
      final res = dividend.divide(divisor);
      check(res.remainder.degree).equals(-1);
      check(res.quotient[0]).isCloseTo(1.0 / 3.0, 1e-12);
      check(res.quotient[1]).isCloseTo(1.0 / 3.0, 1e-12);

      // Untouched constant term 1e-5 must survive alongside leading 1e10 * x^2
      final wideRange = DensePolynomial<double>.fromCoefficients([
        1e-5,
        0.0,
        1e10,
      ], type: DataType.float64);
      final x = DensePolynomial<double>.fromCoefficients([
        0.0,
        1.0,
      ], type: DataType.float64);
      final wideDiv = wideRange.divide(x);
      check(wideDiv.quotient[1]).equals(1e10);
      check(wideDiv.remainder.degree).equals(0);
      check(wideDiv.remainder[0]).equals(1e-5);
    });
  });

  group('DensePolynomial calculus and composition', () {
    test('derivative with order, integrate, and compose', () {
      final poly = DensePolynomial<double>.fromCoefficients([
        1.0,
        3.0,
        4.0,
      ], type: DataType.float64);

      check(poly.derivative(order: 0)).equals(poly);
      check(poly.derivative().coefficients).deepEquals([3.0, 8.0]);
      check(poly.derivative(order: 2).coefficients).deepEquals([8.0]);
      check(poly.derivative(order: 3).isZero).isTrue;
      check(() => poly.derivative(order: -1)).throws<RangeError>();

      final integ = poly.integrate(5.0);
      check(integ.coefficients).deepEquals([5.0, 1.0, 1.5, 4.0 / 3.0]);
      check(
        DensePolynomial<double>.fromCoefficients(const [])
            .integrate(5.0)
            .coefficients,
      ).deepEquals([5.0]);
      check(identical(poly.toDense(), poly)).isTrue;

      final sq = DensePolynomial<double>.fromCoefficients([
        0.0,
        0.0,
        1.0,
      ], type: DataType.float64);
      final q = DensePolynomial<double>.fromCoefficients([
        1.0,
        2.0,
      ], type: DataType.float64);
      check(sq.compose(q).coefficients).deepEquals([1.0, 4.0, 4.0]);
    });
  });
}
