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

      // BigInt coefficients exceeding 64-bit int are preserved and factored
      final bigInt = Integer.big(BigInt.two.pow(70));
      final bigNum = IntegerNumber(bigInt);
      final bigDen = RationalNumber.of(Integer.one, bigInt);
      check(factorUnivariatePoly(PolyQ([IntegerNumber.one, bigNum]), 'x'))
          .isA<Add>();
      check(factorUnivariatePoly(PolyQ([IntegerNumber.one, bigDen]), 'x'))
          .isA<Mul>();

      // Large quadratic difference of squares with BigInt coefficients
      final big140 = Integer.big(BigInt.two.pow(140));
      final polyBigSq = PolyQ([
        IntegerNumber(-big140),
        IntegerNumber.zero,
        IntegerNumber.one,
      ]);
      final factoredBigSq = factorUnivariatePoly(polyBigSq, 'x');
      check(
        factoredBigSq.toString(),
      ).equals('(-1180591620717411303424 + x) * (1180591620717411303424 + x)');

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
      final quadFactors = factorQuadraticInX(
        Integer.one,
        const Integer(-4),
        'x',
      );
      check(quadFactors.length).equals(2);

      // Irreducible degree 5 with content 1 and content 2
      check(Expr.parse('x^5 + x + 1').factor().toString())
          .equals('1 + x + x ^ 5');
      check(Expr.parse('2*x^5 + 2*x + 2').factor().toString())
          .equals('2 * (1 + x + x ^ 5)');
    });

    test('number-theoretic helpers (divisors)', () {
      check(const Integer(12).gcd(const Integer(18))).equals(const Integer(6));
      check(Integer.zero.lcm(const Integer(5))).equals(Integer.zero);
      check(const Integer(4).lcm(const Integer(6))).equals(const Integer(12));
      check(const Integer(-4).isqrt()).isNull();
      check(Integer.zero.isqrt()).equals(Integer.zero);
      check(const Integer(16).isqrt()).equals(const Integer(4));
      check(const Integer(15).isqrt()).isNull();
      check(divisors(Integer.zero)).isEmpty();
      check(divisors(const Integer(12))).deepEquals([
        const Integer(1),
        const Integer(2),
        const Integer(3),
        const Integer(4),
        const Integer(6),
        const Integer(12),
      ]);
    });
  });
}
