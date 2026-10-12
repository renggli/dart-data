import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

/// Helper to recursively assert that no sub-AST contains Pow(Mul(...), ...) or Pow(Div(...), ...).
void assertNoPowerOfProduct(Expr expr, [String context = '']) {
  switch (expr) {
    case Pow(:final base, :final exponent):
      if (base is Mul || base is Div) {
        throw StateError(
          'Found un-expanded power of product/quotient: $expr (base: $base, exponent: $exponent) in $context',
        );
      }
      assertNoPowerOfProduct(base, context);
      assertNoPowerOfProduct(exponent, context);
    case Neg(:final expr):
      assertNoPowerOfProduct(expr, context);
    case Add(:final left, :final right):
    case Sub(:final left, :final right):
    case Mul(:final left, :final right):
    case Div(:final left, :final right):
      assertNoPowerOfProduct(left, context);
      assertNoPowerOfProduct(right, context);
    case Sin(:final expr):
    case Cos(:final expr):
    case Tan(:final expr):
    case Asin(:final expr):
    case Acos(:final expr):
    case Atan(:final expr):
    case Sinh(:final expr):
    case Cosh(:final expr):
    case Tanh(:final expr):
    case Abs(:final expr):
    case Exp(:final expr):
    case Ln(:final expr):
      assertNoPowerOfProduct(expr, context);
    case Log(:final base, :final expr):
      assertNoPowerOfProduct(base, context);
      assertNoPowerOfProduct(expr, context);
    case Number() || Variable():
      break;
  }
}

/// Helper to evaluate an expression with double values.
double evaluateExpr(Expr expr, Map<String, double> values) =>
    expr.evaluate(values);

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');
  const w = Variable('w');

  group('Group 1: Binomial Expansions with Negative Cross Terms', () {
    test('(x - y)^n for n = 2..8 expands without (x * y)^k', () {
      final powers = [2, 3, 4, 5, 6, 7, 8];
      for (final n in powers) {
        final expr = Pow(x - y, RationalNumber(n));
        final expanded = expr.expand();

        assertNoPowerOfProduct(expanded, '(x - y)^$n');

        // Check string does not contain '(x * y)'
        check(expanded.toString()).not((it) => it.contains('(x * y)'));

        // Numerical check
        for (final (vx, vy) in [(2.0, 3.0), (-1.5, 2.5), (0.7, -1.2)]) {
          final expected = math.pow(vx - vy, n).toDouble();
          final actual = evaluateExpr(expanded, {'x': vx, 'y': vy});
          check((actual - expected).abs()).isLessThan(1e-7);
        }
      }
    });

    test('(2x - 3y)^n for n = 2..5 expands with correct negative cross coefficients', () {
      final base = const RationalNumber(2) * x - const RationalNumber(3) * y;
      for (final n in [2, 3, 4, 5]) {
        final expr = Pow(base, RationalNumber(n));
        final expanded = expr.expand();

        assertNoPowerOfProduct(expanded, '(2x - 3y)^$n');
        check(expanded.toString()).not((it) => it.contains('(x * y)'));

        // Parity with factor().expand()
        check(expr.factor().expand()).equals(expanded);

        // Numerical check
        for (final (vx, vy) in [(1.0, 1.0), (2.0, -1.0), (-0.5, 1.5)]) {
          final expected = math.pow(2.0 * vx - 3.0 * vy, n).toDouble();
          final actual = evaluateExpr(expanded, {'x': vx, 'y': vy});
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
        assertNoPowerOfProduct(e1, '(x/2 - y/3)^2');
        check(e1.toString()).not((it) => it.contains('(x * y)'));

        final b2 =
            const RationalNumber(2, 3) * x - const RationalNumber(3, 4) * y;
        final e2 = Pow(b2, const RationalNumber(3)).expand();
        assertNoPowerOfProduct(e2, '(2x/3 - 3y/4)^3');
        check(e2.toString()).not((it) => it.contains('(x * y)'));
      },
    );
  });

  group('Group 2: Differences of Powers & Higher Powers of Sums/Differences', () {
    test(
      '(x^2 - y^2)^n for n = 2..5 expands to clean monomials without (x * y)^k',
      () {
        // (x^2 - y^2)^2 = x^4 + y^4 - 2 * x^2 * y^2
        final p2 = Pow(x.pow(2) - y.pow(2), const RationalNumber(2));
        final e2 = p2.expand();
        assertNoPowerOfProduct(e2, '(x^2 - y^2)^2');
        check(e2.toString()).equals('x ^ 4 + y ^ 4 - 2 * x ^ 2 * y ^ 2');
        check(p2.factor().expand()).equals(e2);

        // (x^2 - y^2)^3 = x^6 - 3*x^4*y^2 + 3*x^2*y^4 - y^6
        final p3 = Pow(x.pow(2) - y.pow(2), const RationalNumber(3));
        final e3 = p3.expand();
        assertNoPowerOfProduct(e3, '(x^2 - y^2)^3');
        check(e3.toString()).not((it) => it.contains('(x * y)'));
        check(p3.factor().expand()).equals(e3);

        // (x^2 - y^2)^4 = x^8 - 4*x^6*y^2 + 6*x^4*y^4 - 4*x^2*y^6 + y^8
        final p4 = Pow(x.pow(2) - y.pow(2), const RationalNumber(4));
        final e4 = p4.expand();
        assertNoPowerOfProduct(e4, '(x^2 - y^2)^4');
        check(e4.toString()).not((it) => it.contains('(x * y)'));
        check(p4.factor().expand()).equals(e4);

        // (x^2 - y^2)^5
        final p5 = Pow(x.pow(2) - y.pow(2), const RationalNumber(5));
        final e5 = p5.expand();
        assertNoPowerOfProduct(e5, '(x^2 - y^2)^5');
        check(e5.toString()).not((it) => it.contains('(x * y)'));
        check(p5.factor().expand()).equals(e5);
      },
    );

    test('(x^3 - y^3)^n for n = 2, 3 expands without (x * y)^k', () {
      // (x^3 - y^3)^2 = x^6 - 2*x^3*y^3 + y^6
      final p2 = Pow(x.pow(3) - y.pow(3), const RationalNumber(2));
      final e2 = p2.expand();
      assertNoPowerOfProduct(e2, '(x^3 - y^3)^2');
      check(e2.toString()).equals('x ^ 6 + y ^ 6 - 2 * x ^ 3 * y ^ 3');
      check(p2.factor().expand()).equals(e2);

      // (x^3 - y^3)^3 = x^9 - 3*x^6*y^3 + 3*x^3*y^6 - y^9
      final p3 = Pow(x.pow(3) - y.pow(3), const RationalNumber(3));
      final e3 = p3.expand();
      assertNoPowerOfProduct(e3, '(x^3 - y^3)^3');
      check(e3.toString()).not((it) => it.contains('(x * y)'));
      check(p3.factor().expand()).equals(e3);
    });

    test('(x^4 - y^4)^2 expands without (x * y)^k', () {
      final p = Pow(x.pow(4) - y.pow(4), const RationalNumber(2));
      final e = p.expand();
      assertNoPowerOfProduct(e, '(x^4 - y^4)^2');
      check(e.toString()).equals('x ^ 8 + y ^ 8 - 2 * x ^ 4 * y ^ 4');
      check(p.factor().expand()).equals(e);
    });

    test(
      'asymmetric powers differences: (x^2 - y^3)^2 and (3x^2 - 2y^3)^2',
      () {
        final p1 = Pow(x.pow(2) - y.pow(3), const RationalNumber(2));
        final e1 = p1.expand();
        assertNoPowerOfProduct(e1, '(x^2 - y^3)^2');
        check(e1.toString()).equals('y ^ 6 - 2 * x ^ 2 * y ^ 3 + x ^ 4');
        check(p1.factor().expand()).equals(e1);

        final p2 = Pow(
          const RationalNumber(3) * x.pow(2) -
              const RationalNumber(2) * y.pow(3),
          const RationalNumber(2),
        );
        final e2 = p2.expand();
        assertNoPowerOfProduct(e2, '(3x^2 - 2y^3)^2');
        check(e2.toString())
            .equals('4 * y ^ 6 - 12 * x ^ 2 * y ^ 3 + 9 * x ^ 4');
        check(p2.factor().expand()).equals(e2);
      },
    );
  });

  group('Group 3: Multinomial Expansions with Negative Terms', () {
    test('(x - y - z)^2 and (x - y - z)^3 expansion', () {
      final p2 = Pow(x - y - z, const RationalNumber(2));
      final e2 = p2.expand();
      assertNoPowerOfProduct(e2, '(x - y - z)^2');
      check(e2.toString()).not((it) => it.contains('(x * y)'));
      check(e2.toString()).not((it) => it.contains('(x * z)'));
      check(e2.toString()).not((it) => it.contains('(y * z)'));
      check(p2.factor().expand()).equals(e2);

      final p3 = Pow(x - y - z, const RationalNumber(3));
      final e3 = p3.expand();
      assertNoPowerOfProduct(e3, '(x - y - z)^3');
      check(p3.factor().expand()).equals(e3);
    });

    test('(x^2 - y^2 - z^2)^2 and (x^2 - y^2 + z^2)^2 expansion', () {
      final p1 = Pow(x.pow(2) - y.pow(2) - z.pow(2), const RationalNumber(2));
      final e1 = p1.expand();
      assertNoPowerOfProduct(e1, '(x^2 - y^2 - z^2)^2');
      check(e1.toString()).not((it) => it.contains('(x * y)'));
      check(e1.toString()).not((it) => it.contains('(x * z)'));
      check(e1.toString()).not((it) => it.contains('(y * z)'));
      check(p1.factor().expand()).equals(e1);

      final p2 = Pow(x.pow(2) - y.pow(2) + z.pow(2), const RationalNumber(2));
      final e2 = p2.expand();
      assertNoPowerOfProduct(e2, '(x^2 - y^2 + z^2)^2');
      check(p2.factor().expand()).equals(e2);
    });

    test('quadrinomial (x - y - z - w)^2 and (x^2 - y^2 - z^2 - w^2)^2', () {
      final p1 = Pow(x - y - z - w, const RationalNumber(2));
      final e1 = p1.expand();
      assertNoPowerOfProduct(e1, '(x - y - z - w)^2');
      check(p1.factor().expand()).equals(e1);

      final p2 = Pow(
        x.pow(2) - y.pow(2) - z.pow(2) - w.pow(2),
        const RationalNumber(2),
      );
      final e2 = p2.expand();
      assertNoPowerOfProduct(e2, '(x^2 - y^2 - z^2 - w^2)^2');
      check(p2.factor().expand()).equals(e2);
    });
  });

  group('Group 4: Negative Monomials & Products of Differences', () {
    test('standalone negative monomials do not un-expand', () {
      final m1 = -(x.pow(2) * y.pow(2));
      final e1 = m1.expand();
      assertNoPowerOfProduct(e1, '-(x^2 * y^2)');
      check(e1.toString()).equals('-(x ^ 2 * y ^ 2)');

      final m2 = -(x.pow(3) * y.pow(3));
      final e2 = m2.expand();
      assertNoPowerOfProduct(e2, '-(x^3 * y^3)');
      check(e2.toString()).equals('-(x ^ 3 * y ^ 3)');

      final m3 = -(x.pow(4) * y.pow(4));
      final e3 = m3.expand();
      assertNoPowerOfProduct(e3, '-(x^4 * y^4)');
      check(e3.toString()).equals('-(x ^ 4 * y ^ 4)');

      final m4 = const RationalNumber(-2) * x.pow(2) * y.pow(2);
      final e4 = m4.expand();
      assertNoPowerOfProduct(e4, '-2 * x^2 * y^2');
      check(e4.toString()).equals('-2 * x ^ 2 * y ^ 2');

      final m5 = -(x.pow(2) * y.pow(2) * z.pow(2));
      final e5 = m5.expand();
      assertNoPowerOfProduct(e5, '-(x^2 * y^2 * z^2)');
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
      assertNoPowerOfProduct(e4, '(x^2 - y^2)(z^2 - w^2)');
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
      assertNoPowerOfProduct(e, '(x - y)^2 * (x + y)^2');
      check(e.toString()).equals('x ^ 4 + y ^ 4 - 2 * x ^ 2 * y ^ 2');
      check(p.factor().expand()).equals(e);
    });

    test('compounded powers of differences: (x^2 - y^2)^2 * (x^2 + y^2)^2', () {
      final p =
          Pow(x.pow(2) - y.pow(2), const RationalNumber(2)) *
          Pow(x.pow(2) + y.pow(2), const RationalNumber(2));
      final e = p.expand();
      assertNoPowerOfProduct(e, '(x^2 - y^2)^2 * (x^2 + y^2)^2');
      check(e.toString()).equals('x ^ 8 + y ^ 8 - 2 * x ^ 4 * y ^ 4');
      check(p.factor().expand()).equals(e);
    });

    test('monomial difference powers: (x^2*y^2 - 1)^2 and (1 - x^2*y^2)^2', () {
      final p1 = Pow(x.pow(2) * y.pow(2) - 1, const RationalNumber(2));
      final e1 = p1.expand();
      assertNoPowerOfProduct(e1, '(x^2*y^2 - 1)^2');
      check(e1.toString()).equals('x ^ 4 * y ^ 4 - 2 * x ^ 2 * y ^ 2 + 1');
      check(p1.factor().expand()).equals(e1);

      final p2 = Pow(
        const RationalNumber(1) - x.pow(2) * y.pow(2),
        const RationalNumber(2),
      );
      final e2 = p2.expand();
      assertNoPowerOfProduct(e2, '(1 - x^2*y^2)^2');
      check(e2.toString()).equals('x ^ 4 * y ^ 4 - 2 * x ^ 2 * y ^ 2 + 1');
      check(p2.factor().expand()).equals(e2);
    });

    test('monomial difference cube: (x^2*y^2 - 1)^3 and (1 - x^2*y^2)^3', () {
      final p1 = Pow(x.pow(2) * y.pow(2) - 1, const RationalNumber(3));
      final e1 = p1.expand();
      assertNoPowerOfProduct(e1, '(x^2*y^2 - 1)^3');
      check(e1.toString())
          .equals('x ^ 6 * y ^ 6 - 3 * x ^ 4 * y ^ 4 + 3 * x ^ 2 * y ^ 2 - 1');
      check(p1.factor().expand()).equals(e1);

      final p2 = Pow(
        const RationalNumber(1) - x.pow(2) * y.pow(2),
        const RationalNumber(3),
      );
      final e2 = p2.expand();
      assertNoPowerOfProduct(e2, '(1 - x^2*y^2)^3');
      check(
        e2.toString(),
      ).equals('-(x ^ 6 * y ^ 6) + 3 * x ^ 4 * y ^ 4 - 3 * x ^ 2 * y ^ 2 + 1');
      check(p2.factor().expand()).equals(e2);
    });

    test('cross product of distinct monomials (x^2 * y - x * y^2)^2', () {
      final p = Pow(x.pow(2) * y - x * y.pow(2), const RationalNumber(2));
      final e = p.expand();
      assertNoPowerOfProduct(e, '(x^2 * y - x * y^2)^2');
      check(e.toString())
          .equals('x ^ 4 * y ^ 2 + x ^ 2 * y ^ 4 - 2 * x ^ 3 * y ^ 3');
      check(p.factor().expand()).equals(e);
    });
  });

  group('Group 5: Negative Powers and Inverses of Expanded Monomials', () {
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
          .equals('-(2 * (x * y) ^ 2) / z + x ^ 4 / z + y ^ 4 / z');
    });
  });
}
