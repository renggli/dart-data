import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const a = Variable('a');
  const b = Variable('b');
  const c = Variable('c');
  const d = Variable('d');
  const e = Variable('e');
  const f = Variable('f');
  const w = Variable('w');
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

  group('ExpandExtension - binomial expansions with negative cross terms', () {
    test('(x - y)^n for n = 2..8 expands without (x * y)^k', () {
      final powers = [2, 3, 4, 5, 6, 7, 8];
      for (final n in powers) {
        final expr = Pow(x - y, RationalNumber(n));
        final expanded = expr.expand();

        _assertNoPowerOfProduct(expanded, '(x - y)^$n');
        check(expanded.toString()).not((it) => it.contains('(x * y)'));

        for (final (vx, vy) in [(2.0, 3.0), (-1.5, 2.5), (0.7, -1.2)]) {
          final expected = math.pow(vx - vy, n).toDouble();
          final actual = _evaluateExpr(expanded, {'x': vx, 'y': vy});
          check((actual - expected).abs()).isLessThan(1e-7);
        }
      }
    });

    test('(2x - 3y)^n for n = 2..5 expands with correct negative cross coefficients', () {
      final base = const RationalNumber(2) * x - const RationalNumber(3) * y;
      for (final n in [2, 3, 4, 5]) {
        final expr = Pow(base, RationalNumber(n));
        final expanded = expr.expand();

        _assertNoPowerOfProduct(expanded, '(2x - 3y)^$n');
        check(expanded.toString()).not((it) => it.contains('(x * y)'));
        check(expr.factor().expand()).equals(expanded);

        for (final (vx, vy) in [(1.0, 1.0), (2.0, -1.0), (-0.5, 1.5)]) {
          final expected = math.pow(2.0 * vx - 3.0 * vy, n).toDouble();
          final actual = _evaluateExpr(expanded, {'x': vx, 'y': vy});
          check((actual - expected).abs()).isLessThan(1e-6);
        }
      }
    });

    test(
      'fractional coefficient binomials (x/2 - y/3)^2 and (2x/3 - 3y/4)^3',
      () {
        final b1 =
            const RationalNumber(1, 2) * x - const RationalNumber(1, 3) * y;
        final e1 = Pow(b1, const RationalNumber(2)).expand();
        _assertNoPowerOfProduct(e1, '(x/2 - y/3)^2');
        check(e1.toString()).not((it) => it.contains('(x * y)'));

        final b2 =
            const RationalNumber(2, 3) * x - const RationalNumber(3, 4) * y;
        final e2 = Pow(b2, const RationalNumber(3)).expand();
        _assertNoPowerOfProduct(e2, '(2x/3 - 3y/4)^3');
        check(e2.toString()).not((it) => it.contains('(x * y)'));
      },
    );
  });

  group('ExpandExtension - differences of powers & higher powers', () {
    test(
      '(x^2 - y^2)^n for n = 2..5 expands to clean monomials without (x * y)^k',
      () {
        final p2 = Pow(x.pow(2) - y.pow(2), const RationalNumber(2));
        final e2 = p2.expand();
        _assertNoPowerOfProduct(e2, '(x^2 - y^2)^2');
        check(e2.toString()).equals('x ^ 4 + y ^ 4 - 2 * x ^ 2 * y ^ 2');
        check(p2.factor().expand()).equals(e2);

        final p3 = Pow(x.pow(2) - y.pow(2), const RationalNumber(3));
        final e3 = p3.expand();
        _assertNoPowerOfProduct(e3, '(x^2 - y^2)^3');
        check(e3.toString()).not((it) => it.contains('(x * y)'));
        check(p3.factor().expand()).equals(e3);

        final p4 = Pow(x.pow(2) - y.pow(2), const RationalNumber(4));
        final e4 = p4.expand();
        _assertNoPowerOfProduct(e4, '(x^2 - y^2)^4');
        check(e4.toString()).not((it) => it.contains('(x * y)'));
        check(p4.factor().expand()).equals(e4);

        final p5 = Pow(x.pow(2) - y.pow(2), const RationalNumber(5));
        final e5 = p5.expand();
        _assertNoPowerOfProduct(e5, '(x^2 - y^2)^5');
        check(e5.toString()).not((it) => it.contains('(x * y)'));
        check(p5.factor().expand()).equals(e5);
      },
    );

    test('(x^3 - y^3)^n for n = 2, 3 expands without (x * y)^k', () {
      final p2 = Pow(x.pow(3) - y.pow(3), const RationalNumber(2));
      final e2 = p2.expand();
      _assertNoPowerOfProduct(e2, '(x^3 - y^3)^2');
      check(e2.toString()).equals('x ^ 6 + y ^ 6 - 2 * x ^ 3 * y ^ 3');
      check(p2.factor().expand()).equals(e2);

      final p3 = Pow(x.pow(3) - y.pow(3), const RationalNumber(3));
      final e3 = p3.expand();
      _assertNoPowerOfProduct(e3, '(x^3 - y^3)^3');
      check(e3.toString()).not((it) => it.contains('(x * y)'));
      check(p3.factor().expand()).equals(e3);
    });

    test('(x^4 - y^4)^2 expands without (x * y)^k', () {
      final p = Pow(x.pow(4) - y.pow(4), const RationalNumber(2));
      final e = p.expand();
      _assertNoPowerOfProduct(e, '(x^4 - y^4)^2');
      check(e.toString()).equals('x ^ 8 + y ^ 8 - 2 * x ^ 4 * y ^ 4');
      check(p.factor().expand()).equals(e);
    });

    test(
      'asymmetric powers differences: (x^2 - y^3)^2 and (3x^2 - 2y^3)^2',
      () {
        final p1 = Pow(x.pow(2) - y.pow(3), const RationalNumber(2));
        final e1 = p1.expand();
        _assertNoPowerOfProduct(e1, '(x^2 - y^3)^2');
        check(e1.toString()).equals('y ^ 6 - 2 * x ^ 2 * y ^ 3 + x ^ 4');
        check(p1.factor().expand()).equals(e1);

        final p2 = Pow(
          const RationalNumber(3) * x.pow(2) -
              const RationalNumber(2) * y.pow(3),
          const RationalNumber(2),
        );
        final e2 = p2.expand();
        _assertNoPowerOfProduct(e2, '(3x^2 - 2y^3)^2');
        check(e2.toString())
            .equals('4 * y ^ 6 - 12 * x ^ 2 * y ^ 3 + 9 * x ^ 4');
        check(p2.factor().expand()).equals(e2);
      },
    );
  });

  group('ExpandExtension - multinomial expansions with negative terms', () {
    test('(x - y - z)^2 and (x - y - z)^3 expansion', () {
      final p2 = Pow(x - y - z, const RationalNumber(2));
      final e2 = p2.expand();
      _assertNoPowerOfProduct(e2, '(x - y - z)^2');
      check(e2.toString()).not((it) => it.contains('(x * y)'));
      check(e2.toString()).not((it) => it.contains('(x * z)'));
      check(e2.toString()).not((it) => it.contains('(y * z)'));
      check(p2.factor().expand()).equals(e2);

      final p3 = Pow(x - y - z, const RationalNumber(3));
      final e3 = p3.expand();
      _assertNoPowerOfProduct(e3, '(x - y - z)^3');
      check(p3.factor().expand()).equals(e3);
    });

    test('(x^2 - y^2 - z^2)^2 and (x^2 - y^2 + z^2)^2 expansion', () {
      final p1 = Pow(x.pow(2) - y.pow(2) - z.pow(2), const RationalNumber(2));
      final e1 = p1.expand();
      _assertNoPowerOfProduct(e1, '(x^2 - y^2 - z^2)^2');
      check(e1.toString()).not((it) => it.contains('(x * y)'));
      check(e1.toString()).not((it) => it.contains('(x * z)'));
      check(e1.toString()).not((it) => it.contains('(y * z)'));
      check(p1.factor().expand()).equals(e1);

      final p2 = Pow(x.pow(2) - y.pow(2) + z.pow(2), const RationalNumber(2));
      final e2 = p2.expand();
      _assertNoPowerOfProduct(e2, '(x^2 - y^2 + z^2)^2');
      check(p2.factor().expand()).equals(e2);
    });

    test('quadrinomial (x - y - z - w)^2 and (x^2 - y^2 - z^2 - w^2)^2', () {
      final p1 = Pow(x - y - z - w, const RationalNumber(2));
      final e1 = p1.expand();
      _assertNoPowerOfProduct(e1, '(x - y - z - w)^2');
      check(p1.factor().expand()).equals(e1);

      final p2 = Pow(
        x.pow(2) - y.pow(2) - z.pow(2) - w.pow(2),
        const RationalNumber(2),
      );
      final e2 = p2.expand();
      _assertNoPowerOfProduct(e2, '(x^2 - y^2 - z^2 - w^2)^2');
      check(p2.factor().expand()).equals(e2);
    });
  });

  group('ExpandExtension - negative monomials & products of differences', () {
    test('standalone negative monomials do not un-expand', () {
      final m1 = -(x.pow(2) * y.pow(2));
      final e1 = m1.expand();
      _assertNoPowerOfProduct(e1, '-(x^2 * y^2)');
      check(e1.toString()).equals('-(x ^ 2 * y ^ 2)');

      final m2 = -(x.pow(3) * y.pow(3));
      final e2 = m2.expand();
      _assertNoPowerOfProduct(e2, '-(x^3 * y^3)');
      check(e2.toString()).equals('-(x ^ 3 * y ^ 3)');

      final m3 = -(x.pow(4) * y.pow(4));
      final e3 = m3.expand();
      _assertNoPowerOfProduct(e3, '-(x^4 * y^4)');
      check(e3.toString()).equals('-(x ^ 4 * y ^ 4)');

      final m4 = const RationalNumber(-2) * x.pow(2) * y.pow(2);
      final e4 = m4.expand();
      _assertNoPowerOfProduct(e4, '-2 * x^2 * y^2');
      check(e4.toString()).equals('-2 * x ^ 2 * y ^ 2');

      final m5 = -(x.pow(2) * y.pow(2) * z.pow(2));
      final e5 = m5.expand();
      _assertNoPowerOfProduct(e5, '-(x^2 * y^2 * z^2)');
      check(e5.toString()).equals('-(x ^ 2 * y ^ 2 * z ^ 2)');
    });

    test('products of differences: (x - y)(x + y) and higher powers', () {
      final p1 = (x - y) * (x + y);
      check(p1.expand().toString()).equals('x ^ 2 - y ^ 2');

      final p2 = (x.pow(2) - y.pow(2)) * (x.pow(2) + y.pow(2));
      check(p2.expand().toString()).equals('x ^ 4 - y ^ 4');

      final p3 = (x.pow(3) - y.pow(3)) * (x.pow(3) + y.pow(3));
      check(p3.expand().toString()).equals('x ^ 6 - y ^ 6');

      final p4 = (x.pow(2) - y.pow(2)) * (z.pow(2) - w.pow(2));
      final e4 = p4.expand();
      _assertNoPowerOfProduct(e4, '(x^2 - y^2)(z^2 - w^2)');
      check(e4.toString()).not((it) => it.contains('(x * z)'));
      check(e4.toString()).not((it) => it.contains('(x * w)'));
      check(e4.toString()).not((it) => it.contains('(y * z)'));
      check(e4.toString()).not((it) => it.contains('(y * w)'));
      check(p4.factor().expand()).equals(e4);
    });

    test('compounded powers of differences: (x - y)^2 * (x + y)^2', () {
      final p =
          Pow(x - y, const RationalNumber(2)) *
          Pow(x + y, const RationalNumber(2));
      final e = p.expand();
      _assertNoPowerOfProduct(e, '(x - y)^2 * (x + y)^2');
      check(e.toString()).equals('x ^ 4 + y ^ 4 - 2 * x ^ 2 * y ^ 2');
      check(p.factor().expand()).equals(e);
    });

    test('compounded powers of differences: (x^2 - y^2)^2 * (x^2 + y^2)^2', () {
      final p =
          Pow(x.pow(2) - y.pow(2), const RationalNumber(2)) *
          Pow(x.pow(2) + y.pow(2), const RationalNumber(2));
      final e = p.expand();
      _assertNoPowerOfProduct(e, '(x^2 - y^2)^2 * (x^2 + y^2)^2');
      check(e.toString()).equals('x ^ 8 + y ^ 8 - 2 * x ^ 4 * y ^ 4');
      check(p.factor().expand()).equals(e);
    });

    test('monomial difference powers: (x^2*y^2 - 1)^2 and (1 - x^2*y^2)^2', () {
      final p1 = Pow(x.pow(2) * y.pow(2) - 1, const RationalNumber(2));
      final e1 = p1.expand();
      _assertNoPowerOfProduct(e1, '(x^2*y^2 - 1)^2');
      check(e1.toString()).equals('x ^ 4 * y ^ 4 - 2 * x ^ 2 * y ^ 2 + 1');
      check(p1.factor().expand()).equals(e1);

      final p2 = Pow(
        const RationalNumber(1) - x.pow(2) * y.pow(2),
        const RationalNumber(2),
      );
      final e2 = p2.expand();
      _assertNoPowerOfProduct(e2, '(1 - x^2*y^2)^2');
      check(e2.toString()).equals('x ^ 4 * y ^ 4 - 2 * x ^ 2 * y ^ 2 + 1');
      check(p2.factor().expand()).equals(e2);
    });

    test('monomial difference cube: (x^2*y^2 - 1)^3 and (1 - x^2*y^2)^3', () {
      final p1 = Pow(x.pow(2) * y.pow(2) - 1, const RationalNumber(3));
      final e1 = p1.expand();
      _assertNoPowerOfProduct(e1, '(x^2*y^2 - 1)^3');
      check(e1.toString())
          .equals('x ^ 6 * y ^ 6 - 3 * x ^ 4 * y ^ 4 + 3 * x ^ 2 * y ^ 2 - 1');
      check(p1.factor().expand()).equals(e1);

      final p2 = Pow(
        const RationalNumber(1) - x.pow(2) * y.pow(2),
        const RationalNumber(3),
      );
      final e2 = p2.expand();
      _assertNoPowerOfProduct(e2, '(1 - x^2*y^2)^3');
      check(
        e2.toString(),
      ).equals('-(x ^ 6 * y ^ 6) + 3 * x ^ 4 * y ^ 4 - 3 * x ^ 2 * y ^ 2 + 1');
      check(p2.factor().expand()).equals(e2);
    });

    test('cross product of distinct monomials (x^2 * y - x * y^2)^2', () {
      final p = Pow(x.pow(2) * y - x * y.pow(2), const RationalNumber(2));
      final e = p.expand();
      _assertNoPowerOfProduct(e, '(x^2 * y - x * y^2)^2');
      check(e.toString())
          .equals('x ^ 4 * y ^ 2 + x ^ 2 * y ^ 4 - 2 * x ^ 3 * y ^ 3');
      check(p.factor().expand()).equals(e);
    });
  });

  group(
    'ExpandExtension - negative powers and inverses of expanded monomials',
    () {
      test('(x - y)^(-1) does not crash or corrupt powers', () {
        final p = Pow(x - y, const RationalNumber(-1));
        final e = p.expand();
        check(e.toString()).equals('1 / (x - y)');
      });

      test('(x^2 - y^2)^(-2) round-trip factor-expand invariant holds', () {
        final p = Pow(x.pow(2) - y.pow(2), const RationalNumber(-2));
        final factored = p.factor();
        final roundTrip = factored.expand();
        final expanded = p.expand();
        check(roundTrip).equals(expanded);
        check(expanded.toString())
            .equals('1 / (x ^ 4 + y ^ 4 - 2 * (x * y) ^ 2)');
      });

      test('(x^2 - y^2)^2 / z distributes division', () {
        final p = Pow(x.pow(2) - y.pow(2), const RationalNumber(2)) / z;
        final e = p.expand();
        check(e.toString())
            .equals('x ^ 4 / z + y ^ 4 / z - 2 * (x * y) ^ 2 / z');
      });
    },
  );

  group('ExpandExtension - multi-term products', () {
    test('3-factor symbolic product: (a + b) * (c + d) * (e + f)', () {
      final expr = (a + b) * (c + d) * (e + f);
      final expanded = expr.expand();
      _checkParity(expr, expanded, vars: ['a', 'b', 'c', 'd', 'e', 'f']);
      check(expanded.expand()).equals(expanded);
    });

    test(
      '4-factor product with alternating signs: (x-1)*(x+2)*(x-3)*(x+4)',
      () {
        final expr = (x - 1) * (x + 2) * (x - 3) * (x + 4);
        final expanded = expr.expand();
        final expected =
            x.pow(4) +
            const RationalNumber(2) * x.pow(3) -
            const RationalNumber(13) * x.pow(2) -
            const RationalNumber(14) * x +
            24;
        check(expanded).equals(expected);
        _checkParity(expr, expanded, vars: ['x']);
      },
    );

    test(
      '5-factor product: (x - 1) * (x - 2) * (x - 3) * (x - 4) * (x - 5)',
      () {
        final expr = (x - 1) * (x - 2) * (x - 3) * (x - 4) * (x - 5);
        final expanded = expr.expand();
        final expected =
            x.pow(5) -
            const RationalNumber(15) * x.pow(4) +
            const RationalNumber(85) * x.pow(3) -
            const RationalNumber(225) * x.pow(2) +
            const RationalNumber(274) * x -
            120;
        check(expanded).equals(expected);
        _checkParity(expr, expanded, vars: ['x']);
      },
    );

    test('cyclical difference product: (x - y) * (y - z) * (z - x)', () {
      final expr = (x - y) * (y - z) * (z - x);
      final expanded = expr.expand();
      _checkParity(expr, expanded, vars: ['x', 'y', 'z']);
      check(expanded.expand()).equals(expanded);
    });

    test(
      'rational coefficient distribution: (1/3*x + 2/5) * (3/4*x - 5/6)',
      () {
        final expr =
            (const RationalNumber(1, 3) * x + const RationalNumber(2, 5)) *
            (const RationalNumber(3, 4) * x - const RationalNumber(5, 6));
        final expanded = expr.expand();
        final expected =
            const RationalNumber(1, 4) * x.pow(2) +
            const RationalNumber(1, 45) * x -
            const RationalNumber(1, 3);
        check(expanded).equals(expected);
        _checkParity(expr, expanded, vars: ['x']);
      },
    );

    test('mixed rational and floating-point coefficients', () {
      final expr = (x + const RealNumber(1.5)) * (x - const RationalNumber(2));
      final expanded = expr.expand();
      _checkParity(expr, expanded, vars: ['x']);
      check(expanded.expand()).equals(expanded);
    });
  });

  group('ExpandExtension - polynomial powers', () {
    test('(x + 1)^4 expansion', () {
      final expr = (x + 1).pow(4);
      final expanded = expr.expand();
      final expected =
          x.pow(4) +
          const RationalNumber(4) * x.pow(3) +
          const RationalNumber(6) * x.pow(2) +
          const RationalNumber(4) * x +
          1;
      check(expanded).equals(expected);
      _checkParity(expr, expanded, vars: ['x']);
    });

    test('(x - 1)^4 expansion with alternating signs', () {
      final expr = (x - 1).pow(4);
      final expanded = expr.expand();
      final expected =
          x.pow(4) -
          const RationalNumber(4) * x.pow(3) +
          const RationalNumber(6) * x.pow(2) -
          const RationalNumber(4) * x +
          1;
      check(expanded).equals(expected);
      _checkParity(expr, expanded, vars: ['x']);
    });

    test('(2*x - 3)^3 expansion', () {
      final expr = (const RationalNumber(2) * x - 3).pow(3);
      final expanded = expr.expand();
      final expected =
          const RationalNumber(8) * x.pow(3) -
          const RationalNumber(36) * x.pow(2) +
          const RationalNumber(54) * x -
          27;
      check(expanded).equals(expected);
      _checkParity(expr, expanded, vars: ['x']);
    });

    test('(x + y + z)^3 multinomial expansion', () {
      final expr = (x + y + z).pow(3);
      final expanded = expr.expand();
      _checkParity(expr, expanded, vars: ['x', 'y', 'z']);
      check(expanded.expand()).equals(expanded);
    });

    test('high degree power: (x + 1)^6', () {
      final expr = (x + 1).pow(6);
      final expanded = expr.expand();
      final expected =
          x.pow(6) +
          const RationalNumber(6) * x.pow(5) +
          const RationalNumber(15) * x.pow(4) +
          const RationalNumber(20) * x.pow(3) +
          const RationalNumber(15) * x.pow(2) +
          const RationalNumber(6) * x +
          1;
      check(expanded).equals(expected);
      _checkParity(expr, expanded, vars: ['x']);
    });

    test('high degree power: (x - 1)^5', () {
      final expr = (x - 1).pow(5);
      final expanded = expr.expand();
      final expected =
          x.pow(5) -
          const RationalNumber(5) * x.pow(4) +
          const RationalNumber(10) * x.pow(3) -
          const RationalNumber(10) * x.pow(2) +
          const RationalNumber(5) * x -
          1;
      check(expanded).equals(expected);
      _checkParity(expr, expanded, vars: ['x']);
    });
  });

  group('ExpandExtension - non-polynomial & transcendental expressions', () {
    test('Pythagorean identity in squared sum: (sin(x) + cos(x))^2', () {
      final expr = (const Sin(x) + const Cos(x)).pow(2);
      final expanded = expr.expand();
      _checkParity(expr, expanded, vars: ['x']);
      check(expanded.expand()).equals(expanded);
    });

    test('Hyperbolic squared sum: (cosh(x) - sinh(x))^2', () {
      final expr = (const Cosh(x) - const Sinh(x)).pow(2);
      final expanded = expr.expand();
      _checkParity(expr, expanded, vars: ['x']);
      check(expanded.expand()).equals(expanded);
    });

    test('product of exponential sums: (exp(x) + 1) * (exp(x) - 1)', () {
      final expr = (const Exp(x) + 1) * (const Exp(x) - 1);
      final expanded = expr.expand();
      _checkParity(expr, expanded, vars: ['x']);
      check(expanded.expand()).equals(expanded);
    });

    test('nested function arguments expand internally', () {
      final expr = Sin((x - 2) * (x - 3)) + Cos((x + 1).pow(3));
      final expanded = expr.expand();
      final expected =
          Cos(
            x.pow(3) +
                const RationalNumber(3) * x.pow(2) +
                const RationalNumber(3) * x +
                1,
          ) +
          Sin(x.pow(2) - const RationalNumber(5) * x + 6);
      check(expanded).equals(expected);
      _checkParity(expr, expanded, vars: ['x']);
    });

    test('deeply nested trigonometric chain', () {
      final expr = Tan(Sin((x + 1) * (x - 1)));
      final expanded = expr.expand();
      final expected = Tan(Sin(x.pow(2) - 1));
      check(expanded).equals(expected);
    });

    test('nested logarithm and exponential', () {
      final expr = Ln(Exp((x + 2).pow(2)));
      final expanded = expr.expand();
      final expected = Ln(Exp(x.pow(2) + const RationalNumber(4) * x + 4));
      check(expanded).equals(expected);
    });
  });

  group('ExpandExtension - like-term combination & structural ordering', () {
    test('exact cancellation to zero for complex multi-term polynomial', () {
      final expr =
          (x + y).pow(3) -
          (x.pow(3) +
              const RationalNumber(3) * (x.pow(2) * y) +
              const RationalNumber(3) * (x * y.pow(2)) +
              y.pow(3));
      final expanded = expr.expand();
      check(expanded).equals(RationalNumber.zero);
    });

    test('telescoping cyclical sum cancels completely to zero', () {
      final expr = (a - b) + (b - c) + (c - d) + (d - a);
      final expanded = expr.expand();
      check(expanded).equals(RationalNumber.zero);
    });

    test('telescoping products cancel to zero', () {
      final expr = (x + y) * (x - y) + (y + z) * (y - z) + (z + x) * (z - x);
      final expanded = expr.expand();
      check(expanded).equals(RationalNumber.zero);
    });

    test('descending degree ordering in univariate polynomial', () {
      final expr =
          const RationalNumber(3) +
          x +
          const RationalNumber(5) * x.pow(3) +
          const RationalNumber(2) * x.pow(2);
      final expanded = expr.expand();
      final expected =
          const RationalNumber(5) * x.pow(3) +
          const RationalNumber(2) * x.pow(2) +
          x +
          3;
      check(expanded).equals(expected);
    });

    test('sign ordering in univariate polynomial: positive terms first at equal degree', () {
      final expr = (x - 2) * (x + 2);
      final expanded = expr.expand();
      check(expanded).equals(x.pow(2) - 4);
    });

    test('multivariate structural ordering of terms', () {
      final expr = (x + y).pow(2);
      final expanded = expr.expand();
      check(expanded.toString()).equals('x ^ 2 + 2 * x * y + y ^ 2');
    });

    test('multivariate difference of squares ordering', () {
      final expr = (x + y) * (x - y);
      final expanded = expr.expand();
      check(expanded.toString()).equals('x ^ 2 - y ^ 2');
    });
  });

  group('ExpandExtension - division and rational terms', () {
    test('distributes numerator over scalar denominator', () {
      final expr =
          (x.pow(2) + const RationalNumber(4) * x + 6) /
          const RationalNumber(2);
      final expanded = expr.expand();
      final expected =
          const RationalNumber(1, 2) * x.pow(2) +
          const RationalNumber(2) * x +
          3;
      check(expanded).equals(expected);
    });

    test('distributes numerator sum over non-scalar denominator', () {
      final expr = (x.pow(2) + 1) / y;
      final expanded = expr.expand();
      _checkParity(expr, expanded, vars: ['x', 'y']);
      check(expanded.expand()).equals(expanded);
    });

    test('division by zero throws UnsupportedError', () {
      check(() => ((x + 1) / 0).expand()).throws<UnsupportedError>();
      check(() => ((x + 1) / const RationalNumber(0)).expand())
          .throws<UnsupportedError>();
      check(() => ((x + 1) / const RealNumber(0.0)).expand())
          .throws<UnsupportedError>();
    });
  });

  group('ExpandExtension - stress and edge cases', () {
    test('expanding already expanded polynomial is idempotent', () {
      final p =
          x.pow(4) -
          const RationalNumber(3) * x.pow(3) +
          const RationalNumber(5) * x.pow(2) -
          const RationalNumber(7) * x +
          9;
      check(p.expand()).equals(p);
    });

    test('unary negation distributes across product', () {
      final expr = -((x - 2) * (x - 3));
      final expanded = expr.expand();
      final expected = -x.pow(2) + const RationalNumber(5) * x - 6;
      check(expanded).equals(expected);
      _checkParity(expr, expanded, vars: ['x']);
    });

    test('zero multiplier produces zero', () {
      final expr =
          const RationalNumber(0) *
          (x.pow(3) + const RationalNumber(2) * x + 1);
      check(expr.expand()).equals(RationalNumber.zero);
    });

    test('identity multiplier 1 leaves expression unchanged', () {
      final expr =
          const RationalNumber(1) *
          (x.pow(2) - const RationalNumber(2) * x + 1);
      final expected = x.pow(2) - const RationalNumber(2) * x + 1;
      check(expr.expand()).equals(expected);
    });

    test('sum/difference of cubes identities', () {
      final diffCubes = ((x - 1) * (x.pow(2) + x + 1)).expand();
      check(diffCubes).equals(x.pow(3) - 1);

      final sumCubes = ((x + 1) * (x.pow(2) - x + 1)).expand();
      check(sumCubes).equals(x.pow(3) + 1);

      final diffQuart = ((x - 1) * (x.pow(3) + x.pow(2) + x + 1)).expand();
      check(diffQuart).equals(x.pow(4) - 1);
    });

    test('symmetric power cancellations', () {
      final diffSq = ((x + 1).pow(2) - (x - 1).pow(2)).expand();
      check(diffSq).equals(const RationalNumber(4) * x);

      final diffCb = ((x + 1).pow(3) - (x - 1).pow(3)).expand();
      check(diffCb).equals(const RationalNumber(6) * x.pow(2) + 2);

      final diffQ = ((x + 1).pow(4) - (x - 1).pow(4)).expand();
      check(diffQ).equals(
        const RationalNumber(8) * x.pow(3) + const RationalNumber(8) * x,
      );
    });

    test('multivariate symmetric difference', () {
      final expr = (x + y + z).pow(2) - (x.pow(2) + y.pow(2) + z.pow(2));
      final expanded = expr.expand();
      final expected =
          const RationalNumber(2) * (x * y) +
          const RationalNumber(2) * (x * z) +
          const RationalNumber(2) * (y * z);
      check(expanded).equals(expected);
    });

    test('all-negative coefficients binomial products', () {
      final expr1 = (-x - 2) * (-x - 3);
      check(expr1.expand()).equals(x.pow(2) + const RationalNumber(5) * x + 6);

      final expr2 = (-x + 2) * (x - 2);
      check(expr2.expand()).equals(-x.pow(2) + const RationalNumber(4) * x - 4);

      final expr3 =
          (-const RationalNumber(2) * x + const RationalNumber(3) * y) *
          (const RationalNumber(4) * x - const RationalNumber(5) * y);
      check(expr3.expand()).equals(
        const RationalNumber(22) * (x * y) -
            const RationalNumber(8) * x.pow(2) -
            const RationalNumber(15) * y.pow(2),
      );
    });

    test('factored square product equals square of expanded quadratic', () {
      final p1 = ((x - 2).pow(2) * (x + 2).pow(2)).expand();
      final p2 = (x.pow(2) - 4).pow(2).expand();
      final expected = x.pow(4) - const RationalNumber(8) * x.pow(2) + 16;
      check(p1).equals(expected);
      check(p2).equals(expected);
      check(p1).equals(p2);
    });

    test('round-trip invariant: expr.factor().expand() == expr.expand() across 15 cases', () {
      final expressions = [
        (x - 1) * (x - 2),
        (x + 3) * (x - 3),
        (x - 2).pow(2),
        (x - 1) * (x - 2) * (x - 3),
        (const RationalNumber(2) * x + 1) * (const RationalNumber(3) * x + 4),
        (const RationalNumber(2) * x - 5).pow(2),
        x * (x - 1) * (x + 1),
        (x.pow(2) - 4) * (x - 3),
        (x.pow(2) + 1) * (x - 1),
        (x - 1).pow(3),
        (x + 2).pow(4),
        (x - 1) * (x + 1) * (x - 2) * (x + 2),
        (x * y + const RationalNumber(2) * x + const RationalNumber(3) * y + 6),
        (const RationalNumber(3) * x.pow(2) * y +
            const RationalNumber(6) * x * y.pow(2)),
        (const RationalNumber(4) * x.pow(2) -
            const RationalNumber(9) * y.pow(2)),
      ];

      for (final e in expressions) {
        check(e.factor().expand()).equals(e.expand());
      }
    });
  });

  group('ExpandExtension - randomized algebraic axioms & invariants', () {
    final polyVars = [const Variable('x'), const Variable('y')];

    Expr randomPolynomial(math.Random rng, int depth) {
      if (depth <= 0 || rng.nextDouble() < 0.3) {
        if (rng.nextBool()) {
          return polyVars[rng.nextInt(polyVars.length)];
        } else {
          final n = rng.nextInt(9) - 4;
          return RationalNumber(n);
        }
      }
      final op = rng.nextInt(3);
      final left = randomPolynomial(rng, depth - 1);
      final right = randomPolynomial(rng, depth - 1);
      return switch (op) {
        0 => left + right,
        1 => left - right,
        _ => left * right,
      };
    }

    test('commutativity of multiplication: expand(A * B) == expand(B * A) across 50 random pairs', () {
      final rng = math.Random(1001);
      for (var i = 0; i < 50; i++) {
        final a = randomPolynomial(rng, 2);
        final b = randomPolynomial(rng, 2);
        final ab = (a * b).expand();
        final ba = (b * a).expand();
        check(ab).equals(ba);
      }
    });

    test('distributivity: expand(A * (B + C)) == expand(A * B + A * C) across 50 random triples', () {
      final rng = math.Random(1002);
      for (var i = 0; i < 50; i++) {
        final a = randomPolynomial(rng, 2);
        final b = randomPolynomial(rng, 2);
        final c = randomPolynomial(rng, 2);
        final left = (a * (b + c)).expand();
        final right = (a * b + a * c).expand();
        check(left).equals(right);
      }
    });

    test(
      'additive cancellation: expand(A - A) == 0 across 50 random polynomials',
      () {
        final rng = math.Random(1003);
        for (var i = 0; i < 50; i++) {
          final a = randomPolynomial(rng, 3);
          final zero = (a - a).expand();
          check(zero).equals(RationalNumber.zero);
        }
      },
    );

    test('idempotence: expand(expand(A)) == expand(A) across 50 random polynomials', () {
      final rng = math.Random(1004);
      for (var i = 0; i < 50; i++) {
        final a = randomPolynomial(rng, 3);
        final once = a.expand();
        final twice = once.expand();
        check(twice).equals(once);
      }
    });

    test('evaluation fidelity: A.evaluate() == A.expand().evaluate() across 100 valuations', () {
      final rng = math.Random(1005);
      for (var i = 0; i < 20; i++) {
        final poly = randomPolynomial(rng, 3);
        final expanded = poly.expand();
        for (var pt = 0; pt < 5; pt++) {
          final ctx = {
            'x': (rng.nextDouble() - 0.5) * 10.0,
            'y': (rng.nextDouble() - 0.5) * 10.0,
          };
          final v1 = poly.evaluate(ctx);
          final v2 = expanded.evaluate(ctx);
          if (v1.isFinite && v2.isFinite) {
            check((v1 - v2).abs()).isLessThan(1e-7);
          }
        }
      }
    });
  });
}

/// Helper to recursively assert that no sub-AST contains Pow(Mul(...), ...) or Pow(Div(...), ...).
void _assertNoPowerOfProduct(Expr expr, [String context = '']) {
  switch (expr) {
    case Pow(:final base, :final exponent):
      if (base is Mul || base is Div) {
        throw StateError(
          'Found un-expanded power of product/quotient: $expr (base: $base, exponent: $exponent) in $context',
        );
      }
      _assertNoPowerOfProduct(base, context);
      _assertNoPowerOfProduct(exponent, context);
    case UnaryExpr(:final expr):
      _assertNoPowerOfProduct(expr, context);
    case BinaryExpr(:final left, :final right):
      _assertNoPowerOfProduct(left, context);
      _assertNoPowerOfProduct(right, context);
    case Piecewise(:final branches, :final otherwise):
      for (final (cond, e) in branches) {
        _assertNoPowerOfProduct(cond, context);
        _assertNoPowerOfProduct(e, context);
      }
      if (otherwise != null) _assertNoPowerOfProduct(otherwise, context);
    case Number() || Variable() || OrderTerm():
      break;
  }
}

/// Helper to evaluate an expression with double values.
double _evaluateExpr(Expr expr, Map<String, double> values) =>
    expr.evaluate(values);

void _checkParity(
  Expr original,
  Expr expanded, {
  List<String> vars = const ['x', 'y', 'z'],
  int trials = 30,
  double tolerance = 1e-7,
}) {
  final rng = math.Random(42);
  for (var i = 0; i < trials; i++) {
    final context = <String, double>{};
    for (final v in vars) {
      context[v] = (rng.nextDouble() - 0.5) * 10.0;
    }
    final v1 = original.evaluate(context);
    final v2 = expanded.evaluate(context);
    if (v1.isFinite && v2.isFinite) {
      check((v1 - v2).abs()).isLessThan(tolerance);
    }
  }
}
