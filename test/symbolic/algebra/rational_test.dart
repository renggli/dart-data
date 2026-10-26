import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('numerator and denominator', () {
    test(
      'extracts numerator and denominator of rational numbers and products',
      () {
        final frac = Expr.parse('3 / 7');
        check(frac.numerator).equals(IntegerNumber.of(3));
        check(frac.denominator).equals(IntegerNumber.of(7));

        final ratExpr = Expr.parse('(x + 1) / (x - 1)');
        check(ratExpr.numerator.toString()).equals('1 + x');
        check(ratExpr.denominator.toString()).equals('-1 + x');

        final multi = Expr.parse('2 * (x + 1) / (3 * (x - 1) * (x + 2)^2)');
        check(multi.numerator.toString()).equals('2 * (1 + x)');
        check(multi.denominator.toString())
            .equals('3 * (-1 + x) * (2 + x) ^ 2');

        final invPow = Expr.parse('1 / (x + 1)^3');
        check(invPow.numerator).equals(IntegerNumber.one);
        check(invPow.denominator.toString()).equals('(1 + x) ^ 3');

        final poly = Expr.parse('x^2 + 2*x + 1');
        check(poly.numerator.toString()).equals('1 + 2 * x + x ^ 2');
        check(poly.denominator).equals(IntegerNumber.one);
      },
    );
  });

  group('together and cancel', () {
    test('combines fractions over a least common denominator', () {
      final e1 = Expr.parse('1 / x + 1 / (x + 1)');
      check(e1.together().toString()).equals('(1 + 2 * x) / (x * (1 + x))');

      final e2 = Expr.parse('1 / (x^2 - 1) + 1 / (x - 1)');
      check(e2.together().toString()).equals('(2 + x) / ((-1 + x) * (1 + x))');

      final e3 = Expr.parse('1 / (2 * x) + 1 / (3 * x^2)');
      check(e3.together().toString()).equals('1/6 * (2 + 3 * x) / x ^ 2');

      final compound = Expr.parse('(1 + 1 / x) / (1 - 1 / x^2)');
      check(compound.together().toString()).equals('x / (-1 + x)');
    });

    test('cancels common polynomial and numeric factors', () {
      final e1 = Expr.parse('(x^2 - 1) / (x^2 + 2*x + 1)');
      check(e1.cancel().toString()).equals('(-1 + x) / (1 + x)');

      final e2 = Expr.parse('(2*x^2 - 2) / (4*x - 4)');
      check(e2.cancel().toString()).equals('1/2 * (1 + x)');

      final e3 = Expr.parse('x^2 + 2*x + 1');
      check(e3.cancel().toString()).equals('1 + 2 * x + x ^ 2');

      // Powers of rational expressions
      final ePow = Expr.parse('((x^2 - 1) / (x + 1))^2');
      check(ePow.cancel().toString()).equals('(-1 + x) ^ 2');
    });
  });

  group('collect', () {
    test('collects multivariate additive terms by powers of a variable', () {
      final e1 = Expr.parse('a * x^2 + b * x^2 + c * x + d * x + 5');
      check(e1.collect('x').toString())
          .equals('5 + (c + d) * x + (a + b) * x ^ 2');

      final e2 = Expr.parse('(a + 1) * x - a * x + y');
      check(e2.collect('x').toString()).equals('y + x');

      final e3 = Expr.parse('(a*x + b*x) / (c*x^2 + d*x^2 + 1)');
      check(e3.collect('x').toString())
          .equals('x * (a + b) / (1 + (c + d) * x ^ 2)');
    });
  });

  group('polynomialDivide', () {
    test(
      'computes exact quotient and remainder for univariate polynomials',
      () {
        final p1 = Expr.parse('x^3 + 2*x^2 - x - 2');
        final d1 = Expr.parse('x - 1');
        final res1 = p1.polynomialDivide(d1, 'x');
        check(res1.quotient.toString()).equals('2 + 3 * x + x ^ 2');
        check(res1.remainder).equals(IntegerNumber.zero);

        final p2 = Expr.parse('x^3 + 1');
        final d2 = Expr.parse('x^2 + 1');
        final res2 = p2.polynomialDivide(d2, 'x');
        check(res2.quotient.toString()).equals('x');
        check(res2.remainder.toString()).equals('1 - x');

        // Verify identity P = Q * D + R
        final checkIdentity = (res2.quotient * d2 + res2.remainder - p2)
            .expand()
            .simplify();
        check(checkIdentity).equals(IntegerNumber.zero);

        // Degree of dividend < degree of divisor
        final low = Expr.parse('x + 1').polynomialDivide(d2, 'x');
        check(low.quotient).equals(IntegerNumber.zero);
        check(low.remainder.toString()).equals('1 + x');

        // Constant divisor
        final constDiv = Expr.parse('2*x + 4')
            .polynomialDivide(IntegerNumber.two, 'x');
        check(constDiv.quotient.toString()).equals('2 + x');
        check(constDiv.remainder).equals(IntegerNumber.zero);

        // Zero dividend
        final zeroDiv = IntegerNumber.zero.polynomialDivide(d1, 'x');
        check(zeroDiv.quotient).equals(IntegerNumber.zero);
        check(zeroDiv.remainder).equals(IntegerNumber.zero);
      },
    );

    test('throws ArgumentError on division by zero or non-polynomials', () {
      final p = Expr.parse('x^2 + 1');
      check(() => p.polynomialDivide(IntegerNumber.zero, 'x'))
          .throws<ArgumentError>();
      check(() => Expr.parse('sin(x)').polynomialDivide(p, 'x'))
          .throws<ArgumentError>();
      check(() => p.polynomialDivide(Expr.parse('1 / x'), 'x'))
          .throws<ArgumentError>();
    });
  });

  group('apart (partial fraction decomposition)', () {
    test('decomposes distinct linear factors', () {
      final e1 = Expr.parse('1 / (x^2 - 1)');
      final pf1 = e1.apart('x');
      check(pf1.toString()).equals('1/2 / (-1 + x) - 1/2 / (1 + x)');
      check((pf1.together() - e1.cancel()).cancel()).equals(IntegerNumber.zero);

      final e2 = Expr.parse('(5*x - 3) / ((x - 1) * (x + 3))');
      final pf2 = e2.apart('x');
      check((pf2.together() - e2.cancel()).cancel()).equals(IntegerNumber.zero);
      check(pf2.toString()).equals('1/2 / (-1 + x) + 9/2 / (3 + x)');
    });

    test('decomposes repeated linear factors', () {
      final e1 = Expr.parse('(2*x + 3) / (x + 1)^2');
      final pf1 = e1.apart('x');
      check(pf1.toString()).equals('(1 + x) ^ (-2) + 2 / (1 + x)');
      check((pf1.together() - e1.cancel()).cancel()).equals(IntegerNumber.zero);

      final e2 = Expr.parse('(3*x^2 - 4*x + 5) / ((x - 1) * (x + 1)^2)');
      final pf2 = e2.apart('x');
      check((pf2.together() - e2.cancel()).cancel()).equals(IntegerNumber.zero);
    });

    test('decomposes irreducible quadratic and improper rational functions', () {
      final e1 = Expr.parse('(x^2 + 2*x + 3) / ((x - 1) * (x^2 + 1))');
      final pf1 = e1.apart('x');
      check(pf1.toString()).equals('3 / (-1 + x) - 2 * x / (1 + x ^ 2)');
      check((pf1.together() - e1.cancel()).cancel()).equals(IntegerNumber.zero);

      // Improper rational function with polynomial quotient + partial fractions
      final e2 = Expr.parse('(x^3 + 2) / (x^2 - 1)');
      final pf2 = e2.apart('x');
      check(pf2.toString()).equals('x + 3/2 / (-1 + x) - 1/2 / (1 + x)');
      check((pf2.together() - e2.cancel()).cancel()).equals(IntegerNumber.zero);

      // Constant denominator, single irreducible factor, and scalar/symbolic constant factors
      check(Expr.parse('(2*x + 4) / 2').apart('x').toString()).equals('2 + x');
      check(Expr.parse('(x^2 + x + 1) / (x + 1)').apart('x').toString())
          .equals('x + 1 / (1 + x)');
      check(Expr.parse('1 / (2 * a * (x^2 - 1))').apart('x').toString())
          .equals('1/4 / (a * (-1 + x)) - 1/4 / (a * (1 + x))');

      // Positive power of rational in together, negative coefficient in collect, and multi-factor coeff/var
      check(Expr.parse('((x + 1) / (x - 1))^2').together().toString())
          .equals('(1 + x) ^ 2 / (-1 + x) ^ 2');
      check(Expr.parse('-x + a * b * x * sin(x)').collect('x').toString())
          .equals('-x + a * b * x * sin(x)');
      check(Expr.parse('x / 0').apart('x')).equals(Constant.undefined);

      // Polynomial division by zero throws ArgumentError
      check(() => const Variable('x').polynomialDivide(IntegerNumber.zero, 'x'))
          .throws<ArgumentError>();

      // cancel with positive power of rational
      final posPow = Pow(Expr.parse('(x + 1) / (x - 1)'), IntegerNumber.of(2));
      check(posPow.cancel().toString()).equals('(1 + x) ^ 2 / (-1 + x) ^ 2');

      // apart with degree >= 2 polynomial factor in denominator
      final eCubic = Expr.parse('1 / ((x^3 + x + 1) * (x + 1))');
      final pfCubic = eCubic.apart('x');
      check(pfCubic.together().cancel().toString())
          .equals(eCubic.cancel().toString());

      // together with negative and fractional denominators
      final eNegDen = Expr.parse('x / (-2 * y) + 3 / (y / 3)');
      check(eNegDen.together().toString()).contains('y');

      // assumptions propagation through together, collect, cancel, apart
      const posAssump = Assumptions(domains: {'a': VariableDomain.positive});
      check(
        Expr.parse('sqrt(a^2) / x + 1 / x')
            .together(assumptions: posAssump)
            .toString(),
      ).equals('(1 + a) / x');
      check(
        Expr.parse('sqrt(a^2) * x + x')
            .collect('x', assumptions: posAssump)
            .toString(),
      ).equals('(1 + a) * x');
      check(
        Expr.parse('sqrt(a^2) / (x^2 - 1)')
            .apart('x', assumptions: posAssump)
            .toString(),
      ).equals('1/2 * a / (-1 + x) - 1/2 * a / (1 + x)');
    });
  });
}
