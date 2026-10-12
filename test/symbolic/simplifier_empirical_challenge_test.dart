import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Empirical Challenge 1.1: Pythagorean Reductions', () {
    const x = Variable('x');

    test(r'sin^2(x) + cos^2(x) -> 1', () {
      final expr1 = Expr.parse('sin(x)^2 + cos(x)^2');
      check(expr1.simplify()).equals(RationalNumber.one);

      final expr2 = Expr.parse('cos(x)^2 + sin(x)^2');
      check(expr2.simplify()).equals(RationalNumber.one);
    });

    test(r'5*sin^2(x) + 5*cos^2(x) -> 5', () {
      final expr = Expr.parse('5 * sin(x)^2 + 5 * cos(x)^2');
      check(expr.simplify()).equals(const RationalNumber(5));

      final exprReversed = Expr.parse('5 * cos(x)^2 + 5 * sin(x)^2');
      check(exprReversed.simplify()).equals(const RationalNumber(5));
    });

    test(r'1 - sin^2(x) -> cos^2(x) and 1 - cos^2(x) -> sin^2(x)', () {
      final exprSin = Expr.parse('1 - sin(x)^2');
      check(exprSin.simplify()).equals(const Pow(Cos(x), RationalNumber(2)));

      final exprCos = Expr.parse('1 - cos(x)^2');
      check(exprCos.simplify()).equals(const Pow(Sin(x), RationalNumber(2)));
    });

    test(r'cosh^2(x) - sinh^2(x) -> 1', () {
      final expr = Expr.parse('cosh(x)^2 - sinh(x)^2');
      check(expr.simplify()).equals(RationalNumber.one);

      final exprPlus = Expr.parse('1 + sinh(x)^2');
      check(exprPlus.simplify()).equals(const Pow(Cosh(x), RationalNumber(2)));

      final exprMinus = Expr.parse('cosh(x)^2 - 1');
      check(exprMinus.simplify()).equals(const Pow(Sinh(x), RationalNumber(2)));
    });

    test('Pythagorean identity with complex composite arguments', () {
      final expr = Expr.parse('sin(x * y + 3)^2 + cos(x * y + 3)^2');
      check(expr.simplify()).equals(RationalNumber.one);

      final exprH = Expr.parse('cosh(2 * x + y)^2 - sinh(2 * x + y)^2');
      check(exprH.simplify()).equals(RationalNumber.one);
    });

    test('Negative coefficient Pythagorean: -sin^2(x) - cos^2(x) -> -1', () {
      final expr = Expr.parse('-sin(x)^2 - cos(x)^2');
      check(expr.simplify()).equals(RationalNumber.negativeOne);
    });

    test('Partial Pythagorean reduction: 5*sin^2(x) + 3*cos^2(x) -> 2*sin^2(x) + 3', () {
      final expr = Expr.parse('5 * sin(x)^2 + 3 * cos(x)^2');
      check(expr.simplify()).equals(
        const Add(
          Mul(RationalNumber(2), Pow(Sin(x), RationalNumber(2))),
          RationalNumber(3),
        ),
      );
    });
  });

  group('Empirical Challenge 1.2: Exponential & Logarithmic Reductions', () {
    const x = Variable('x');
    const a = Variable('a');
    const b = Variable('b');

    test(r'e^(ln(x)) -> x', () {
      final expr = Expr.parse('exp(ln(x))');
      check(expr.simplify()).equals(x);
    });

    test(r'e^(5*ln(x)) -> x^5', () {
      final expr = Expr.parse('exp(5 * ln(x))');
      check(expr.simplify()).equals(const Pow(x, RationalNumber(5)));

      final exprReversed = Expr.parse('exp(ln(x) * 5)');
      check(exprReversed.simplify()).equals(const Pow(x, RationalNumber(5)));
    });

    test(r'e^(-ln(x)) -> x^(-1)', () {
      final expr = Expr.parse('exp(-ln(x))');
      check(expr.simplify()).equals(const Pow(x, RationalNumber.negativeOne));
    });

    test(r'ln(e^x) -> x', () {
      final expr = Expr.parse('ln(exp(x))');
      check(expr.simplify()).equals(x);
    });

    test(r'ln(x^3) -> 3*ln(x)', () {
      final expr = Expr.parse('ln(x^3)');
      check(expr.simplify()).equals(const Mul(RationalNumber(3), Ln(x)));
    });

    test(r'ln(a) + ln(b) -> ln(a * b)', () {
      final expr = Expr.parse('ln(a) + ln(b)');
      check(expr.simplify()).equals(const Ln(Mul(a, b)));
    });

    test(r'ln(a) - ln(b) -> ln(a / b)', () {
      final expr = Expr.parse('ln(a) - ln(b)');
      check(expr.simplify()).equals(const Ln(Div(a, b)));
    });

    test('Multi-term log product aggregation: ln(a) + ln(b) + ln(c) -> ln(a * b * c)', () {
      final expr = Expr.parse('ln(a) + ln(b) + ln(c)');
      final simplified = expr.simplify();
      check(simplified).isA<Ln>();
      // Evaluate parity on test values
      final env = {'a': 2.0, 'b': 3.0, 'c': 5.0};
      check((expr.evaluate(env) - simplified.evaluate(env)).abs())
          .isLessThan(1e-12);
    });

    test('Multi-term log quotient aggregation: ln(a) - ln(b) - ln(c)', () {
      final expr = Expr.parse('ln(a) - ln(b) - ln(c)');
      final simplified = expr.simplify();
      check(simplified).isA<Ln>();
      final env = {'a': 12.0, 'b': 3.0, 'c': 2.0};
      check((expr.evaluate(env) - simplified.evaluate(env)).abs())
          .isLessThan(1e-12);
    });

    test('Constant log and exp evaluations', () {
      check(Expr.parse('ln(1)').simplify()).equals(RationalNumber.zero);
      check(Expr.parse('ln(e)').simplify()).equals(RationalNumber.one);
      check(Expr.parse('exp(0)').simplify()).equals(RationalNumber.one);
      check(Expr.parse('exp(1)').simplify()).equals(ConstantNumber.e);
      check(Expr.parse('log(2, 1)').simplify()).equals(RationalNumber.zero);
      check(Expr.parse('log(5, 5)').simplify()).equals(RationalNumber.one);
      check(Expr.parse('log(x, x^4)').simplify())
          .equals(const RationalNumber(4));
    });
  });

  group(
    'Empirical Challenge 1.3: Parity Symmetry with Negative Multipliers',
    () {
      const x = Variable('x');

      test(r'sin(-5x) -> -sin(5x) (NOT -5*sin(x))', () {
        final expr1 = Expr.parse('sin(-5 * x)');
        final s1 = expr1.simplify();
        check(s1).equals(const Neg(Sin(Mul(RationalNumber(5), x))));

        final expr2 = Expr.parse('sin(-(5 * x))');
        final s2 = expr2.simplify();
        check(s2).equals(const Neg(Sin(Mul(RationalNumber(5), x))));

        // Crucial mathematical invariant: sin(-5x) != -5*sin(x)
        const wrongSymmetry = Mul(RationalNumber(-5), Sin(x));
        check(s1).not((it) => it.equals(wrongSymmetry));

        // Numerical verification across test points
        for (final testVal in [0.1, 0.5, 1.2, 2.5]) {
          final valOriginal = expr1.evaluate({'x': testVal});
          final valSimplified = s1.evaluate({'x': testVal});
          check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
        }
      });

      test(r'cos(-5x) -> cos(5x)', () {
        final expr = Expr.parse('cos(-5 * x)');
        final s = expr.simplify();
        check(s).equals(const Cos(Mul(RationalNumber(5), x)));

        for (final testVal in [0.1, 0.5, 1.2, 2.5]) {
          final valOriginal = expr.evaluate({'x': testVal});
          final valSimplified = s.evaluate({'x': testVal});
          check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
        }
      });

      test(r'tan(-5x) -> -tan(5x)', () {
        final expr = Expr.parse('tan(-5 * x)');
        final s = expr.simplify();
        check(s).equals(const Neg(Tan(Mul(RationalNumber(5), x))));

        for (final testVal in [0.1, 0.2, 0.3]) {
          final valOriginal = expr.evaluate({'x': testVal});
          final valSimplified = s.evaluate({'x': testVal});
          check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
        }
      });

      test(r'sinh(-5x) -> -sinh(5x)', () {
        final expr = Expr.parse('sinh(-5 * x)');
        final s = expr.simplify();
        check(s).equals(const Neg(Sinh(Mul(RationalNumber(5), x))));

        for (final testVal in [0.1, 0.5, 1.0]) {
          final valOriginal = expr.evaluate({'x': testVal});
          final valSimplified = s.evaluate({'x': testVal});
          check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
        }
      });

      test(r'cosh(-5x) -> cosh(5x)', () {
        final expr = Expr.parse('cosh(-5 * x)');
        final s = expr.simplify();
        check(s).equals(const Cosh(Mul(RationalNumber(5), x)));

        for (final testVal in [0.1, 0.5, 1.0]) {
          final valOriginal = expr.evaluate({'x': testVal});
          final valSimplified = s.evaluate({'x': testVal});
          check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
        }
      });

      test(r'tanh(-5x) -> -tanh(5x)', () {
        final expr = Expr.parse('tanh(-5 * x)');
        final s = expr.simplify();
        check(s).equals(const Neg(Tanh(Mul(RationalNumber(5), x))));

        for (final testVal in [0.1, 0.5, 1.0]) {
          final valOriginal = expr.evaluate({'x': testVal});
          final valSimplified = s.evaluate({'x': testVal});
          check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
        }
      });

      test(r'abs(-5x) -> abs(5x)', () {
        final expr = Expr.parse('abs(-5 * x)');
        final s = expr.simplify();
        check(s).equals(const Abs(Mul(RationalNumber(5), x)));

        for (final testVal in [-2.0, -0.5, 1.5]) {
          final valOriginal = expr.evaluate({'x': testVal});
          final valSimplified = s.evaluate({'x': testVal});
          check((valOriginal - valSimplified).abs()).isLessThan(1e-12);
        }
      });
    },
  );

  group('Empirical Challenge 1.4: Simplification Idempotence Generator', () {
    // Generate random expressions of various structures and test:
    // expr.simplify().simplify() == expr.simplify()
    Expr generateRandomExpr(math.Random rand, int depth) {
      if (depth <= 0) {
        final leafType = rand.nextInt(5);
        return switch (leafType) {
          0 => const Variable('x'),
          1 => const Variable('y'),
          2 => RationalNumber(rand.nextInt(7) - 3),
          3 => ConstantNumber.pi,
          _ => ConstantNumber.e,
        };
      }

      final opType = rand.nextInt(17);
      return switch (opType) {
        0 => Add(
          generateRandomExpr(rand, depth - 1),
          generateRandomExpr(rand, depth - 1),
        ),
        1 => Sub(
          generateRandomExpr(rand, depth - 1),
          generateRandomExpr(rand, depth - 1),
        ),
        2 => Mul(
          generateRandomExpr(rand, depth - 1),
          generateRandomExpr(rand, depth - 1),
        ),
        3 => Div(
          generateRandomExpr(rand, depth - 1),
          RationalNumber(rand.nextInt(5) + 1),
        ),
        4 => Pow(
          generateRandomExpr(rand, depth - 1),
          RationalNumber(rand.nextInt(3) + 1),
        ),
        5 => Neg(generateRandomExpr(rand, depth - 1)),
        6 => Sin(generateRandomExpr(rand, depth - 1)),
        7 => Cos(generateRandomExpr(rand, depth - 1)),
        8 => Tan(generateRandomExpr(rand, depth - 1)),
        9 => Asin(generateRandomExpr(rand, depth - 1)),
        10 => Atan(generateRandomExpr(rand, depth - 1)),
        11 => Sinh(generateRandomExpr(rand, depth - 1)),
        12 => Cosh(generateRandomExpr(rand, depth - 1)),
        13 => Tanh(generateRandomExpr(rand, depth - 1)),
        14 => Abs(generateRandomExpr(rand, depth - 1)),
        15 => Pow(
          Add(
            Pow(generateRandomExpr(rand, depth - 1), const RationalNumber(2)),
            const RationalNumber(1),
          ),
          const RationalNumber(1, 2),
        ),
        _ => Exp(generateRandomExpr(rand, depth - 1)),
      };
    }

    test('1000 combinatorial random expressions satisfy expr.simplify().simplify() == expr.simplify()', () {
      final rand = math.Random(42);
      var validCount = 0;

      for (var i = 0; i < 1000; i++) {
        final depth = 1 + rand.nextInt(3);
        final expr = generateRandomExpr(rand, depth);

        try {
          final s1 = expr.simplify();
          final s2 = s1.simplify();
          check(s2).equals(s1);
          validCount++;
        } on UnsupportedError {
          // Div by 0
        } on ArgumentError {
          // Domain error
        }
      }

      check(validCount).isGreaterThan(950);
    });
  });

  group('Empirical Challenge 2: Parser & Textualization Round-Trip', () {
    test('parses complex expression containing all new and existing operations', () {
      const input =
          'tan(x + 1) + sinh(2 * y) * cosh(z) / tanh(w) - abs(acos(u)) + sqrt(asin(v)) + log(2, atan(t)) + root(3, s)';
      final parsed = Expr.parse(input);
      check(parsed).isA<Expr>();

      // Check all variables are identified
      check(parsed.freeVariables)
          .unorderedEquals({'x', 'y', 'z', 'w', 'u', 'v', 't', 's'});

      // LaTeX serialization
      final latex = parsed.toLatex();
      check(latex).contains(r'\tan(x + 1)');
      check(latex).contains(r'\sinh(2 \cdot y)');
      check(latex).contains(r'\cosh(z)');
      check(latex).contains(r'\tanh(w)');
      check(latex).contains(r'\left|\arccos(u)\right|');
      check(latex).contains(r'\sqrt{\arcsin(v)}');
      check(latex).contains(r'\log_{2}(\arctan(t))');
      check(latex).contains(r'{s}^{\frac{1}{3}}');

      // Simplified LaTeX folds Div(1, 3) into RationalNumber(1, 3) -> \sqrt[3]{s}
      final simplifiedLatex = parsed.simplify().toLatex();
      check(simplifiedLatex).contains(r'\sqrt[3]{s}');

      // MathML serialization
      final mathml = parsed.toMathMl();
      check(mathml).startsWith('<math>');
      check(mathml).endsWith('</math>');
      check(mathml).contains('<mi>tan</mi>');
      check(mathml).contains('<mi>sinh</mi>');
      check(mathml).contains('<mi>cosh</mi>');
      check(mathml).contains('<mi>tanh</mi>');
      check(mathml).contains('<mo>|</mo>');
      check(mathml).contains('<mi>arccos</mi>');
      check(mathml).contains('<msqrt>');
      check(mathml).contains('<mi>arcsin</mi>');
      check(mathml).contains('<msub><mi>log</mi><mn>2</mn></msub>');
      check(mathml).contains('<mi>arctan</mi>');

      final simplifiedMathMl = parsed.simplify().toMathMl();
      check(simplifiedMathMl).contains(
        '<mroot><mrow><mi>s</mi></mrow><mrow><mn>3</mn></mrow></mroot>',
      );

      // String formatting round-trip
      final str = parsed.toString();
      final reparsed = Expr.parse(str);
      check(reparsed.freeVariables).unorderedEquals(parsed.freeVariables);

      final testEnv = {
        'x': 0.1,
        'y': 0.2,
        'z': 0.3,
        'w': 0.4,
        'u': 0.5,
        'v': 0.6,
        't': 0.7,
        's': 8.0,
      };
      final valOriginal = parsed.evaluate(testEnv);
      final valReparsed = reparsed.evaluate(testEnv);
      check((valOriginal - valReparsed).abs()).isLessThan(1e-12);
    });

    test('LaTeX and MathML formatting for all 10 new operations with nested arguments', () {
      final tests = <String, (String, String)>{
        'tan(x)': (
          r'\tan(x)',
          '<mrow><mi>tan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
        ),
        'asin(x)': (
          r'\arcsin(x)',
          '<mrow><mi>arcsin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
        ),
        'acos(x)': (
          r'\arccos(x)',
          '<mrow><mi>arccos</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
        ),
        'atan(x)': (
          r'\arctan(x)',
          '<mrow><mi>arctan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
        ),
        'sinh(x)': (
          r'\sinh(x)',
          '<mrow><mi>sinh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
        ),
        'cosh(x)': (
          r'\cosh(x)',
          '<mrow><mi>cosh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
        ),
        'tanh(x)': (
          r'\tanh(x)',
          '<mrow><mi>tanh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
        ),
        'abs(x)': (
          r'\left|x\right|',
          '<mrow><mo>|</mo><mi>x</mi><mo>|</mo></mrow>',
        ),
        'sqrt(x)': (r'\sqrt{x}', '<msqrt><mrow><mi>x</mi></mrow></msqrt>'),
        'log(10, x)': (
          r'\log_{10}(x)',
          '<mrow><msub><mi>log</mi><mn>10</mn></msub><mo>(</mo><mi>x</mi><mo>)</mo></mrow>',
        ),
      };

      for (final entry in tests.entries) {
        final parsed = Expr.parse(entry.key);
        final (expectedLatex, expectedMathMlInner) = entry.value;
        check(parsed.toLatex()).equals(expectedLatex);
        check(parsed.toMathMl(root: false)).equals(expectedMathMlInner);
      }
    });

    test(
      'String formatting round-trip invariance across variety of functions',
      () {
        final expressions = [
          'tan(2 * x + 1)',
          'sinh(x) / cosh(x)',
          'asin(x / 2) + acos(x / 2)',
          'atan(x) * tanh(y)',
          'abs(x - y) + sqrt(x^2 + y^2)',
          'log(2, x + 1) - log(10, y + 1)',
          'exp(-x^2) * sin(pi * x)',
        ];

        for (final exprStr in expressions) {
          final parsed = Expr.parse(exprStr);
          final formatted = parsed.toString();
          final reparsed = Expr.parse(formatted);

          final env = {'x': 0.3, 'y': 0.7};
          final originalVal = parsed.evaluate(env);
          final reparsedVal = reparsed.evaluate(env);
          check((originalVal - reparsedVal).abs()).isLessThan(1e-12);
        }
      },
    );

    test('Parser arity validation', () {
      check(() => Expr.parse('tan(x, y)')).throws<FormatException>();
      check(() => Expr.parse('sin(x, y)')).throws<FormatException>();
      check(() => Expr.parse('cosh(x, y)')).throws<FormatException>();
      check(() => Expr.parse('abs(x, y)')).throws<FormatException>();
      check(() => Expr.parse('sqrt(x, y)')).throws<FormatException>();
      check(() => Expr.parse('log(2, 3, 4)')).throws<FormatException>();
      check(() => Expr.parse('root(2, 3, 4)')).throws<FormatException>();
      check(() => Expr.parse('root(2)')).throws<FormatException>();
    });
  });

  group(
    'Empirical Challenge 3: Parity Cancellation & Confluence Invariants',
    () {
      const x = Variable('x');

      test('Parity cancellations reduce to zero', () {
        check(Expr.parse('sin(-x) + sin(x)').simplify())
            .equals(RationalNumber.zero);
        check(Expr.parse('cos(-x) - cos(x)').simplify())
            .equals(RationalNumber.zero);
        check(Expr.parse('tan(-x) + tan(x)').simplify())
            .equals(RationalNumber.zero);
        check(Expr.parse('sinh(-x) + sinh(x)').simplify())
            .equals(RationalNumber.zero);
        check(Expr.parse('cosh(-x) - cosh(x)').simplify())
            .equals(RationalNumber.zero);
        check(Expr.parse('tanh(-x) + tanh(x)').simplify())
            .equals(RationalNumber.zero);
        check(Expr.parse('asin(-x) + asin(x)').simplify())
            .equals(RationalNumber.zero);
        check(Expr.parse('atan(-x) + atan(x)').simplify())
            .equals(RationalNumber.zero);
      });

      test('Confluence and term-ordering permutation invariance', () {
        final s1 = Expr.parse('sin(x)^2 + cos(x)^2 + x').simplify();
        final s2 = Expr.parse('x + cos(x)^2 + sin(x)^2').simplify();
        final s3 = Expr.parse('cos(x)^2 + x + sin(x)^2').simplify();
        check(s1).equals(s2);
        check(s2).equals(s3);
        check(s1).equals(const Add(x, RationalNumber.one));

        // In logarithms, addition sorts terms canonically, while product maintains operand order:
        // ln(a) + ln(b) -> ln(a * b), while ln(b) + ln(a) -> ln(b * a)
        final l1 = Expr.parse('ln(a) + ln(b) + x').simplify();
        final l2 = Expr.parse('x + ln(b) + ln(a)').simplify();
        check(l1).equals(Expr.parse('x + ln(a * b)'));
        check(l2).equals(Expr.parse('x + ln(b * a)'));

        // Both evaluate to identical values across all inputs
        final env = {'x': 1.5, 'a': 2.3, 'b': 4.7};
        check((l1.evaluate(env) - l2.evaluate(env)).abs()).isLessThan(1e-12);
      });

      test('Involutions reduce canonically to inner variable', () {
        check(Expr.parse('sin(asin(x))').simplify()).equals(x);
        check(Expr.parse('asin(sin(x))').simplify()).equals(x);
        check(Expr.parse('cos(acos(x))').simplify()).equals(x);
        check(Expr.parse('acos(cos(x))').simplify()).equals(x);
        check(Expr.parse('tan(atan(x))').simplify()).equals(x);
        check(Expr.parse('atan(tan(x))').simplify()).equals(x);
        check(Expr.parse('abs(abs(x))').simplify()).equals(const Abs(x));
        check(Expr.parse('abs(exp(x))').simplify()).equals(const Exp(x));
        check(Expr.parse('sqrt(x^2)').simplify()).equals(const Abs(x));
        check(Expr.parse('sqrt(x)^2').simplify()).equals(x);
      });
    },
  );
}
