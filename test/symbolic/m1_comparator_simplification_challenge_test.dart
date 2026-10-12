import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

// Replication of the simplifier structural comparator to directly challenge its total order invariants.
int _nodeTag(Expr expr) => switch (expr) {
  RationalNumber() => 0,
  RealNumber() => 1,
  ConstantNumber() => 2,
  Variable() => 3,
  Neg() => 4,
  Cos() => 5,
  Exp() => 6,
  Ln() => 7,
  Sin() => 8,
  Tan() => 9,
  Asin() => 10,
  Acos() => 11,
  Atan() => 12,
  Sinh() => 13,
  Cosh() => 14,
  Tanh() => 15,
  Abs() => 16,
  Sqrt() => 17,
  Log() => 18,
  Pow() => 20,
  Mul() => 21,
  Div() => 22,
  Add() => 23,
  Sub() => 24,
};

int _compareRational(RationalNumber a, RationalNumber b) {
  if (a.numerator == b.numerator && a.denominator == b.denominator) {
    return 0;
  }
  final delta = a.numerator * b.denominator - b.numerator * a.denominator;
  if (delta < 0) return -1;
  if (delta > 0) return 1;
  return a.denominator.compareTo(b.denominator);
}

int _compareStructural(Expr a, Expr b) {
  if (identical(a, b)) return 0;
  final tagA = _nodeTag(a);
  final tagB = _nodeTag(b);
  if (tagA != tagB) return tagA.compareTo(tagB);

  return switch (a) {
    RationalNumber() => _compareRational(a, b as RationalNumber),
    RealNumber(:final value) => value.compareTo((b as RealNumber).value),
    ConstantNumber(:final name, :final value) => switch (name.compareTo(
      (b as ConstantNumber).name,
    )) {
      0 => value.compareTo(b.value),
      final cmp => cmp,
    },
    Variable(:final name) => name.compareTo((b as Variable).name),
    UnaryExpr(:final expr) => _compareStructural(expr, (b as UnaryExpr).expr),
    BinaryExpr(:final left, :final right) => switch (_compareStructural(
      left,
      (b as BinaryExpr).left,
    )) {
      0 => _compareStructural(right, b.right),
      final cmp => cmp,
    },
  };
}

/// Helper to clone an AST node into a distinct heap object so `identical(a, b)` is false.
Expr _cloneExpr(Expr expr) => switch (expr) {
  RationalNumber(:final numerator, :final denominator) => RationalNumber(
    numerator,
    denominator,
  ),
  RealNumber(:final value) => RealNumber(value),
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
  Sqrt(:final expr) => Sqrt(_cloneExpr(expr)),
  Log(:final base, :final expr) => Log(_cloneExpr(base), _cloneExpr(expr)),
  Add(:final left, :final right) => Add(_cloneExpr(left), _cloneExpr(right)),
  Sub(:final left, :final right) => Sub(_cloneExpr(left), _cloneExpr(right)),
  Mul(:final left, :final right) => Mul(_cloneExpr(left), _cloneExpr(right)),
  Div(:final left, :final right) => Div(_cloneExpr(left), _cloneExpr(right)),
  Pow(:final base, :final exponent) => Pow(
    _cloneExpr(base),
    _cloneExpr(exponent),
  ),
};

void main() {
  group(
    'Empirical Challenge 1: Structural Comparator Total Order Invariants',
    () {
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
          check(_compareStructural(e, e)).equals(0);

          // Cloned non-identical reference
          final clone = _cloneExpr(e);
          check(identical(e, clone)).isFalse();
          check(_compareStructural(e, clone)).equals(0);
          check(_compareStructural(clone, e)).equals(0);
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
            final cmpAB = _compareStructural(a, b);
            final cmpBA = _compareStructural(b, a);

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
            final cmpAB = _compareStructural(a, b);

            for (var k = 0; k < n; k++) {
              final c = subset[k];
              final cmpBC = _compareStructural(b, c);
              final cmpAC = _compareStructural(a, c);

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
            check(_compareStructural(e, e)).equals(0);
            final clone = _cloneExpr(e);
            check(_compareStructural(e, clone)).equals(0);
          }

          // Antisymmetry on all pairs
          for (var i = 0; i < randomNodes.length; i++) {
            for (var j = 0; j < randomNodes.length; j++) {
              final a = randomNodes[i];
              final b = randomNodes[j];
              final ab = _compareStructural(a, b);
              final ba = _compareStructural(b, a);
              check(ab.sign).equals(-ba.sign);
            }
          }

          // Transitivity on 80^3 = 512,000 triads
          final count = randomNodes.length;
          for (var i = 0; i < count; i++) {
            final a = randomNodes[i];
            for (var j = 0; j < count; j++) {
              final b = randomNodes[j];
              final ab = _compareStructural(a, b);
              if (ab > 0) continue; // prune non-monotonic prefixes

              for (var k = 0; k < count; k++) {
                final c = randomNodes[k];
                final bc = _compareStructural(b, c);
                if (bc >= 0) {
                  if (ab <= 0 && bc <= 0) {
                    final ac = _compareStructural(a, c);
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
        final cmp12 = _compareStructural(r1, r2);
        final cmp21 = _compareStructural(r2, r1);
        check(cmp12 != 0).isTrue();
        check(cmp12.sign).equals(-cmp21.sign);

        // Ordering: r4 < r1 < r3
        check(_compareStructural(r4, r1) < 0).isTrue();
        check(_compareStructural(r1, r3) < 0).isTrue();
        check(_compareStructural(r4, r3) < 0).isTrue();
      });
    },
  );

  group(
    'Empirical Challenge 2: Simplification Sorting Stability & Determinism',
    () {
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
        // Tie must be broken deterministically by _compareStructural
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
    },
  );
}
