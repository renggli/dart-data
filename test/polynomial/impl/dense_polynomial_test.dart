import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('DensePolynomial construction and properties', () {
    test('construction and zero representation', () {
      final zero = DensePolynomial<double>.fromCoefficients(
        const [],
        type: DataType.float64,
      );
      check(zero.degree).equals(-1);
      check(zero.leadingCoefficient).equals(0.0);
      check(zero.termCount).equals(0);
      check(zero.coefficients).isEmpty();
      check(zero[0]).equals(0.0);
      check(zero[10]).equals(0.0);
      check(zero.toString()).equals('0');

      // Trailing zeros are trimmed
      final trimmed = DensePolynomial<int>.fromCoefficients([
        1,
        2,
        0,
        0,
      ], type: DataType.int32);
      check(trimmed.degree).equals(1);
      check(trimmed.coefficients).deepEquals([1, 2]);
      check(trimmed.leadingCoefficient).equals(2);
      check(trimmed.termCount).equals(2);
    });

    test('indexing, nonZeroTerms, and toMap', () {
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
    });
  });

  group('DensePolynomial evaluation', () {
    test('evaluates real, double, and complex values', () {
      // P(x) = 2 - 3x + x^2 = (x - 1)(x - 2)
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

      // Complex evaluation: P(1 + i) = -1 - i
      final cVal = poly.evaluateComplex(const Complex(1.0, 1.0));
      check(cVal.a).isCloseTo(-1.0, 1e-10);
      check(cVal.b).isCloseTo(-1.0, 1e-10);
    });
  });

  group('DensePolynomial arithmetic', () {
    test('addition, subtraction, negation, scaling', () {
      final a = DensePolynomial<int>.fromCoefficients([
        1,
        2,
        3,
      ], type: DataType.int32);
      final b = DensePolynomial<int>.fromCoefficients([
        3,
        -2,
      ], type: DataType.int32);

      final sum = a + b;
      check(sum.coefficients).deepEquals([4, 0, 3]);

      final diff = a - b;
      check(diff.coefficients).deepEquals([-2, 4, 3]);

      final neg = -a;
      check(neg.coefficients).deepEquals([-1, -2, -3]);

      final scaled = a.scale(2);
      check(scaled.coefficients).deepEquals([2, 4, 6]);

      final zeroScale = a.scale(0);
      check(zeroScale.degree).equals(-1);
    });

    test('multiplication', () {
      // (1 + 2x) * (3 - x) = 3 + 5x - 2x^2
      final a = DensePolynomial<double>.fromCoefficients([
        1.0,
        2.0,
      ], type: DataType.float64);
      final b = DensePolynomial<double>.fromCoefficients([
        3.0,
        -1.0,
      ], type: DataType.float64);

      final prod = a * b;
      check(prod.degree).equals(2);
      check(prod.coefficients).deepEquals([3.0, 5.0, -2.0]);
    });
  });

  group('DensePolynomial calculus and transformations', () {
    test('derivative and integrate', () {
      // P(x) = 1 + 3x + 4x^2
      final poly = DensePolynomial<double>.fromCoefficients([
        1.0,
        3.0,
        4.0,
      ], type: DataType.float64);

      final deriv = poly.derivative();
      check(deriv.coefficients).deepEquals([3.0, 8.0]);

      final integ = poly.integrate(5.0);
      check(integ.coefficients).deepEquals([5.0, 1.0, 1.5, 4.0 / 3.0]);
    });

    test('division and compose', () {
      // A(x) = x^2 - 1, B(x) = x - 1 -> Q = x + 1, R = 0
      final a = DensePolynomial<double>.fromCoefficients([
        -1.0,
        0.0,
        1.0,
      ], type: DataType.float64);
      final b = DensePolynomial<double>.fromCoefficients([
        -1.0,
        1.0,
      ], type: DataType.float64);
      final res = a.divide(b);
      check(res.quotient.coefficients).deepEquals([1.0, 1.0]);
      check(res.remainder.coefficients).isEmpty();

      // Compose: P(x) = x^2, Q(x) = 2x + 1 -> (2x + 1)^2 = 1 + 4x + 4x^2
      final poly = DensePolynomial<double>.fromCoefficients([
        0.0,
        0.0,
        1.0,
      ], type: DataType.float64);
      final q = DensePolynomial<double>.fromCoefficients([
        1.0,
        2.0,
      ], type: DataType.float64);
      final composed = poly.compose(q);
      check(composed.coefficients).deepEquals([1.0, 4.0, 4.0]);
    });
  });

  group('DensePolynomial conversions and representations', () {
    test('toCompressed conversion', () {
      final dense = DensePolynomial<double>.fromCoefficients([
        1.0,
        0.0,
        2.0,
      ], type: DataType.float64);

      final comp = dense.toCompressed();
      check(comp).isA<CompressedPolynomial<double>>();
      check(comp.toMap()).deepEquals({0: 1.0, 2: 2.0});
    });
  });
}
