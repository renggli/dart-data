import 'package:data/polynomial.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Polynomial', () {
    test('construction and basic properties', () {
      final p0 = Polynomial<int>.zero(type: DataType.int32);
      expect(p0.degree, -1);
      expect(p0.leadingCoefficient, 0);
      expect(p0[0], 0);

      // P(x) = 3 + 2x - 5x^2
      final p1 = Polynomial<double>.fromCoefficients([
        3.0,
        2.0,
        -5.0,
      ], type: DataType.float64);
      expect(p1.degree, 2);
      expect(p1.leadingCoefficient, -5.0);
      expect(p1[0], 3.0);
      expect(p1[1], 2.0);
      expect(p1[2], -5.0);
      expect(p1[3], 0.0);
    });

    test('evaluation Horner method', () {
      // P(x) = 2 - 3x + x^2 = (x - 1)(x - 2)
      final p = Polynomial<double>.fromCoefficients([
        2.0,
        -3.0,
        1.0,
      ], type: DataType.float64);
      expect(p.evaluate(0.0), 2.0);
      expect(p.evaluate(1.0), 0.0);
      expect(p.evaluate(2.0), 0.0);
      expect(p.evaluate(3.0), 2.0);
      expect(p.evaluateDouble(4), 6.0);

      // Complex evaluation
      final complexVal = p.evaluateComplex(const Complex(1.0, 1.0));
      // P(1 + i) = (1 + i - 1)(1 + i - 2) = i * (i - 1) = -1 - i
      expect(complexVal.a, closeTo(-1.0, 1e-9));
      expect(complexVal.b, closeTo(-1.0, 1e-9));
    });

    test(
      'arithmetic: addition, subtraction, negation, scaling, multiplication',
      () {
        // P = 1 + 2x, Q = 3 - x + 4x^2
        final p = Polynomial<double>.fromCoefficients([
          1.0,
          2.0,
        ], type: DataType.float64);
        final q = Polynomial<double>.fromCoefficients([
          3.0,
          -1.0,
          4.0,
        ], type: DataType.float64);

        final sum = p + q;
        expect(sum.coefficients, [4.0, 1.0, 4.0]);

        final diff = p - q;
        expect(diff.coefficients, [-2.0, 3.0, -4.0]);

        final neg = -p;
        expect(neg.coefficients, [-1.0, -2.0]);

        final scaled = p.scale(3.0);
        expect(scaled.coefficients, [3.0, 6.0]);

        // (1 + 2x) * (3 - x + 4x^2) = 3 + (-1 + 6)x + (4 - 2)x^2 + 8x^3 = 3 + 5x + 2x^2 + 8x^3
        final prod = p * q;
        expect(prod.coefficients, [3.0, 5.0, 2.0, 8.0]);
      },
    );

    test('division and modulo', () {
      // Dividend: A(x) = x^3 - 2x^2 - 4
      // Divisor:  B(x) = x - 3
      // A(x) = (x^2 + x + 3)(x - 3) + 5
      final a = Polynomial<double>.fromCoefficients([
        -4.0,
        0.0,
        -2.0,
        1.0,
      ], type: DataType.float64);
      final b = Polynomial<double>.fromCoefficients([
        -3.0,
        1.0,
      ], type: DataType.float64);

      final div = a.divide(b);
      expect(div.quotient.coefficients, [3.0, 1.0, 1.0]);
      expect(div.remainder.coefficients[0], closeTo(5.0, 1e-9));
      expect((a / b).coefficients, [3.0, 1.0, 1.0]);
      expect((a % b).coefficients[0], closeTo(5.0, 1e-9));
    });

    test('polynomial GCD', () {
      // A(x) = (x - 1)(x - 2) = 2 - 3x + x^2
      // B(x) = (x - 2)(x - 3) = 6 - 5x + x^2
      // GCD = x - 2
      final a = Polynomial<double>.fromRoots([
        1.0,
        2.0,
      ], type: DataType.float64);
      final b = Polynomial<double>.fromRoots([
        2.0,
        3.0,
      ], type: DataType.float64);

      final gcd = a.gcd(b);
      expect(gcd.degree, 1);
      expect(gcd[1], closeTo(1.0, 1e-9)); // Monic
      expect(gcd[0], closeTo(-2.0, 1e-9));
    });

    test('differentiation and integration', () {
      // P(x) = 5 + 4x + 3x^2 + 2x^3
      final p = Polynomial<double>.fromCoefficients([
        5.0,
        4.0,
        3.0,
        2.0,
      ], type: DataType.float64);

      // P'(x) = 4 + 6x + 6x^2
      final deriv = p.differentiate();
      expect(deriv.coefficients, [4.0, 6.0, 6.0]);

      // \int P'(x) dx with C=5 gives P(x)
      final anti = deriv.integrate(5.0);
      expect(anti.coefficients, [5.0, 4.0, 3.0, 2.0]);
    });

    test('roots: linear, quadratic real, quadratic complex, cubic', () {
      // Linear: 2 + 4x = 0 => x = -0.5
      final p1 = Polynomial<double>.fromCoefficients([
        2.0,
        4.0,
      ], type: DataType.float64);
      expect(p1.roots.length, 1);
      expect(p1.roots[0].a, closeTo(-0.5, 1e-9));
      expect(p1.roots[0].b, closeTo(0.0, 1e-9));

      // Quadratic real: x^2 - 5x + 6 = (x - 2)(x - 3)
      final p2 = Polynomial<double>.fromCoefficients([
        6.0,
        -5.0,
        1.0,
      ], type: DataType.float64);
      final roots2 = p2.roots;
      expect(roots2.length, 2);
      final realParts2 = roots2.map((r) => r.a).toList()..sort();
      expect(realParts2[0], closeTo(2.0, 1e-9));
      expect(realParts2[1], closeTo(3.0, 1e-9));

      // Quadratic complex: x^2 + 4 = 0 => x = +- 2i
      final p3 = Polynomial<double>.fromCoefficients([
        4.0,
        0.0,
        1.0,
      ], type: DataType.float64);
      final roots3 = p3.roots;
      expect(roots3.length, 2);
      expect(roots3[0].a, closeTo(0.0, 1e-9));
      expect(roots3[0].b.abs(), closeTo(2.0, 1e-9));

      // Cubic: (x - 1)(x - 2)(x - 3) = -6 + 11x - 6x^2 + x^3
      final p4 = Polynomial<double>.fromRoots([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float64);
      final roots4 = p4.roots;
      expect(roots4.length, 3);
      final realParts4 = roots4.map((r) => r.a).toList()..sort();
      expect(realParts4[0], closeTo(1.0, 1e-6));
      expect(realParts4[1], closeTo(2.0, 1e-6));
      expect(realParts4[2], closeTo(3.0, 1e-6));
    });
  });
}
