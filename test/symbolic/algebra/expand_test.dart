import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  group('ExpandExtension - basic polynomials', () {
    test('monic binomial product: (x - 2) * (x - 3)', () {
      final expr = (x - 2) * (x - 3);
      final expected = x.pow(2) - const RationalNumber(5) * x + 6;
      check(expr.expand()).equals(expected);
    });

    test('difference of squares: (x + 2) * (x - 2)', () {
      final expr = (x + 2) * (x - 2);
      final expected = x.pow(2) - 4;
      check(expr.expand()).equals(expected);
    });

    test('non-monic product: (2*x + 1) * (3*x + 4)', () {
      final expr =
          (const RationalNumber(2) * x + 1) * (const RationalNumber(3) * x + 4);
      final expected =
          const RationalNumber(6) * x.pow(2) + const RationalNumber(11) * x + 4;
      check(expr.expand()).equals(expected);
    });

    test('scaled sum distribution: 3 * (x + 2)', () {
      final expr = const RationalNumber(3) * (x + 2);
      final expected = const RationalNumber(3) * x + 6;
      check(expr.expand()).equals(expected);
    });

    test('negated sum distribution: -(x - 2)', () {
      final expr = -(x - 2);
      final expected = -x + 2;
      check(expr.expand()).equals(expected);
    });

    test('three-factor product: (x - 1) * (x - 2) * (x - 3)', () {
      final expr = (x - 1) * (x - 2) * (x - 3);
      final expected =
          x.pow(3) -
          const RationalNumber(6) * x.pow(2) +
          const RationalNumber(11) * x -
          6;
      check(expr.expand()).equals(expected);
    });

    test('four-factor product: (x - 1) * (x - 2) * (x - 3) * (x - 4)', () {
      final expr = (x - 1) * (x - 2) * (x - 3) * (x - 4);
      final expected =
          x.pow(4) -
          const RationalNumber(10) * x.pow(3) +
          const RationalNumber(35) * x.pow(2) -
          const RationalNumber(50) * x +
          24;
      check(expr.expand()).equals(expected);
    });
  });

  group('ExpandExtension - multivariate polynomials', () {
    test('bivariate difference of squares: (x + y) * (x - y)', () {
      final expr = (x + y) * (x - y);
      final expected = x.pow(2) - y.pow(2);
      check(expr.expand()).equals(expected);
    });

    test('bivariate binomial square: (x + y)^2', () {
      final expr = (x + y).pow(2);
      final expected = x.pow(2) + const RationalNumber(2) * (x * y) + y.pow(2);
      check(expr.expand()).equals(expected);
    });

    test('bivariate non-monic product: (x + 2*y) * (3*x - 4*y)', () {
      final expr =
          (x + const RationalNumber(2) * y) *
          (const RationalNumber(3) * x - const RationalNumber(4) * y);
      final expected =
          const RationalNumber(3) * x.pow(2) +
          const RationalNumber(2) * (x * y) -
          const RationalNumber(8) * y.pow(2);
      check(expr.expand()).equals(expected);
    });

    test('trivariate multinomial square: (x + y + z)^2', () {
      final expr = (x + y + z).pow(2);
      final expected =
          x.pow(2) +
          const RationalNumber(2) * (x * y) +
          const RationalNumber(2) * (x * z) +
          y.pow(2) +
          const RationalNumber(2) * (y * z) +
          z.pow(2);
      check(expr.expand()).equals(expected);
    });

    test('trivariate grouping product: ((x + y) + z) * ((x + y) - z)', () {
      final expr = ((x + y) + z) * ((x + y) - z);
      final expected =
          x.pow(2) + const RationalNumber(2) * (x * y) + y.pow(2) - z.pow(2);
      check(expr.expand()).equals(expected);
    });
  });

  group('ExpandExtension - integer powers of sums', () {
    test('power zero: (x + y)^0', () {
      final expr = (x + y).pow(0);
      check(expr.expand()).equals(const RationalNumber(1));
    });

    test('power one: (x + y)^1', () {
      final expr = (x + y).pow(1);
      check(expr.expand()).equals(x + y);
    });

    test('power two: (x + 1)^2', () {
      final expr = (x + 1).pow(2);
      final expected = x.pow(2) + const RationalNumber(2) * x + 1;
      check(expr.expand()).equals(expected);
    });

    test('power three: (x + 1)^3', () {
      final expr = (x + 1).pow(3);
      final expected =
          x.pow(3) +
          const RationalNumber(3) * x.pow(2) +
          const RationalNumber(3) * x +
          1;
      check(expr.expand()).equals(expected);
    });

    test('power four: (x + y)^4', () {
      final expr = (x + y).pow(4);
      final expected =
          x.pow(4) +
          const RationalNumber(4) * (x.pow(3) * y) +
          const RationalNumber(6) * (x.pow(2) * y.pow(2)) +
          const RationalNumber(4) * (x * y.pow(3)) +
          y.pow(4);
      check(expr.expand()).equals(expected);
    });

    test('power of monomial: (2*x)^3', () {
      final expr = (const RationalNumber(2) * x).pow(3);
      final expected = const RationalNumber(8) * x.pow(3);
      check(expr.expand()).equals(expected);
    });

    test('power of product: (x * y)^2', () {
      final expr = (x * y).pow(2);
      final expected = x.pow(2) * y.pow(2);
      check(expr.expand()).equals(expected);
    });

    test('nested powers: ((x + 1)^2)^2', () {
      final expr = (x + 1).pow(2).pow(2);
      final expected =
          x.pow(4) +
          const RationalNumber(4) * x.pow(3) +
          const RationalNumber(6) * x.pow(2) +
          const RationalNumber(4) * x +
          1;
      check(expr.expand()).equals(expected);
    });
  });

  group('ExpandExtension - non-integer and negative powers', () {
    test('negative integer power: (x + y)^(-1)', () {
      final expr = (x + y).pow(-1);
      final expected = const RationalNumber(1) / (x + y);
      check(expr.expand()).equals(expected);
    });

    test('negative square: (x + y)^(-2)', () {
      final expr = (x + y).pow(-2);
      final expected =
          const RationalNumber(1) /
          (x.pow(2) + const RationalNumber(2) * (x * y) + y.pow(2));
      check(expr.expand()).equals(expected);
    });

    test('fractional power unmodified: (x + 1)^(1/2)', () {
      final expr = (x + 1).pow(const RationalNumber(1, 2));
      check(expr.expand()).equals(expr);
    });

    test('fractional power with reducible base: ((x + 1) * (x - 1))^(1/2)', () {
      final expr = ((x + 1) * (x - 1)).pow(const RationalNumber(1, 2));
      final expected = (x.pow(2) - 1).pow(const RationalNumber(1, 2));
      check(expr.expand()).equals(expected);
    });
  });

  group('ExpandExtension - deep subexpression expansion', () {
    test('sine argument', () {
      final expr = Sin((x + 1).pow(2));
      final expected = Sin(x.pow(2) + const RationalNumber(2) * x + 1);
      check(expr.expand()).equals(expected);
    });

    test('cosine argument', () {
      final expr = Cos((x + y) * (x - y));
      final expected = Cos(x.pow(2) - y.pow(2));
      check(expr.expand()).equals(expected);
    });

    test('exponential argument', () {
      final expr = Exp((x + 1).pow(3));
      final expected = Exp(
        x.pow(3) +
            const RationalNumber(3) * x.pow(2) +
            const RationalNumber(3) * x +
            1,
      );
      check(expr.expand()).equals(expected);
    });

    test('logarithm argument', () {
      final expr = Ln((x + 2) * (x - 2));
      final expected = Ln(x.pow(2) - 4);
      check(expr.expand()).equals(expected);
    });

    test('absolute value argument', () {
      final expr = Abs((x - 1).pow(2));
      final expected = Abs(x.pow(2) - const RationalNumber(2) * x + 1);
      check(expr.expand()).equals(expected);
    });

    test('hyperbolic cosine argument', () {
      final expr = Cosh((x + y).pow(2));
      final expected = Cosh(
        x.pow(2) + const RationalNumber(2) * (x * y) + y.pow(2),
      );
      check(expr.expand()).equals(expected);
    });
  });

  group('ExpandExtension - algebraic cancellation & properties', () {
    test('exact cancellation to zero', () {
      final expr =
          (x + 1).pow(2) - (x.pow(2) + const RationalNumber(2) * x + 1);
      check(expr.expand()).equals(const RationalNumber(0));
    });

    test('difference cancellation to zero', () {
      final expr = (x + y) * (x - y) - (x.pow(2) - y.pow(2));
      check(expr.expand()).equals(const RationalNumber(0));
    });

    test('idempotence on composite expression', () {
      final expr =
          (x + 2) * (x - 3) * (const RationalNumber(2) * x + 1) +
          (x + y).pow(3);
      final first = expr.expand();
      final second = first.expand();
      check(second).equals(first);
    });

    test('evaluation parity across 50 random valuation points', () {
      final expr =
          (const RationalNumber(2) * x - const RationalNumber(3) * y + 1) *
          (x + const RationalNumber(2) * y - 4);
      final expanded = expr.expand();
      final rng = math.Random(12345);
      for (var i = 0; i < 50; i++) {
        final ctx = {
          'x': (rng.nextDouble() - 0.5) * 20.0,
          'y': (rng.nextDouble() - 0.5) * 20.0,
        };
        final v1 = expr.evaluate(ctx);
        final v2 = expanded.evaluate(ctx);
        check((v1 - v2).abs()).isLessThan(1e-9);
      }
    });
  });
}
