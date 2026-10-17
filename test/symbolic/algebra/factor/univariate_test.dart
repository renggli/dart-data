import 'package:checks/checks.dart';
import 'package:data/src/symbolic/algebra/factor/univariate.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Univariate polynomial extraction (extractPoly)', () {
    test('extracts rational polynomials and rejects non-polynomials', () {
      final p0 = extractPoly(IntegerNumber.zero, 'x');
      check(p0).isNotNull();
      check(p0!.degree).equals(0);

      final p = extractPoly(Expr.parse('1/2 * x^2 - 3 * x + 5'), 'x');
      check(p).isNotNull();
      check(p!.degree).equals(2);

      // Non-polynomial or multivariate expressions return null
      check(extractPoly(Expr.parse('1.5 * x + 1'), 'x')).isNull();
      check(extractPoly(Expr.parse('x^(-1) + 1'), 'x')).isNull();
      check(extractPoly(Expr.parse('x + y'), 'x')).isNull();
      check(extractPoly(Expr.parse('sin(x) + 1'), 'x')).isNull();
    });
  });

  group('Univariate polynomial factorization over Q[x]', () {
    test('factors constant, linear, quadratic, and rational-coefficient polynomials', () {
      check(factorUnivariatePoly(PolyQ([IntegerNumber.of(7)]), 'x'))
          .equals(IntegerNumber.of(7));

      // Linear with content > 1 and negative leading coeff
      check(Expr.parse('-2 * x - 4').factor().toString())
          .equals('-2 * (2 + x)');
      check(Expr.parse('x + 3').factor().toString()).equals('3 + x');

      // Pure monomial with zero roots via factorUnivariatePoly
      final pureMonomial = extractPoly(Expr.parse('3 * x^2'), 'x')!;
      check(factorUnivariatePoly(pureMonomial, 'x').toString())
          .equals('3 * x ^ 2');

      // BigInt coefficients exceeding 64-bit int return unfactored polynomial expression
      final bigInt = Integer.big(BigInt.two.pow(70));
      final bigNum = IntegerNumber(bigInt);
      final bigDen = RationalNumber.of(Integer.one, bigInt);
      check(factorUnivariatePoly(PolyQ([IntegerNumber.one, bigNum]), 'x'))
          .isA<Add>();
      check(factorUnivariatePoly(PolyQ([IntegerNumber.one, bigDen]), 'x'))
          .isA<Add>();

      // Cubic reducing to linear after root extraction: x^2 * (2*x - 3)
      check(Expr.parse('2 * x^3 - 3 * x^2').factor().toString())
          .equals('x ^ 2 * (-3 + 2 * x)');

      // Irreducible quadratic with content > 1
      check(Expr.parse('2 * x^2 + 2').factor().toString())
          .equals('2 * (1 + x ^ 2)');

      // Rational coefficients: 1/2 * x^2 - 1/2 -> 1/2 * (-1 + x) * (1 + x)
      check(Expr.parse('1/2 * x^2 - 1/2').factor().toString())
          .equals('1/2 * (-1 + x) * (1 + x)');
    });

    test('factors biquadratics, square-free polynomials, and irreducible higher degrees', () {
      // Biquadratic factoring into irreducible quadratics: x^4 + 3*x^2 + 2 = (1 + x^2)*(2 + x^2)
      check(Expr.parse('x^4 + 3*x^2 + 2').factor().toString())
          .equals('(1 + x ^ 2) * (2 + x ^ 2)');

      // Direct factorQuadraticInX with perfect-square discriminant
      final quadFactors = factorQuadraticInX(1, -4, 'x');
      check(quadFactors.length).equals(2);

      // Irreducible degree 5 with content 1 and content 2
      check(Expr.parse('x^5 + x + 1').factor().toString())
          .equals('1 + x + x ^ 5');
      check(Expr.parse('2*x^5 + 2*x + 2').factor().toString())
          .equals('2 * (1 + x + x ^ 5)');
    });

    test('number-theoretic helpers (gcd, lcm, integerSqrt, divisors)', () {
      check(gcd(12, 18)).equals(6);
      check(lcm(0, 5)).equals(0);
      check(lcm(4, 6)).equals(12);
      check(integerSqrt(-4)).isNull();
      check(integerSqrt(0)).equals(0);
      check(integerSqrt(16)).equals(4);
      check(integerSqrt(15)).isNull();
      check(divisors(0)).isEmpty();
      check(divisors(12)).deepEquals([1, 2, 3, 4, 6, 12]);
    });
  });
}
