import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('Expr.factor() - Univariate Polynomials over Q[x]', () {
    test('linear polynomials', () {
      check((x - 2).factor()).equals(x - 2);
      check((const RationalNumber(2) * x + 4).factor())
          .equals(const RationalNumber(2) * (x + 2));
    });

    test('monic quadratics with distinct rational roots', () {
      check((x * x - const RationalNumber(5) * x + 6).factor())
          .equals((x - 2) * (x - 3));
      check((x * x - 4).factor()).equals((x - 2) * (x + 2));
    });

    test('non-monic quadratics', () {
      check(
        (const RationalNumber(2) * x * x + const RationalNumber(5) * x + 3)
            .factor(),
      ).equals((x + 1) * (const RationalNumber(2) * x + 3));
      check(
        (const RationalNumber(6) * x * x + const RationalNumber(11) * x + 4)
            .factor(),
      ).equals(
        (const RationalNumber(2) * x + 1) * (const RationalNumber(3) * x + 4),
      );
    });

    test('perfect square quadratics', () {
      check((x * x - const RationalNumber(2) * x + 1).factor())
          .equals(Pow(x - 1, const RationalNumber(2)));
      check((x * x - const RationalNumber(6) * x + 9).factor())
          .equals(Pow(x - 3, const RationalNumber(2)));
      check(
        (const RationalNumber(4) * x * x - const RationalNumber(12) * x + 9)
            .factor(),
      ).equals(Pow(const RationalNumber(2) * x - 3, const RationalNumber(2)));
    });

    test('scalar content factored out', () {
      check(
        (const RationalNumber(2) * x * x - const RationalNumber(10) * x + 12)
            .factor(),
      ).equals(const RationalNumber(2) * (x - 2) * (x - 3));
      check((-x * x + const RationalNumber(5) * x - 6).factor())
          .equals(-((x - 2) * (x - 3)));
    });

    test('fractional coefficients', () {
      final expr =
          const RationalNumber(1, 2) * x * x -
          const RationalNumber(5, 2) * x +
          const RationalNumber(3);
      check(expr.factor())
          .equals(const RationalNumber(1, 2) * (x - 2) * (x - 3));
    });

    test('zero root / monomial extraction', () {
      check(
        (x * x * x -
                const RationalNumber(5) * x * x +
                const RationalNumber(6) * x)
            .factor(),
      ).equals(x * (x - 2) * (x - 3));
      check(
        (const RationalNumber(2) * x * x * x - const RationalNumber(8) * x)
            .factor(),
      ).equals(const RationalNumber(2) * x * (x - 2) * (x + 2));
      check((x.pow(4) - const RationalNumber(4) * x * x).factor())
          .equals(const Pow(x, RationalNumber(2)) * (x - 2) * (x + 2));
    });

    test('cubic polynomials with rational roots', () {
      check(
        (x.pow(3) -
                const RationalNumber(6) * x.pow(2) +
                const RationalNumber(11) * x -
                6)
            .factor(),
      ).equals((x - 1) * (x - 2) * (x - 3));
      check(
        (x.pow(3) -
                const RationalNumber(3) * x.pow(2) +
                const RationalNumber(3) * x -
                1)
            .factor(),
      ).equals(Pow(x - 1, const RationalNumber(3)));
    });

    test('difference and sum of cubes', () {
      check((x.pow(3) - 8).factor())
          .equals((x - 2) * (x.pow(2) + const RationalNumber(2) * x + 4));
      check((x.pow(3) + 8).factor())
          .equals((x + 2) * (x.pow(2) - const RationalNumber(2) * x + 4));
    });

    test('quartic polynomials with rational roots', () {
      check((x.pow(4) - const RationalNumber(5) * x.pow(2) + 4).factor())
          .equals((x - 1) * (x + 1) * (x - 2) * (x + 2));
      check((x.pow(4) - 1).factor()).equals((x - 1) * (x + 1) * (x.pow(2) + 1));
    });

    test('irreducible polynomials over Q[x]', () {
      check((x.pow(2) + 1).factor()).equals(x.pow(2) + 1);
      check((x.pow(2) + x + 1).factor()).equals(x.pow(2) + x + 1);
      check((x.pow(3) + x + 1).factor()).equals(x.pow(3) + x + 1);
    });
  });

  group('Expr.factor() - Multivariate & Grouping', () {
    test('4-term grouping', () {
      final expr =
          x * y + const RationalNumber(2) * x + const RationalNumber(3) * y + 6;
      check(expr.factor()).equals((x + 3) * (y + 2));
    });

    test('multivariate monomial GCD', () {
      final expr =
          const RationalNumber(3) * x * x * y +
          const RationalNumber(6) * x * y * y;
      check(expr.factor()).equals(
        const RationalNumber(3) * x * y * (x + const RationalNumber(2) * y),
      );
    });

    test('difference of squares multivariate', () {
      final expr =
          const RationalNumber(4) * x * x - const RationalNumber(9) * y * y;
      check(expr.factor()).equals(
        (const RationalNumber(2) * x - const RationalNumber(3) * y) *
            (const RationalNumber(2) * x + const RationalNumber(3) * y),
      );
    });
  });

  group(
    'Expr.factor() - Round-Trip Invariant: factor().expand() == expand()',
    () {
      final testExpressions = [
        x * x - const RationalNumber(5) * x + 6,
        const RationalNumber(2) * x * x + const RationalNumber(5) * x + 3,
        const RationalNumber(6) * x * x + const RationalNumber(11) * x + 4,
        x.pow(3) -
            const RationalNumber(6) * x.pow(2) +
            const RationalNumber(11) * x -
            6,
        const RationalNumber(2) * x.pow(3) - const RationalNumber(8) * x,
        x.pow(4) - const RationalNumber(5) * x.pow(2) + 4,
        x.pow(3) - 8,
        (x - 2) * (x - 3),
        x * y + const RationalNumber(2) * x + const RationalNumber(3) * y + 6,
        const RationalNumber(3) * x * x * y +
            const RationalNumber(6) * x * y * y,
      ];

      for (final expr in testExpressions) {
        test('round-trip for $expr', () {
          check(expr.factor().expand()).equals(expr.expand());
        });
      }
    },
  );

  group('Expr.factor() - Rational Functions and Powers', () {
    test('rational function quotients cancel like factors', () {
      final num = x * x - 4;
      final den = x * x - const RationalNumber(5) * x + 6;
      final quotient = (num / den).factor();
      check(quotient).equals((x + 2) / (x - 3));
    });

    test('powers of factored expressions', () {
      final expr = Pow((x - 2) * (x - 3), const RationalNumber(2));
      final expected =
          Pow(x - 2, const RationalNumber(2)) *
          Pow(x - 3, const RationalNumber(2));
      check(expr.factor()).equals(expected);
    });
  });
}
