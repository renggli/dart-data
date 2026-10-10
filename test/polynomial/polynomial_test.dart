import 'package:checks/checks.dart';
import 'package:data/polynomial.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Polynomial', () {
    test('construction and basic properties', () {
      final p0 = Polynomial<int>.zero(type: DataType.int32);
      check(p0.degree).equals(-1);
      check(p0.leadingCoefficient).equals(0);
      check(p0[0]).equals(0);

      // P(x) = 3 + 2x - 5x^2
      final p1 = Polynomial<double>.fromCoefficients([
        3.0,
        2.0,
        -5.0,
      ], type: DataType.float64);
      check(p1.degree).equals(2);
      check(p1.leadingCoefficient).equals(-5.0);
      check(p1[0]).equals(3.0);
      check(p1[1]).equals(2.0);
      check(p1[2]).equals(-5.0);
      check(p1[3]).equals(0.0);
    });

    test('evaluation Horner method', () {
      // P(x) = 2 - 3x + x^2 = (x - 1)(x - 2)
      final poly = Polynomial<double>.fromCoefficients([
        2.0,
        -3.0,
        1.0,
      ], type: DataType.float64);
      check(poly.evaluate(0.0)).equals(2.0);
      check(poly.evaluate(1.0)).equals(0.0);
      check(poly.evaluate(2.0)).equals(0.0);
      check(poly.evaluate(3.0)).equals(2.0);
      check(poly.evaluateDouble(4)).equals(6.0);

      // Complex evaluation
      final complexVal = poly.evaluateComplex(const Complex(1.0, 1.0));
      // P(1 + i) = (1 + i - 1)(1 + i - 2) = i * (i - 1) = -1 - i
      check(complexVal.a).isCloseTo(-1.0, 1e-9);
      check(complexVal.b).isCloseTo(-1.0, 1e-9);
    });

    test(
      'arithmetic: addition, subtraction, negation, scaling, multiplication',
      () {
        // P = 1 + 2x, Q = 3 - x + 4x^2
        final polyP = Polynomial<double>.fromCoefficients([
          1.0,
          2.0,
        ], type: DataType.float64);
        final polyQ = Polynomial<double>.fromCoefficients([
          3.0,
          -1.0,
          4.0,
        ], type: DataType.float64);

        final sum = polyP + polyQ;
        check(sum.coefficients).deepEquals([4.0, 1.0, 4.0]);

        final diff = polyP - polyQ;
        check(diff.coefficients).deepEquals([-2.0, 3.0, -4.0]);

        final neg = -polyP;
        check(neg.coefficients).deepEquals([-1.0, -2.0]);

        final scaled = polyP.scale(3.0);
        check(scaled.coefficients).deepEquals([3.0, 6.0]);

        // (1 + 2x) * (3 - x + 4x^2) = 3 + (-1 + 6)x + (4 - 2)x^2 + 8x^3 = 3 + 5x + 2x^2 + 8x^3
        final prod = polyP * polyQ;
        check(prod.coefficients).deepEquals([3.0, 5.0, 2.0, 8.0]);
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
      check(div.quotient.coefficients).deepEquals([3.0, 1.0, 1.0]);
      check(div.remainder.coefficients[0]).isCloseTo(5.0, 1e-9);
      check((a / b).coefficients).deepEquals([3.0, 1.0, 1.0]);
      check((a % b).coefficients[0]).isCloseTo(5.0, 1e-9);
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
      check(gcd.degree).equals(1);
      check(gcd[1]).isCloseTo(1.0, 1e-9); // Monic
      check(gcd[0]).isCloseTo(-2.0, 1e-9);
    });

    test('differentiation and integration', () {
      // P(x) = 5 + 4x + 3x^2 + 2x^3
      final poly = Polynomial<double>.fromCoefficients([
        5.0,
        4.0,
        3.0,
        2.0,
      ], type: DataType.float64);

      // P'(x) = 4 + 6x + 6x^2
      final deriv = poly.differentiate();
      check(deriv.coefficients).deepEquals([4.0, 6.0, 6.0]);

      // \int P'(x) dx with C=5 gives P(x)
      final anti = deriv.integrate(5.0);
      check(anti.coefficients).deepEquals([5.0, 4.0, 3.0, 2.0]);
    });

    test('roots: linear, quadratic real, quadratic complex, cubic', () {
      // Linear: 2 + 4x = 0 => x = -0.5
      final p1 = Polynomial<double>.fromCoefficients([
        2.0,
        4.0,
      ], type: DataType.float64);
      check(p1.roots.length).equals(1);
      check(p1.roots[0].a).isCloseTo(-0.5, 1e-9);
      check(p1.roots[0].b).isCloseTo(0.0, 1e-9);

      // Quadratic real: x^2 - 5x + 6 = (x - 2)(x - 3)
      final p2 = Polynomial<double>.fromCoefficients([
        6.0,
        -5.0,
        1.0,
      ], type: DataType.float64);
      final roots2 = p2.roots;
      check(roots2.length).equals(2);
      final realParts2 = roots2.map((root) => root.a).toList()..sort();
      check(realParts2[0]).isCloseTo(2.0, 1e-9);
      check(realParts2[1]).isCloseTo(3.0, 1e-9);

      // Quadratic complex: x^2 + 4 = 0 => x = +- 2i
      final p3 = Polynomial<double>.fromCoefficients([
        4.0,
        0.0,
        1.0,
      ], type: DataType.float64);
      final roots3 = p3.roots;
      check(roots3.length).equals(2);
      check(roots3[0].a).isCloseTo(0.0, 1e-9);
      check(roots3[0].b.abs()).isCloseTo(2.0, 1e-9);

      // Cubic: (x - 1)(x - 2)(x - 3) = -6 + 11x - 6x^2 + x^3
      final p4 = Polynomial<double>.fromRoots([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float64);
      final roots4 = p4.roots;
      check(roots4.length).equals(3);
      final realParts4 = roots4.map((root) => root.a).toList()..sort();
      check(realParts4[0]).isCloseTo(1.0, 1e-6);
      check(realParts4[1]).isCloseTo(2.0, 1e-6);
      check(realParts4[2]).isCloseTo(3.0, 1e-6);
    });

    test('Polynomial factories, division errors, integration on zero, and toString', () {
      final zero = Polynomial<double>.zero();
      check(zero.degree).equals(-1);
      check(zero.toString()).equals('0');

      final gen = Polynomial<int>.generate(2, (exp) => exp + 1);
      check(gen.coefficients).deepEquals([1, 2, 3]);

      // Division by zero polynomial throws
      final poly = Polynomial<int>.fromCoefficients([1, 2]);
      final zeroInt = Polynomial<int>.zero();
      check(() => poly.divide(zeroInt)).throws<UnsupportedError>();

      // degA < degB
      final small = Polynomial<int>.fromCoefficients([1]);
      final big = Polynomial<int>.fromCoefficients([1, 2, 3]);
      final div = small.divide(big);
      check(div.quotient.degree).equals(-1);
      check(div.remainder.coefficients).deepEquals([1]);

      // Coprime gcd
      final p1 = Polynomial<double>.fromCoefficients([1.0, 1.0]); // x + 1
      final p2 = Polynomial<double>.fromCoefficients([2.0, 1.0]); // x + 2
      final gcd = p1.gcd(p2);
      check(gcd.degree).equals(0);
      check(gcd[0]).isCloseTo(1.0, 1e-9);

      // Integration on zero polynomial and without constant
      final intZero = zero.integrate(2.0);
      check(intZero.coefficients).deepEquals([2.0]);
      final intDefault = poly.integrate();
      check(intDefault[0]).equals(0);

      // toString formatting
      final constP = Polynomial<int>.fromCoefficients([5]);
      check(constP.toString()).equals('5');
      final poly1 = Polynomial<int>.fromCoefficients([1, 1]);
      check(poly1.toString()).equals('x + 1');
      final poly3 = Polynomial<int>.fromCoefficients([3, 0, 2, 1]);
      check(poly3.toString()).equals('x^3 + 2x^2 + 3');
    });
  });
}
