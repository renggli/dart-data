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
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  void checkParity(
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

  group('Challenger - Multi-term products', () {
    test('monic quadratic: (x - 2) * (x - 3)', () {
      final expr = (x - 2) * (x - 3);
      final expanded = expr.expand();
      final expected = x.pow(2) - const RationalNumber(5) * x + 6;
      check(expanded).equals(expected);
      check(expanded.toString()).equals('x ^ 2 - 5 * x + 6');
      checkParity(expr, expanded, vars: ['x']);
    });

    test('3-factor symbolic product: (a + b) * (c + d) * (e + f)', () {
      final expr = (a + b) * (c + d) * (e + f);
      final expanded = expr.expand();

      // Expanding (a+b)(c+d)(e+f) should yield 8 terms:
      // a*c*e + a*c*f + a*d*e + a*d*f + b*c*e + b*c*f + b*d*e + b*d*f
      checkParity(expr, expanded, vars: ['a', 'b', 'c', 'd', 'e', 'f']);

      // Check idempotence
      check(expanded.expand()).equals(expanded);
    });

    test(
      '4-factor product with alternating signs: (x-1)*(x+2)*(x-3)*(x+4)',
      () {
        final expr = (x - 1) * (x + 2) * (x - 3) * (x + 4);
        final expanded = expr.expand();
        // (x^2 + x - 2) * (x^2 + x - 12) = x^4 + 2*x^3 - 13*x^2 - 14*x + 24
        final expected =
            x.pow(4) +
            const RationalNumber(2) * x.pow(3) -
            const RationalNumber(13) * x.pow(2) -
            const RationalNumber(14) * x +
            24;
        check(expanded).equals(expected);
        checkParity(expr, expanded, vars: ['x']);
      },
    );

    test(
      '5-factor product: (x - 1) * (x - 2) * (x - 3) * (x - 4) * (x - 5)',
      () {
        final expr = (x - 1) * (x - 2) * (x - 3) * (x - 4) * (x - 5);
        final expanded = expr.expand();
        // x^5 - 15*x^4 + 85*x^3 - 225*x^2 + 274*x - 120
        final expected =
            x.pow(5) -
            const RationalNumber(15) * x.pow(4) +
            const RationalNumber(85) * x.pow(3) -
            const RationalNumber(225) * x.pow(2) +
            const RationalNumber(274) * x -
            120;
        check(expanded).equals(expected);
        checkParity(expr, expanded, vars: ['x']);
      },
    );

    test('cyclical difference product: (x - y) * (y - z) * (z - x)', () {
      final expr = (x - y) * (y - z) * (z - x);
      final expanded = expr.expand();
      checkParity(expr, expanded, vars: ['x', 'y', 'z']);
      check(expanded.expand()).equals(expanded);
    });

    test(
      'rational coefficient distribution: (1/3*x + 2/5) * (3/4*x - 5/6)',
      () {
        final expr =
            (const RationalNumber(1, 3) * x + const RationalNumber(2, 5)) *
            (const RationalNumber(3, 4) * x - const RationalNumber(5, 6));
        final expanded = expr.expand();
        // 1/3 * 3/4 = 1/4
        // 1/3 * (-5/6) + 2/5 * 3/4 = -5/18 + 3/10 = (-25 + 27)/90 = 2/90 = 1/45
        // 2/5 * (-5/6) = -1/3
        final expected =
            const RationalNumber(1, 4) * x.pow(2) +
            const RationalNumber(1, 45) * x -
            const RationalNumber(1, 3);
        check(expanded).equals(expected);
        checkParity(expr, expanded, vars: ['x']);
      },
    );

    test('mixed rational and floating-point coefficients', () {
      final expr = (x + const RealNumber(1.5)) * (x - const RationalNumber(2));
      final expanded = expr.expand();
      // x^2 - 0.5*x - 3.0
      checkParity(expr, expanded, vars: ['x']);
      check(expanded.expand()).equals(expanded);
    });
  });

  group('Challenger - Polynomial Powers', () {
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
      checkParity(expr, expanded, vars: ['x']);
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
      checkParity(expr, expanded, vars: ['x']);
    });

    test('(2*x - 3)^3 expansion', () {
      final expr = (const RationalNumber(2) * x - 3).pow(3);
      final expanded = expr.expand();
      // 8*x^3 - 36*x^2 + 54*x - 27
      final expected =
          const RationalNumber(8) * x.pow(3) -
          const RationalNumber(36) * x.pow(2) +
          const RationalNumber(54) * x -
          27;
      check(expanded).equals(expected);
      checkParity(expr, expanded, vars: ['x']);
    });

    test('(x + y + z)^3 multinomial expansion', () {
      final expr = (x + y + z).pow(3);
      final expanded = expr.expand();
      checkParity(expr, expanded, vars: ['x', 'y', 'z']);
      check(expanded.expand()).equals(expanded);
    });

    test('high degree power: (x + 1)^6', () {
      final expr = (x + 1).pow(6);
      final expanded = expr.expand();
      // 1, 6, 15, 20, 15, 6, 1
      final expected =
          x.pow(6) +
          const RationalNumber(6) * x.pow(5) +
          const RationalNumber(15) * x.pow(4) +
          const RationalNumber(20) * x.pow(3) +
          const RationalNumber(15) * x.pow(2) +
          const RationalNumber(6) * x +
          1;
      check(expanded).equals(expected);
      checkParity(expr, expanded, vars: ['x']);
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
      checkParity(expr, expanded, vars: ['x']);
    });

    test('zero and negative integer powers', () {
      check((x.pow(2) + const RationalNumber(3) * x + 5).pow(0).expand())
          .equals(const RationalNumber(1));
      final negPow = (x + 2).pow(-1).expand();
      check(negPow).equals(const RationalNumber(1) / (x + 2));
      final negPow2 = (x + 2).pow(-2).expand();
      check(negPow2).equals(
        const RationalNumber(1) / (x.pow(2) + const RationalNumber(4) * x + 4),
      );
    });

    test('fractional power: (x^2 - 1)^(1/2)', () {
      final expr = ((x - 1) * (x + 1)).pow(const RationalNumber(1, 2));
      final expanded = expr.expand();
      check(expanded).equals((x.pow(2) - 1).pow(const RationalNumber(1, 2)));
    });
  });

  group(
    'Challenger - Non-polynomial expressions & Trigonometric/Transcendental',
    () {
      test('Pythagorean identity in squared sum: (sin(x) + cos(x))^2', () {
        final expr = (const Sin(x) + const Cos(x)).pow(2);
        final expanded = expr.expand();
        // sin^2(x) + cos^2(x) reduces to 1, leaving 2*sin(x)*cos(x) + 1
        checkParity(expr, expanded, vars: ['x']);
        check(expanded.expand()).equals(expanded);
      });

      test('Hyperbolic squared sum: (cosh(x) - sinh(x))^2', () {
        final expr = (const Cosh(x) - const Sinh(x)).pow(2);
        final expanded = expr.expand();
        checkParity(expr, expanded, vars: ['x']);
        check(expanded.expand()).equals(expanded);
      });

      test('product of exponential sums: (exp(x) + 1) * (exp(x) - 1)', () {
        final expr = (const Exp(x) + 1) * (const Exp(x) - 1);
        final expanded = expr.expand();
        checkParity(expr, expanded, vars: ['x']);
        check(expanded.expand()).equals(expanded);
      });

      test('nested function arguments expand internally', () {
        final expr = Sin((x - 2) * (x - 3)) + Cos((x + 1).pow(3));
        final expanded = expr.expand();
        // Cos (nodeTag 5) canonically precedes Sin (nodeTag 8)
        final expected =
            Cos(
              x.pow(3) +
                  const RationalNumber(3) * x.pow(2) +
                  const RationalNumber(3) * x +
                  1,
            ) +
            Sin(x.pow(2) - const RationalNumber(5) * x + 6);
        check(expanded).equals(expected);
        checkParity(expr, expanded, vars: ['x']);
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
    },
  );

  group('Challenger - Like-term combination & Ordering', () {
    test('exact cancellation to zero for complex multi-term polynomial', () {
      // (x + y)^3 - (x^3 + 3*x^2*y + 3*x*y^2 + y^3) = 0
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
      // (a - b) + (b - c) + (c - d) + (d - a) = 0
      final expr = (a - b) + (b - c) + (c - d) + (d - a);
      final expanded = expr.expand();
      check(expanded).equals(RationalNumber.zero);
    });

    test('telescoping products cancel to zero', () {
      // (x + y)*(x - y) + (y + z)*(y - z) + (z + x)*(z - x) = 0
      final expr = (x + y) * (x - y) + (y + z) * (y - z) + (z + x) * (z - x);
      final expanded = expr.expand();
      check(expanded).equals(RationalNumber.zero);
    });

    test('descending degree ordering in univariate polynomial', () {
      // Input in mixed order: 3 + x + 5*x^3 + 2*x^2
      final expr =
          const RationalNumber(3) +
          x +
          const RationalNumber(5) * x.pow(3) +
          const RationalNumber(2) * x.pow(2);
      final expanded = expr.expand();
      // Should be 5*x^3 + 2*x^2 + x + 3
      final expected =
          const RationalNumber(5) * x.pow(3) +
          const RationalNumber(2) * x.pow(2) +
          x +
          3;
      check(expanded).equals(expected);
    });

    test('sign ordering in univariate polynomial: positive terms first at equal degree', () {
      // At same degree, positive terms come first
      final expr = (x - 2) * (x + 2); // x^2 - 4
      final expanded = expr.expand();
      check(expanded).equals(x.pow(2) - 4);
    });

    test('multivariate structural ordering of terms', () {
      final expr = (x + y).pow(2);
      final expanded = expr.expand();
      final str = expanded.toString();
      // Expect x^2 + 2 * x * y + y^2
      check(str).equals('x ^ 2 + 2 * x * y + y ^ 2');
    });

    test('multivariate difference of squares ordering', () {
      final expr = (x + y) * (x - y);
      final expanded = expr.expand();
      check(expanded.toString()).equals('x ^ 2 - y ^ 2');
    });
  });

  group('Challenger - Division and rational terms', () {
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
      // (x^2)/y + 1/y
      checkParity(expr, expanded, vars: ['x', 'y']);
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

  group('Challenger - Stress and edge cases', () {
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
      // -(x^2 - 5*x + 6) = -x^2 + 5*x - 6
      final expected = -x.pow(2) + const RationalNumber(5) * x - 6;
      check(expanded).equals(expected);
      checkParity(expr, expanded, vars: ['x']);
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
      // (x - 1) * (x^2 + x + 1) = x^3 - 1
      final diffCubes = ((x - 1) * (x.pow(2) + x + 1)).expand();
      check(diffCubes).equals(x.pow(3) - 1);

      // (x + 1) * (x^2 - x + 1) = x^3 + 1
      final sumCubes = ((x + 1) * (x.pow(2) - x + 1)).expand();
      check(sumCubes).equals(x.pow(3) + 1);

      // (x - 1) * (x^3 + x^2 + x + 1) = x^4 - 1
      final diffQuart = ((x - 1) * (x.pow(3) + x.pow(2) + x + 1)).expand();
      check(diffQuart).equals(x.pow(4) - 1);
    });

    test('symmetric power cancellations', () {
      // (x + 1)^2 - (x - 1)^2 = 4*x
      final diffSq = ((x + 1).pow(2) - (x - 1).pow(2)).expand();
      check(diffSq).equals(const RationalNumber(4) * x);

      // (x + 1)^3 - (x - 1)^3 = 6*x^2 + 2
      final diffCb = ((x + 1).pow(3) - (x - 1).pow(3)).expand();
      check(diffCb).equals(const RationalNumber(6) * x.pow(2) + 2);

      // (x + 1)^4 - (x - 1)^4 = 8*x^3 + 8*x
      final diffQ = ((x + 1).pow(4) - (x - 1).pow(4)).expand();
      check(diffQ).equals(
        const RationalNumber(8) * x.pow(3) + const RationalNumber(8) * x,
      );
    });

    test('multivariate symmetric difference', () {
      // (x + y + z)^2 - (x^2 + y^2 + z^2) = 2*x*y + 2*x*z + 2*y*z
      final expr = (x + y + z).pow(2) - (x.pow(2) + y.pow(2) + z.pow(2));
      final expanded = expr.expand();
      final expected =
          const RationalNumber(2) * (x * y) +
          const RationalNumber(2) * (x * z) +
          const RationalNumber(2) * (y * z);
      check(expanded).equals(expected);
    });

    test('all-negative coefficients binomial products', () {
      // (-x - 2) * (-x - 3) = x^2 + 5*x + 6
      final expr1 = (-x - 2) * (-x - 3);
      check(expr1.expand()).equals(x.pow(2) + const RationalNumber(5) * x + 6);

      // (-x + 2) * (x - 2) = -x^2 + 4*x - 4
      final expr2 = (-x + 2) * (x - 2);
      check(expr2.expand()).equals(-x.pow(2) + const RationalNumber(4) * x - 4);

      // (-2*x + 3*y) * (4*x - 5*y) = 22*x*y - 8*x^2 - 15*y^2 (positive term first by compareTerms)
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
      // (x - 2)^2 * (x + 2)^2 = (x^2 - 4)^2 = x^4 - 8*x^2 + 16
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

  group('Challenger - Randomized Algebraic Axioms & Invariants', () {
    final vars = [const Variable('x'), const Variable('y')];

    Expr randomPolynomial(math.Random rng, int depth) {
      if (depth <= 0 || rng.nextDouble() < 0.3) {
        if (rng.nextBool()) {
          return vars[rng.nextInt(vars.length)];
        } else {
          final n = rng.nextInt(9) - 4; // -4 to 4
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
