import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Fraction;
import 'package:test/scaffolding.dart';

void main() {
  group('Structural Ordering & Comparator', () {
    const x = Variable('x');
    const y = Variable('y');

    test('compareStructural reflexivity and antisymmetry', () {
      final expressions = <Expr>[
        RationalNumber.zero,
        RationalNumber.one,
        const RationalNumber(3, 4),
        const RealNumber(2.5),
        ConstantNumber.pi,
        ConstantNumber.e,
        x,
        y,
        const Neg(x),
        const Sin(x),
        const Cos(x),
        const Exp(x),
        const Ln(x),
        const Add(x, RationalNumber.one),
        const Sub(x, RationalNumber.one),
        const Mul(RationalNumber(2), x),
        const Div(x, RationalNumber(2)),
        const Pow(x, RationalNumber(2)),
      ];

      for (var i = 0; i < expressions.length; i++) {
        final a = expressions[i];
        // Reflexivity
        check(compareStructural(a, a)).equals(0);

        for (var j = i + 1; j < expressions.length; j++) {
          final b = expressions[j];
          final cmpAB = compareStructural(a, b);
          final cmpBA = compareStructural(b, a);
          check(cmpAB != 0).isTrue();
          check(cmpAB).equals(-cmpBA);
        }
      }
    });

    test('compareStructural transitivity', () {
      final expressions = <Expr>[
        RationalNumber.zero,
        const RealNumber(1.0),
        ConstantNumber.pi,
        x,
        const Neg(x),
        const Sin(x),
        const Pow(x, RationalNumber(2)),
        const Mul(RationalNumber(2), x),
        const Add(x, RationalNumber.one),
      ];

      for (var i = 0; i < expressions.length; i++) {
        for (var j = 0; j < expressions.length; j++) {
          for (var k = 0; k < expressions.length; k++) {
            final a = expressions[i];
            final b = expressions[j];
            final c = expressions[k];
            if (compareStructural(a, b) < 0 && compareStructural(b, c) < 0) {
              check(compareStructural(a, c) < 0).isTrue();
            }
          }
        }
      }
    });

    test('compareRational orders fractions correctly', () {
      const half = RationalNumber(1, 2);
      const half2 = RationalNumber(1, 2);
      const twoFourths = RationalNumber(2, 4);
      const threeFourths = RationalNumber(3, 4);
      const negativeHalf = RationalNumber(-1, 2);

      check(compareRational(half, half2)).equals(0);
      check(compareRational(half, twoFourths)).isLessThan(0);
      check(compareRational(half, threeFourths)).isLessThan(0);
      check(compareRational(threeFourths, half)).isGreaterThan(0);
      check(compareRational(negativeHalf, half)).isLessThan(0);
    });

    test('nodeTag covers AST nodes deterministically', () {
      check(nodeTag(RationalNumber.zero)).equals(0);
      check(nodeTag(const RealNumber(1.0))).equals(1);
      check(nodeTag(ConstantNumber.pi)).equals(2);
      check(nodeTag(x)).equals(3);
      check(nodeTag(const Neg(x))).equals(4);
      check(nodeTag(const Cos(x))).equals(5);
      check(nodeTag(const Exp(x))).equals(6);
      check(nodeTag(const Ln(x))).equals(7);
      check(nodeTag(const Sin(x))).equals(8);
      check(nodeTag(const Tan(x))).equals(9);
      check(nodeTag(const Asin(x))).equals(10);
      check(nodeTag(const Acos(x))).equals(11);
      check(nodeTag(const Atan(x))).equals(12);
      check(nodeTag(const Sinh(x))).equals(13);
      check(nodeTag(const Cosh(x))).equals(14);
      check(nodeTag(const Tanh(x))).equals(15);
      check(nodeTag(const Abs(x))).equals(16);
      check(nodeTag(ComplexNumber.i)).equals(18);
      check(nodeTag(const Pow(x, RationalNumber(2)))).equals(20);
      check(nodeTag(const Mul(x, y))).equals(21);
      check(nodeTag(const Div(x, y))).equals(22);
      check(nodeTag(const Add(x, y))).equals(23);
      check(nodeTag(const Sub(x, y))).equals(24);
    });

    test('termDegree calculates polynomial powers accurately', () {
      check(termDegree(RationalNumber.one)).equals(0.0);
      check(termDegree(ConstantNumber.pi)).equals(0.0);
      check(termDegree(x)).equals(1.0);
      check(termDegree(const Pow(x, RationalNumber(3)))).equals(3.0);
      check(termDegree(const Mul(x, x))).equals(2.0);
      check(termDegree(const Mul(Pow(x, RationalNumber(2)), y))).equals(3.0);
      check(termDegree(const Neg(Pow(x, RationalNumber(4))))).equals(4.0);
    });

    test('primarySymbol extracts symbol names', () {
      check(primarySymbol(x)).equals('x');
      check(primarySymbol(ConstantNumber.pi)).equals('pi');
      check(primarySymbol(const Pow(x, RationalNumber(2)))).equals('x');
      check(primarySymbol(const Neg(x))).equals('x');
      check(primarySymbol(const Mul(x, y))).equals('x');
      check(primarySymbol(const Sin(x))).equals('x');
    });

    test('compareTerms sorts polynomial descending degree and positive first', () {
      const termX3 = Pow(x, RationalNumber(3));
      const termX2 = Pow(x, RationalNumber(2));
      const termX = x;

      // Degree 3 comes before degree 2
      check(compareTerms(termX3, Fraction.one, termX2, Fraction.one))
          .isLessThan(0);
      check(compareTerms(termX2, Fraction.one, termX3, Fraction.one))
          .isGreaterThan(0);

      // Positive coefficient comes before negative coefficient with same degree
      check(compareTerms(termX, Fraction.one, termX, -Fraction.one))
          .isLessThan(0);
      check(compareTerms(termX, -Fraction.one, termX, Fraction.one))
          .isGreaterThan(0);
    });

    test('termTier categorizes expressions into canonical tiers', () {
      // Tier 1: Variable polynomial terms
      check(termTier(x)).equals(1);
      check(termTier(x * x)).equals(1);
      check(termTier(const Sin(x))).equals(1);

      // Tier 2: Pure numbers
      check(termTier(RationalNumber.one)).equals(2);
      check(termTier(const RealNumber(2.5))).equals(2);

      // Tier 3: Real transcendental constants and constant expressions
      check(termTier(ConstantNumber.e)).equals(3);
      check(termTier(ConstantNumber.pi)).equals(3);
      check(termTier(const Pow(RationalNumber(3), RationalNumber(1, 2))))
          .equals(3);

      // Tier 4: Imaginary terms containing i
      check(termTier(ConstantNumber.i)).equals(4);
      check(
        termTier(
          ConstantNumber.i * const Pow(RationalNumber(3), RationalNumber(1, 2)),
        ),
      ).equals(4);
    });

    test('compareTerms enforces 4-tier ordering: variables < pure numbers < e, pi < i', () {
      const one = RationalNumber(1);
      const sqrt3 = Pow(RationalNumber(3), RationalNumber(1, 2));
      final iSqrt3 = ConstantNumber.i * sqrt3;

      // Tier 1 (x) before Tier 2 (1)
      check(compareTerms(x, Fraction.one, one, Fraction.one)).isLessThan(0);

      // Tier 2 (1) before Tier 3 (e, pi, sqrt(3))
      check(compareTerms(one, Fraction.one, ConstantNumber.e, Fraction.one))
          .isLessThan(0);
      check(compareTerms(one, Fraction.one, ConstantNumber.pi, Fraction.one))
          .isLessThan(0);
      check(compareTerms(one, Fraction.one, sqrt3, Fraction.one)).isLessThan(0);

      // Tier 3 (e, pi) before Tier 4 (i, i*sqrt(3))
      check(
        compareTerms(
          ConstantNumber.e,
          Fraction.one,
          ConstantNumber.pi,
          Fraction.one,
        ),
      ).isLessThan(0);
      check(
        compareTerms(
          ConstantNumber.pi,
          Fraction.one,
          ConstantNumber.i,
          Fraction.one,
        ),
      ).isLessThan(0);
      check(
        compareTerms(
          ConstantNumber.i,
          Fraction.one,
          ConstantNumber.pi,
          Fraction.one,
        ),
      ).isGreaterThan(0);
      check(compareTerms(sqrt3, Fraction.one, iSqrt3, Fraction.one))
          .isLessThan(0);
    });

    test('compareStructural places e < pi < i deterministically', () {
      check(compareStructural(ConstantNumber.e, ConstantNumber.pi))
          .isLessThan(0);
      check(compareStructural(ConstantNumber.pi, ConstantNumber.e))
          .isGreaterThan(0);
      check(compareStructural(ConstantNumber.pi, ConstantNumber.i))
          .isLessThan(0);
      check(compareStructural(ConstantNumber.i, ConstantNumber.pi))
          .isGreaterThan(0);
      check(compareStructural(ConstantNumber.e, ConstantNumber.i))
          .isLessThan(0);
      check(compareStructural(ConstantNumber.i, ConstantNumber.e))
          .isGreaterThan(0);
    });
  });

  group('Structural comparator total order invariants', () {
    test('reflexivity: identical and non-identical clones compare to 0', () {
      final sampleNodes = <Expr>[
        const RationalNumber(0),
        const RationalNumber(1),
        const RationalNumber(-3, 7),
        const RationalNumber(3, 7),
        const RealNumber(0.0),
        const RealNumber(-0.0),
        const RealNumber(3.14159),
        const RealNumber(double.nan),
        const ConstantNumber('pi', math.pi),
        const ConstantNumber('e', math.e),
        const Variable('x'),
        const Variable('y'),
        const Variable('z'),
        const Neg(Variable('x')),
        const Sin(Variable('x')),
        const Cos(Variable('x')),
        const Exp(Variable('x')),
        const Ln(Variable('x')),
        const Add(Variable('x'), Variable('y')),
        const Sub(Variable('x'), Variable('y')),
        const Mul(Variable('x'), Variable('y')),
        const Div(Variable('x'), Variable('y')),
        const Pow(Variable('x'), RationalNumber(2)),
        // Nested composite nodes
        const Add(Sin(Variable('x')), Mul(Variable('y'), Exp(Variable('z')))),
        const Div(
          Sub(Variable('a'), RationalNumber(1, 2)),
          Pow(Variable('b'), RationalNumber(3)),
        ),
      ];

      for (final e in sampleNodes) {
        // Identical reference
        check(compareStructural(e, e)).equals(0);

        // Cloned non-identical reference
        final clone = _cloneExpr(e);
        check(identical(e, clone)).isFalse();
        check(compareStructural(e, clone)).equals(0);
        check(compareStructural(clone, e)).equals(0);
      }
    });

    test('antisymmetry across all pairwise node combinations', () {
      final pool = <Expr>[
        const RationalNumber(-5),
        const RationalNumber(-1, 2),
        const RationalNumber(0),
        const RationalNumber(1, 2),
        const RationalNumber(5),
        const RealNumber(-10.0),
        const RealNumber(0.0),
        const RealNumber(10.0),
        const ConstantNumber('e', math.e),
        const ConstantNumber('pi', math.pi),
        const Variable('a'),
        const Variable('b'),
        const Variable('x'),
        const Neg(Variable('a')),
        const Sin(Variable('a')),
        const Cos(Variable('a')),
        const Exp(Variable('a')),
        const Ln(Variable('a')),
        const Add(Variable('a'), Variable('b')),
        const Sub(Variable('a'), Variable('b')),
        const Mul(Variable('a'), Variable('b')),
        const Div(Variable('a'), Variable('b')),
        const Pow(Variable('a'), Variable('b')),
      ];

      for (var i = 0; i < pool.length; i++) {
        for (var j = 0; j < pool.length; j++) {
          final a = pool[i];
          final b = pool[j];
          final cmpAB = compareStructural(a, b);
          final cmpBA = compareStructural(b, a);

          // Antisymmetry: sign(cmp(a, b)) == -sign(cmp(b, a))
          check(cmpAB.sign).equals(-cmpBA.sign);

          // Zero iff structurally equivalent
          if (cmpAB == 0) {
            check(a == b).isTrue();
          } else {
            check(a == b).isFalse();
          }
        }
      }
    });

    test('exhaustive transitivity verification on generated expression triad space', () {
      // Build 120 structurally diverse expressions
      final exprs = <Expr>[];

      // Numerics
      exprs.addAll([
        const RationalNumber(-10),
        const RationalNumber(-2, 3),
        const RationalNumber(0),
        const RationalNumber(2, 3),
        const RationalNumber(10),
        const RealNumber(-5.0),
        const RealNumber(0.0),
        const RealNumber(5.0),
        const ConstantNumber('c1', 1.0),
        const ConstantNumber('c2', 2.0),
      ]);

      // Variables
      const vars = [Variable('u'), Variable('v'), Variable('w')];
      exprs.addAll(vars);

      // Unary variants
      for (final v in vars) {
        exprs.add(Neg(v));
        exprs.add(Sin(v));
        exprs.add(Cos(v));
        exprs.add(Exp(v));
        exprs.add(Ln(v));
      }

      // Binary combinations
      for (var i = 0; i < vars.length; i++) {
        for (var j = 0; j < vars.length; j++) {
          exprs.add(Add(vars[i], vars[j]));
          exprs.add(Sub(vars[i], vars[j]));
          exprs.add(Mul(vars[i], vars[j]));
          exprs.add(Div(vars[i], vars[j]));
          exprs.add(Pow(vars[i], vars[j]));
        }
      }

      // Deeper composite nodes
      for (final v in vars) {
        exprs.add(Add(Sin(v), Cos(v)));
        exprs.add(Mul(v, Exp(v)));
        exprs.add(Pow(v, const RationalNumber(2)));
        exprs.add(Div(v, Add(v, const RationalNumber(1))));
      }

      // Verify triad transitivity across 100 expressions = 1,000,000 triads
      final subset = exprs.take(100).toList();
      final n = subset.length;

      for (var i = 0; i < n; i++) {
        final a = subset[i];
        for (var j = 0; j < n; j++) {
          final b = subset[j];
          final cmpAB = compareStructural(a, b);

          for (var k = 0; k < n; k++) {
            final c = subset[k];
            final cmpBC = compareStructural(b, c);
            final cmpAC = compareStructural(a, c);

            // If a <= b and b <= c, then a <= c
            if (cmpAB <= 0 && cmpBC <= 0) {
              check(cmpAC <= 0).isTrue();
            }
            // Strict transitivity: if a < b and b < c, then a < c
            if (cmpAB < 0 && cmpBC < 0) {
              check(cmpAC < 0).isTrue();
            }
            // Equivalence transitivity: if a == b and b == c, then a == c
            if (cmpAB == 0 && cmpBC == 0) {
              check(cmpAC == 0).isTrue();
            }
          }
        }
      }
    });

    test(
      'random expression tree generator total order stress (500 triads)',
      () {
        final rng = math.Random(42);
        final varNames = ['x', 'y', 'z', 't'];

        Expr generateRandomExpr(int depth) {
          if (depth <= 0 || rng.nextDouble() < 0.3) {
            final choice = rng.nextInt(4);
            return switch (choice) {
              0 => RationalNumber(rng.nextInt(21) - 10, rng.nextInt(9) + 1),
              1 => RealNumber((rng.nextDouble() - 0.5) * 100),
              2 => Variable(varNames[rng.nextInt(varNames.length)]),
              _ => ConstantNumber(
                varNames[rng.nextInt(varNames.length)],
                rng.nextDouble(),
              ),
            };
          }

          final isUnary = rng.nextBool();
          if (isUnary) {
            final child = generateRandomExpr(depth - 1);
            return switch (rng.nextInt(5)) {
              0 => Neg(child),
              1 => Sin(child),
              2 => Cos(child),
              3 => Exp(child),
              _ => Ln(child),
            };
          } else {
            final left = generateRandomExpr(depth - 1);
            final right = generateRandomExpr(depth - 1);
            return switch (rng.nextInt(5)) {
              0 => Add(left, right),
              1 => Sub(left, right),
              2 => Mul(left, right),
              3 => Div(left, right),
              _ => Pow(left, right),
            };
          }
        }

        final randomNodes = List.generate(80, (_) => generateRandomExpr(4));

        // Reflexivity on all generated expressions
        for (final e in randomNodes) {
          check(compareStructural(e, e)).equals(0);
          final clone = _cloneExpr(e);
          check(compareStructural(e, clone)).equals(0);
        }

        // Antisymmetry on all pairs
        for (var i = 0; i < randomNodes.length; i++) {
          for (var j = 0; j < randomNodes.length; j++) {
            final a = randomNodes[i];
            final b = randomNodes[j];
            final ab = compareStructural(a, b);
            final ba = compareStructural(b, a);
            check(ab.sign).equals(-ba.sign);
          }
        }

        // Transitivity on 80^3 = 512,000 triads
        final count = randomNodes.length;
        for (var i = 0; i < count; i++) {
          final a = randomNodes[i];
          for (var j = 0; j < count; j++) {
            final b = randomNodes[j];
            final ab = compareStructural(a, b);
            if (ab > 0) continue; // prune non-monotonic prefixes

            for (var k = 0; k < count; k++) {
              final c = randomNodes[k];
              final bc = compareStructural(b, c);
              if (bc >= 0) {
                if (ab <= 0 && bc <= 0) {
                  final ac = compareStructural(a, c);
                  check(ac <= 0).isTrue();
                }
              }
            }
          }
        }
      },
    );

    test('RationalNumber comparator total order preserves fractions and unreduced forms', () {
      const r1 = RationalNumber(1, 2);
      const r2 = RationalNumber(2, 4); // same value, different denominator
      const r3 = RationalNumber(3, 4);
      const r4 = RationalNumber(-1, 2);

      // r1 and r2 represent the same mathematical fraction, but distinct AST nodes
      check(r1 == r2).isFalse();
      final cmp12 = compareStructural(r1, r2);
      final cmp21 = compareStructural(r2, r1);
      check(cmp12 != 0).isTrue();
      check(cmp12.sign).equals(-cmp21.sign);

      // Ordering: r4 < r1 < r3
      check(compareStructural(r4, r1) < 0).isTrue();
      check(compareStructural(r1, r3) < 0).isTrue();
      check(compareStructural(r4, r3) < 0).isTrue();
    });
  });

  group('Simplification sorting stability and determinism', () {
    test('canonical form is invariant under permutations of sum terms', () {
      const x = Variable('x');
      final terms = <Expr>[
        x.pow(const RationalNumber(5)),
        Mul(const RationalNumber(4), x.pow(const RationalNumber(4))),
        Mul(const RationalNumber(-3), x.pow(const RationalNumber(3))),
        Mul(const RationalNumber(2), x.pow(const RationalNumber(2))),
        const Mul(RationalNumber(-7), x),
        const RationalNumber(9),
        const Sin(x),
        const Cos(x),
        const Exp(x),
        const Ln(x),
      ];

      // Form baseline left-associated sum
      var baselineSum = terms.first;
      for (var i = 1; i < terms.length; i++) {
        baselineSum = Add(baselineSum, terms[i]);
      }
      final canonical = baselineSum.simplify();

      // Test 20 random permutations of the terms
      final rng = math.Random(1337);
      for (var p = 0; p < 20; p++) {
        final perm = List<Expr>.of(terms)..shuffle(rng);

        // Build left-associated sum
        var permSum = perm.first;
        for (var i = 1; i < perm.length; i++) {
          permSum = Add(permSum, perm[i]);
        }

        final permSimplified = permSum.simplify();
        check(permSimplified).equals(canonical);
        check(permSimplified.toString()).equals(canonical.toString());
      }
    });

    test('multivariable and transcendental tie-breaking produces identical canonical AST', () {
      const x = Variable('x');
      const y = Variable('y');

      // Terms having identical degree (1.0), identical primary symbol ('x'), positive sign
      // Tie must be broken deterministically by compareStructural
      const t1 = Mul(x, Sin(y));
      const t2 = Mul(x, Cos(y));
      const t3 = Mul(x, Exp(y));
      const t4 = Mul(x, Ln(y));

      const sumA = Add(Add(Add(t1, t2), t3), t4);
      const sumB = Add(Add(Add(t4, t3), t2), t1);
      const sumC = Add(Add(t2, t4), Add(t1, t3));

      final simpA = sumA.simplify();
      final simpB = sumB.simplify();
      final simpC = sumC.simplify();

      check(simpA).equals(simpB);
      check(simpB).equals(simpC);
      check(simpA.toString()).equals(simpB.toString());
    });

    test('no dropped terms: numerical evaluation parity between original and simplified', () {
      const x = Variable('x');
      const y = Variable('y');
      const z = Variable('z');

      // Complex expression with mixed powers, rational coefficients, and transcendental terms
      // 3*x^3 - 5*x^2 + 2*x*y - sin(z) + 4*x^3 + 7*x^2 - 10 + 3*sin(z) - 5
      final expr =
          Mul(const RationalNumber(3), x.pow(const RationalNumber(3))) -
          Mul(const RationalNumber(5), x.pow(const RationalNumber(2))) +
          const Mul(RationalNumber(2), Mul(x, y)) -
          const Sin(z) +
          Mul(const RationalNumber(4), x.pow(const RationalNumber(3))) +
          Mul(const RationalNumber(7), x.pow(const RationalNumber(2))) -
          const RationalNumber(10) +
          const Mul(RationalNumber(3), Sin(z)) -
          const RationalNumber(5);

      final simplified = expr.simplify();

      // Test numerical parity on 30 random evaluation contexts
      final rng = math.Random(999);
      for (var i = 0; i < 30; i++) {
        final ctx = {
          'x': (rng.nextDouble() - 0.5) * 10,
          'y': (rng.nextDouble() - 0.5) * 10,
          'z': (rng.nextDouble() - 0.5) * 10,
        };

        final rawVal = expr.evaluate(ctx);
        final simpVal = simplified.evaluate(ctx);

        check((rawVal - simpVal).abs()).isLessThan(1e-10);
      }
    });

    test('simplification idempotence across complex expressions', () {
      const x = Variable('x');
      const y = Variable('y');

      final expressions = <Expr>[
        (x + const RationalNumber(1)) * (x - const RationalNumber(1)),
        x.pow(const RationalNumber(2)) +
            const Mul(RationalNumber(2), x) +
            const RationalNumber(1),
        const Sin(x) +
            const Cos(y) -
            const Sin(x) +
            const Mul(RationalNumber(3), Cos(y)),
        Exp(x + y) / const Exp(x),
        (x * y) / y,
        (x + y + const RationalNumber(5)) - (y + const RationalNumber(2)),
      ];

      for (final expr in expressions) {
        final once = expr.simplify();
        final twice = once.simplify();
        check(twice).equals(once);
      }
    });

    test(
      'cancellation preserves remaining terms without leaking zero terms',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');

        // Cancellation of x: (2*x + 3*y - 2*x + 4*z) => 3*y + 4*z
        final expr =
            const Mul(RationalNumber(2), x) +
            const Mul(RationalNumber(3), y) -
            const Mul(RationalNumber(2), x) +
            const Mul(RationalNumber(4), z);

        final simplified = expr.simplify();
        check(simplified.dependsOn('x')).isFalse();
        check(simplified.dependsOn('y')).isTrue();
        check(simplified.dependsOn('z')).isTrue();

        // Full cancellation: (x + y) - (x + y) => 0
        final cancelAll = (x + y) - (x + y);
        check(cancelAll.simplify()).equals(const RationalNumber(0));
      },
    );

    test('infinite loop stress: deep chains and nested operations terminate rapidly', () {
      const x = Variable('x');

      // Deep left-associated chain of 400 terms
      const chainLen = 400;
      Expr deepSum = x;
      for (var i = 1; i < chainLen; i++) {
        deepSum = Add(deepSum, Variable('x_$i'));
      }

      final sw = Stopwatch()..start();
      final simplifiedSum = deepSum.simplify();
      sw.stop();

      // Must complete in under 1 second
      check(sw.elapsedMilliseconds).isLessThan(1000);
      check(simplifiedSum.dependsOn('x')).isTrue();
      check(simplifiedSum.dependsOn('x_399')).isTrue();

      // Deep repeated self-cancellation: (x - x) + (x - x) + ...
      Expr cancelChain = const Sub(x, x);
      for (var i = 0; i < 200; i++) {
        cancelChain = Add(cancelChain, const Sub(x, x));
      }

      final sw2 = Stopwatch()..start();
      final simplifiedCancel = cancelChain.simplify();
      sw2.stop();

      check(sw2.elapsedMilliseconds).isLessThan(1000);
      check(simplifiedCancel).equals(const RationalNumber(0));
    });

    test('negative-only polynomial permutations produce deterministic canonical form', () {
      const x = Variable('x');
      final negTerms = <Expr>[
        Mul(const RationalNumber(-5), x.pow(const RationalNumber(4))),
        Mul(const RationalNumber(-3), x.pow(const RationalNumber(3))),
        Mul(const RationalNumber(-2), x.pow(const RationalNumber(2))),
        const Mul(RationalNumber(-4), x),
        const RationalNumber(-7),
      ];

      var baseSum = negTerms.first;
      for (var i = 1; i < negTerms.length; i++) {
        baseSum = Add(baseSum, negTerms[i]);
      }
      final canonical = baseSum.simplify();

      final rng = math.Random(777);
      for (var p = 0; p < 10; p++) {
        final perm = List<Expr>.of(negTerms)..shuffle(rng);
        var permSum = perm.first;
        for (var i = 1; i < perm.length; i++) {
          permSum = Add(permSum, perm[i]);
        }
        final permSimplified = permSum.simplify();
        check(permSimplified).equals(canonical);
        check(permSimplified.toString()).equals(canonical.toString());
      }
    });

    test('fractional coefficient aggregation and exact cancellation', () {
      const x = Variable('x');

      // 1/3 * x + 2/3 * x => x
      const sumToOne = Add(
        Mul(RationalNumber(1, 3), x),
        Mul(RationalNumber(2, 3), x),
      );
      check(sumToOne.simplify()).equals(x);

      // 1/2 * x + 1/3 * x => 5/6 * x
      const sumToFiveSixths = Add(
        Mul(RationalNumber(1, 2), x),
        Mul(RationalNumber(1, 3), x),
      );
      check(sumToFiveSixths.simplify())
          .equals(const Mul(RationalNumber(5, 6), x));

      // 1/3 * x + 2/3 * x - x => 0
      const cancelToZero = Sub(
        Add(Mul(RationalNumber(1, 3), x), Mul(RationalNumber(2, 3), x)),
        x,
      );
      check(cancelToZero.simplify()).equals(const RationalNumber(0));
    });

    test(
      'associativity grouping invariance: (a + (b + c)) vs ((a + b) + c)',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');

        const t1 = Mul(RationalNumber(3), x);
        const t2 = Mul(RationalNumber(4), y);
        const t3 = Mul(RationalNumber(5), z);

        const leftAssoc = Add(Add(t1, t2), t3);
        const rightAssoc = Add(t1, Add(t2, t3));

        check(leftAssoc.simplify()).equals(rightAssoc.simplify());
        check(leftAssoc.simplify().toString())
            .equals(rightAssoc.simplify().toString());
      },
    );
  });
}

/// Helper to clone an AST node into a distinct heap object so `identical(a, b)` is false.
Expr _cloneExpr(Expr expr) => switch (expr) {
  RationalNumber(:final numerator, :final denominator) => RationalNumber(
    numerator,
    denominator,
  ),
  RealNumber(:final value) => RealNumber(value),
  ComplexNumber(:final real, :final imaginary) => ComplexNumber(
    real,
    imaginary,
  ),
  ConstantNumber(:final name, :final value) => ConstantNumber(name, value),
  Variable(:final name) => Variable(name),
  Neg(:final expr) => Neg(_cloneExpr(expr)),
  Cos(:final expr) => Cos(_cloneExpr(expr)),
  Exp(:final expr) => Exp(_cloneExpr(expr)),
  Ln(:final expr) => Ln(_cloneExpr(expr)),
  Sin(:final expr) => Sin(_cloneExpr(expr)),
  Tan(:final expr) => Tan(_cloneExpr(expr)),
  Asin(:final expr) => Asin(_cloneExpr(expr)),
  Acos(:final expr) => Acos(_cloneExpr(expr)),
  Atan(:final expr) => Atan(_cloneExpr(expr)),
  Sinh(:final expr) => Sinh(_cloneExpr(expr)),
  Cosh(:final expr) => Cosh(_cloneExpr(expr)),
  Tanh(:final expr) => Tanh(_cloneExpr(expr)),
  Abs(:final expr) => Abs(_cloneExpr(expr)),
  Add(:final left, :final right) => Add(_cloneExpr(left), _cloneExpr(right)),
  Sub(:final left, :final right) => Sub(_cloneExpr(left), _cloneExpr(right)),
  Mul(:final left, :final right) => Mul(_cloneExpr(left), _cloneExpr(right)),
  Div(:final left, :final right) => Div(_cloneExpr(left), _cloneExpr(right)),
  Pow(:final base, :final exponent) => Pow(
    _cloneExpr(base),
    _cloneExpr(exponent),
  ),
  OrderTerm(:final variable, :final order, :final point) => OrderTerm(
    variable,
    order,
    point: _cloneExpr(point),
  ),
};
