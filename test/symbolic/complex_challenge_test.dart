import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  group('Dimension 1: Cyclic Powers of i and -i', () {
    test('positive integer exponents of i across full modulo-4 cycles', () {
      for (var k = 0; k < 20; k++) {
        final expected = switch (k % 4) {
          0 => RationalNumber.one,
          1 => ConstantNumber.i,
          2 => RationalNumber.negativeOne,
          3 => const Neg(ConstantNumber.i),
          _ => throw StateError('Unreachable'),
        };
        check(i.pow(k).simplify()).equals(expected);
      }
    });

    test('large positive and negative powers of i', () {
      check(i.pow(1000000).simplify()).equals(RationalNumber.one);
      check(i.pow(1000001).simplify()).equals(i);
      check(i.pow(1000002).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(1000003).simplify()).equals(-i);

      check(i.pow(1000000007).simplify()).equals(-i); // 1000000007 % 4 == 3

      check(i.pow(-1).simplify()).equals(-i);
      check(i.pow(-2).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(-3).simplify()).equals(i);
      check(i.pow(-4).simplify()).equals(RationalNumber.one);
      check(i.pow(-1000000).simplify()).equals(RationalNumber.one);
      check(i.pow(-1000000007).simplify()).equals(i); // -1000000007 % 4 == 1
    });

    test('powers of -i across full modulo-4 cycles', () {
      for (var k = 0; k < 20; k++) {
        final expected = switch (k % 4) {
          0 => RationalNumber.one,
          1 => const Neg(ConstantNumber.i),
          2 => RationalNumber.negativeOne,
          3 => ConstantNumber.i,
          _ => throw StateError('Unreachable'),
        };
        check((-i).pow(k).simplify()).equals(expected);
      }
    });

    test('large positive and negative powers of -i', () {
      check((-i).pow(1000000).simplify()).equals(RationalNumber.one);
      check((-i).pow(1000001).simplify()).equals(-i);
      check((-i).pow(1000002).simplify()).equals(RationalNumber.negativeOne);
      check((-i).pow(1000003).simplify()).equals(i);

      check((-i).pow(-1).simplify()).equals(i);
      check((-i).pow(-2).simplify()).equals(RationalNumber.negativeOne);
      check((-i).pow(-3).simplify()).equals(-i);
      check((-i).pow(-4).simplify()).equals(RationalNumber.one);
      check((-i).pow(-1000000).simplify()).equals(RationalNumber.one);
    });

    test('real number exponent powers of i', () {
      check(i.pow(const RealNumber(0.0)).simplify()).equals(RationalNumber.one);
      check(i.pow(const RealNumber(1.0)).simplify()).equals(i);
      check(i.pow(const RealNumber(2.0)).simplify())
          .equals(RationalNumber.negativeOne);
      check(i.pow(const RealNumber(3.0)).simplify()).equals(-i);
      check(i.pow(const RealNumber(4.0)).simplify()).equals(RationalNumber.one);
      check(i.pow(const RealNumber(-1.0)).simplify()).equals(-i);
      check(i.pow(const RealNumber(-2.0)).simplify())
          .equals(RationalNumber.negativeOne);
      check(i.pow(const RealNumber(-3.0)).simplify()).equals(i);
      check(i.pow(const RealNumber(-4.0)).simplify())
          .equals(RationalNumber.one);

      check((-i).pow(const RealNumber(1.0)).simplify()).equals(-i);
      check((-i).pow(const RealNumber(2.0)).simplify())
          .equals(RationalNumber.negativeOne);
      check((-i).pow(const RealNumber(3.0)).simplify()).equals(i);
      check((-i).pow(const RealNumber(4.0)).simplify())
          .equals(RationalNumber.one);
    });

    test('powers of scaled imaginary terms (c * i)^k', () {
      check((const RationalNumber(3) * i).pow(0).simplify())
          .equals(RationalNumber.one);
      check((const RationalNumber(3) * i).pow(1).simplify())
          .equals(const RationalNumber(3) * i);
      check((const RationalNumber(3) * i).pow(2).simplify())
          .equals(const RationalNumber(-9));
      check((const RationalNumber(3) * i).pow(3).simplify())
          .equals(const RationalNumber(-27) * i);
      check((const RationalNumber(3) * i).pow(4).simplify())
          .equals(const RationalNumber(81));
    });

    test('fractional powers evaluation of i and negative reals', () {
      // i^(1/2) = e^(i * pi / 4) = cos(pi/4) + i * sin(pi/4) = sqrt(2)/2 + i * sqrt(2)/2
      final sqrtI = i.pow(const RationalNumber(1, 2));
      final valSqrtI = sqrtI.evaluateComplex();
      final expectedSqrt2Over2 = math.sqrt(2) / 2;
      check((valSqrtI.a - expectedSqrt2Over2).abs()).isLessThan(1e-12);
      check((valSqrtI.b - expectedSqrt2Over2).abs()).isLessThan(1e-12);

      // (-1)^(1/2) = i
      final sqrtNegOne = RationalNumber.negativeOne.pow(
        const RationalNumber(1, 2),
      );
      final valSqrtNegOne = sqrtNegOne.evaluateComplex();
      check((valSqrtNegOne - Complex.i).abs()).isLessThan(1e-12);

      // (-8)^(1/3)
      final cubeRootNegEight = const RationalNumber(-8)
          .pow(const RationalNumber(1, 3));
      final valCube = cubeRootNegEight.evaluateComplex();
      // (-8)^(1/3) in principal branch: 2 * e^(i * pi / 3) = 1 + i * sqrt(3)
      check((valCube.a - 1.0).abs()).isLessThan(1e-12);
      check((valCube.b - math.sqrt(3)).abs()).isLessThan(1e-12);
    });
  });

  group('Dimension 2: Complex Arithmetic & Simplification Invariants', () {
    test('additive identity and inverse', () {
      check((i + RationalNumber.zero).simplify()).equals(i);
      check((RationalNumber.zero + i).simplify()).equals(i);
      check((i - RationalNumber.zero).simplify()).equals(i);
      check((RationalNumber.zero - i).simplify()).equals(-i);

      check((i - i).simplify()).equals(RationalNumber.zero);
      check((i + (-i)).simplify()).equals(RationalNumber.zero);
      check(((-i) + i).simplify()).equals(RationalNumber.zero);
      check(((-i) - (-i)).simplify()).equals(RationalNumber.zero);
    });

    test('multiplication identities and annihilator', () {
      check((i * RationalNumber.zero).simplify()).equals(RationalNumber.zero);
      check((RationalNumber.zero * i).simplify()).equals(RationalNumber.zero);
      check((i * RationalNumber.one).simplify()).equals(i);
      check((RationalNumber.one * i).simplify()).equals(i);
      check((i * RationalNumber.negativeOne).simplify()).equals(-i);
      check((RationalNumber.negativeOne * i).simplify()).equals(-i);

      check((i * i).simplify()).equals(RationalNumber.negativeOne);
      check(((-i) * i).simplify()).equals(RationalNumber.one);
      check((i * (-i)).simplify()).equals(RationalNumber.one);
      check(((-i) * (-i)).simplify()).equals(RationalNumber.negativeOne);
    });

    test('division by i and -i identities', () {
      check((RationalNumber.one / i).simplify()).equals(-i);
      check((RationalNumber.negativeOne / i).simplify()).equals(i);
      check((RationalNumber.one / (-i)).simplify()).equals(i);
      check((RationalNumber.negativeOne / (-i)).simplify()).equals(-i);

      check((i / i).simplify()).equals(RationalNumber.one);
      check(((-i) / i).simplify()).equals(RationalNumber.negativeOne);
      check((i / (-i)).simplify()).equals(RationalNumber.negativeOne);
      check(((-i) / (-i)).simplify()).equals(RationalNumber.one);

      check((x / i).simplify()).equals(-(i * x));
      check((x / (-i)).simplify()).equals(i * x);
    });

    test('Gaussian integer product expansion (a + bi)(c + di)', () {
      final z1 = const RationalNumber(2) + const RationalNumber(3) * i;
      final z2 = const RationalNumber(4) + const RationalNumber(5) * i;
      // (2 + 3i)(4 + 5i) = (8 - 15) + (10 + 12)i = -7 + 22i
      final prod = (z1 * z2).expand().simplify();
      check(prod)
          .equals(const RationalNumber(-7) + const RationalNumber(22) * i);
    });

    test('complex conjugate product gives sum of squares: (a + bi)(a - bi) = a^2 + b^2', () {
      final z1 = const RationalNumber(3) + const RationalNumber(4) * i;
      final z2 = const RationalNumber(3) - const RationalNumber(4) * i;
      // (3 + 4i)(3 - 4i) = 9 + 16 = 25
      final prod = (z1 * z2).expand().simplify();
      check(prod).equals(const RationalNumber(25));
    });

    test('symbolic conjugate product: (x + i*y)(x - i*y)', () {
      final z1 = x + i * y;
      final z2 = x - i * y;
      final prod = (z1 * z2).expand().simplify();
      // x^2 + y^2
      check(prod).equals(x.pow(2) + y.pow(2));
    });

    test('associativity of Gaussian addition', () {
      final z1 = const RationalNumber(1) + const RationalNumber(2) * i;
      final z2 = const RationalNumber(3) + const RationalNumber(4) * i;
      final z3 = const RationalNumber(5) + const RationalNumber(6) * i;

      final sum1 = ((z1 + z2) + z3).simplify();
      final sum2 = (z1 + (z2 + z3)).simplify();
      check(sum1).equals(sum2);
      check(sum1)
          .equals(const RationalNumber(9) + const RationalNumber(12) * i);
    });

    test('complex arithmetic simplification', () {
      final c1 = const RationalNumber(1) + const RationalNumber(2) * i;
      final c2 = const RationalNumber(3) + const RationalNumber(4) * i;

      // c1 + c2 folds into 4 + 6 * i
      check((c1 + c2).simplify())
          .equals(const RationalNumber(4) + const RationalNumber(6) * i);

      // c1 * c2 folds into -5 + 10 * i
      check((c1 * c2).expand().simplify())
          .equals(const RationalNumber(-5) + const RationalNumber(10) * i);

      // purely real complex sum folds with RationalNumber
      check(
        ((const RationalNumber(1) + const RationalNumber(0) * i) +
                const RationalNumber(2))
            .simplify(),
      ).equals(const RationalNumber(3));

      // c1 * 3 folds into 3 + 6 * i
      check((c1 * const RationalNumber(3)).expand().simplify())
          .equals(const RationalNumber(3) + const RationalNumber(6) * i);
    });

    test('distributivity of multiplication over addition with i', () {
      final expr = i * (x + y);
      final expanded = expr.expand();
      check(expanded.simplify()).equals(i * x + i * y);
    });
  });

  group('Dimension 3: Differential Oracle (evaluateComplex vs compileComplex vs toComplexFunction1D)', () {
    final testPoints = <Complex>[
      Complex.zero,
      Complex.one,
      -Complex.one,
      Complex.i,
      -Complex.i,
      const Complex(1.0, 1.0),
      const Complex(1.0, -1.0),
      const Complex(-1.0, 1.0),
      const Complex(-1.0, -1.0),
      const Complex(0.5, 2.5),
      const Complex(3.0, -4.0),
      const Complex(-0.125, 0.75),
    ];

    void verifyOracleParity1D(Expr expr, {double tol = 1e-11}) {
      final compiled1D = expr.toComplexFunction1D('x');
      final compiledMap = expr.compileComplex();

      for (final pt in testPoints) {
        final evalRes = expr.evaluateComplex({'x': pt});
        final fast1DRes = compiled1D(pt);
        final mapRes = compiledMap({'x': pt});

        if (evalRes.isNaN || fast1DRes.isNaN || mapRes.isNaN) {
          continue;
        }
        if (evalRes.isInfinite || fast1DRes.isInfinite || mapRes.isInfinite) {
          continue;
        }

        final diff1 = (evalRes - fast1DRes).abs();
        final diff2 = (evalRes - mapRes).abs();

        check(diff1).isLessThan(tol);
        check(diff2).isLessThan(tol);
      }
    }

    test('polynomial expressions', () {
      verifyOracleParity1D(
        x * x * x -
            const RationalNumber(2) * x.pow(2) +
            const RationalNumber(4) * x -
            const RationalNumber(7),
      );
      verifyOracleParity1D(x.pow(4) + const RationalNumber(1));
      verifyOracleParity1D((x + i) * (x - i));
      verifyOracleParity1D(x.pow(2) + i * x + const RationalNumber(1));
    });

    test('rational expressions', () {
      verifyOracleParity1D(
        (x + const RationalNumber(1)) / (x - const RationalNumber(2)),
      );
      verifyOracleParity1D(
        (x * x + RationalNumber.one) / (x * x + const RationalNumber(4)),
      );
      verifyOracleParity1D((x + i) / (x - i));
    });

    test('exponential and logarithmic expressions', () {
      verifyOracleParity1D(Exp(i * x));
      verifyOracleParity1D(Exp(-x * x));
      verifyOracleParity1D(Ln(x * x + const RationalNumber(1)));
    });

    test('trigonometric and hyperbolic expressions', () {
      verifyOracleParity1D(const Sin(x) + const Cos(x));
      verifyOracleParity1D(const Sinh(x) + const Cosh(x));
      verifyOracleParity1D(const Tan(x));
      verifyOracleParity1D(const Tanh(x));
      verifyOracleParity1D(Sin(i * x));
      verifyOracleParity1D(Cos(i * x));
    });

    test('inverse trigonometric expressions', () {
      verifyOracleParity1D(const Atan(x));
      verifyOracleParity1D(Asin(x * const RationalNumber(1, 2)));
      verifyOracleParity1D(Acos(x * const RationalNumber(1, 2)));
    });

    test('absolute value and power expressions', () {
      verifyOracleParity1D(const Abs(x));
      verifyOracleParity1D(Abs(x + i));
      verifyOracleParity1D(x.pow(const RationalNumber(3, 2)));
    });

    test('zero base complex power evaluates correctly', () {
      final x2 = x.pow(2);
      final valZero = x2.evaluateComplex({'x': Complex.zero});
      check(valZero).equals(Complex.zero);

      final f = (x * x + 1).toComplexFunction1D('x');
      final valCompZero = f(Complex.zero);
      check(valCompZero).equals(Complex.one);
    });

    test(
      'multi-variable oracle parity with compileComplex on non-zero domain',
      () {
        final expr = x * x + y * y + z * i;
        final compiled = expr.compileComplex();

        final nonZeroPoints = testPoints
            .where((p) => p != Complex.zero)
            .take(4);
        for (final px in nonZeroPoints) {
          for (final py in nonZeroPoints) {
            final ctx = {'x': px, 'y': py, 'z': Complex.i};
            final directVal = expr.evaluateComplex(ctx);
            final compiledVal = compiled(ctx);
            check((directVal - compiledVal).abs()).isLessThan(1e-12);
          }
        }
      },
    );
  });

  group('Dimension 4: String, LaTeX, MathML Formatting & Serialization Round-Tripping', () {
    test('formatExpr string representation precedence and parenthesis', () {
      check(formatExpr(i)).equals('i');
      check(formatExpr(-i)).equals('-i');
      check(formatExpr(const RationalNumber(3) * i)).equals('3 * i');
      check(formatExpr(const RationalNumber(-3) * i)).equals('-3 * i');
      check(formatExpr(const RationalNumber(2) + const RationalNumber(3) * i))
          .equals('2 + 3 * i');
      check(formatExpr(const RationalNumber(2) - const RationalNumber(3) * i))
          .equals('2 - 3 * i');

      final c = const RationalNumber(2) + const RationalNumber(3) * i;
      check(formatExpr(c * x)).equals('(2 + 3 * i) * x');
      check(formatExpr(x / c)).equals('x / (2 + 3 * i)');
      check(formatExpr(c.pow(2))).equals('(2 + 3 * i) ^ 2');
    });

    test('LaTeX serialization formatting', () {
      check(i.toLatex()).equals('i');
      check((-i).toLatex()).equals('-i');
      check((const RationalNumber(5) * i).toLatex()).equals(r'5 \cdot i');
      check((const RationalNumber(2) + const RationalNumber(3) * i).toLatex())
          .equals(r'2 + 3 \cdot i');
      check((const RationalNumber(2) - const RationalNumber(3) * i).toLatex())
          .equals(r'2 - 3 \cdot i');

      final c = const RationalNumber(3) - const RationalNumber(4) * i;
      check(c.toLatex()).equals(r'3 - 4 \cdot i');
      check((c * x).toLatex()).equals(r'(3 - 4 \cdot i) \cdot x');
      check((x - c).toLatex()).equals(r'x - (3 - 4 \cdot i)');
    });

    test('MathML serialization structure', () {
      check(i.toMathMl()).equals('<math><mi>i</mi></math>');
      check((-i).toMathMl())
          .equals('<math><mrow><mo>-</mo><mi>i</mi></mrow></math>');

      final cPos = const RationalNumber(2) + const RationalNumber(3) * i;
      check(cPos.toMathMl()).equals(
        '<math><mrow><mn>2</mn><mo>+</mo><mrow><mn>3</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow></math>',
      );

      final cNeg = const RationalNumber(2) - const RationalNumber(3) * i;
      check(cNeg.toMathMl()).equals(
        '<math><mrow><mn>2</mn><mo>-</mo><mrow><mn>3</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow></math>',
      );

      const cUnitI = i;
      check(cUnitI.toMathMl()).equals('<math><mi>i</mi></math>');

      final cNegUnitI = -i;
      check(cNegUnitI.toMathMl())
          .equals('<math><mrow><mo>-</mo><mi>i</mi></mrow></math>');
    });

    test('parentheses in LaTeX and MathML for pure imaginary powers and negative signs', () {
      final c2I = const RationalNumber(2) * i;
      final cNegI = -i;

      // Pure imaginary powers receive parentheses: (2i)^2 -> (2 i)^2, (-i)^2 -> (-i)^2
      check(c2I.pow(2).toLatex()).equals(r'{(2 \cdot i)}^{2}');
      check(c2I.pow(2).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mn>2</mn><mo>&#x22c5;</mo><mi>i</mi></mrow><mo>)</mo></mrow><mn>2</mn></msup></math>',
      );

      check(cNegI.pow(2).toLatex()).equals(r'{(-i)}^{2}');
      check(cNegI.pow(2).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow><mn>2</mn></msup></math>',
      );

      // Negative imaginary factor in multiplication receives parentheses
      check((x * cNegI).toLatex()).equals(r'x \cdot (-i)');
      check((x * cNegI).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>&#x22c5;</mo><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );

      // Subtraction of negative imaginary receives parentheses
      check((x - cNegI).toLatex()).equals(r'x - (-i)');
      check((x - cNegI).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>-</mo><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );

      // Double negation receives parentheses
      check((-cNegI).toLatex()).equals(r'-(-i)');
      check((-cNegI).toMathMl()).equals(
        '<math><mrow><mo>-</mo><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
    });

    test('round-trip serialization through Expr.parse', () {
      final exprs = <Expr>[
        i,
        -i,
        const RationalNumber(2) * i,
        const RationalNumber(2) + const RationalNumber(3) * i,
        const RationalNumber(2) - const RationalNumber(3) * i,
        (x + i) * (x - i),
        Exp(i * ConstantNumber.pi),
      ];

      for (final expr in exprs) {
        final formatted = formatExpr(expr);
        final parsed = Expr.parse(formatted);

        final valOrig = expr.evaluateComplex({'x': const Complex(1.5, 2.5)});
        final valParsed = parsed.evaluateComplex({
          'x': const Complex(1.5, 2.5),
        });

        check((valOrig - valParsed).abs()).isLessThan(1e-12);
      }
    });
  });

  group('Dimension 5: Calculus & Derivatives with Complex Constants', () {
    test('derivative of complex linear and polynomial expressions', () {
      check((x * i).derivative('x').simplify()).equals(i);
      check((x.pow(2) * i).derivative('x').simplify())
          .equals(Mul(const RationalNumber(2), i * x));
      check((x + i).derivative('x').simplify()).equals(RationalNumber.one);
      check(
        (x + const RationalNumber(3) + const RationalNumber(4) * i)
            .derivative('x')
            .simplify(),
      ).equals(RationalNumber.one);
    });

    test('derivative of complex exponential', () {
      // d/dx [ exp(i * x) ] = i * exp(i * x)
      final deriv = Exp(i * x).derivative('x').simplify();
      check(deriv).equals(i * Exp(i * x));
    });

    test('anti-derivative of complex expressions w.r.t real variable', () {
      // \int i dx = i * x
      check(i.integrate('x').simplify()).equals(i * x);

      // \int (x * i) dx = (1/2) * (x^2 * i) or i * (x^2 / 2)
      final anti = (x * i).integrate('x').simplify();
      check(anti.derivative('x').simplify()).equals(i * x);
    });
  });

  group('Dimension 6: Error Handling & Boundary Robustness', () {
    test('Number.value throws on imaginary constant', () {
      check(() => i.value).throws<UnsupportedError>();
    });

    test(
      'real evaluators throw UnsupportedError on expressions containing i',
      () {
        final exprI = x + i;
        check(() => exprI.evaluate({'x': 1.0})).throws<UnsupportedError>();
        check(() => exprI.toFunction1D('x')).throws<UnsupportedError>();
        check(() => exprI.compile(['x'])).throws<UnsupportedError>();
        check(() => exprI.toVectorFunction(['x'])).throws<UnsupportedError>();
        check(() => exprI.compileTensorKernel(['x']))
            .throws<UnsupportedError>();

        final exprC = x + const RationalNumber(1) + i;
        check(() => exprC.evaluate({'x': 1.0})).throws<UnsupportedError>();
        check(() => exprC.toFunction1D('x')).throws<UnsupportedError>();
        check(() => exprC.compile(['x'])).throws<UnsupportedError>();
        check(() => exprC.toVectorFunction(['x'])).throws<UnsupportedError>();
        check(() => exprC.compileTensorKernel(['x']))
            .throws<UnsupportedError>();
      },
    );

    test('missing variable in evaluateComplex and compileComplex throws ArgumentError', () {
      check(() => x.evaluateComplex()).throws<ArgumentError>();
      check(() => (x + y).evaluateComplex({'x': Complex.one}))
          .throws<ArgumentError>();

      final compiled = (x + y).compileComplex();
      check(() => compiled({'x': Complex.one})).throws<ArgumentError>();
      check(() => compiled({})).throws<ArgumentError>();
    });

    test('structural comparison total order of complex expressions and ConstantNumber.i', () {
      final c1 = const RationalNumber(1) + const RationalNumber(2) * i;
      final c2 = const RationalNumber(1) + const RationalNumber(3) * i;
      final c3 = const RationalNumber(2) + i;

      // Reflexivity
      check(compareStructural(c1, c1)).equals(0);
      check(compareStructural(i, i)).equals(0);

      // Antisymmetry
      check(compareStructural(c1, c2) < 0).isTrue();
      check(compareStructural(c2, c1) > 0).isTrue();

      // Transitivity
      check(compareStructural(c1, c2) < 0).isTrue();
      check(compareStructural(c2, c3) < 0).isTrue();
      check(compareStructural(c1, c3) < 0).isTrue();

      // Comparison between i and other constants
      check(compareStructural(i, ConstantNumber.pi) != 0).isTrue();
      check(compareStructural(ConstantNumber.pi, i) != 0).isTrue();
      check(compareStructural(i, ConstantNumber.e) != 0).isTrue();
      check(compareStructural(ConstantNumber.e, i) != 0).isTrue();
    });
  });

  group('Dimension 7: Remediation Verification & Edge-Case Stress Harness', () {
    test('Zero base power evaluation and evaluator parity across domains', () {
      // 1. x^k at x = 0 for various integer exponents
      for (var k = 1; k <= 6; k++) {
        final expr = x.pow(k);
        final valDirect = expr.evaluateComplex({'x': Complex.zero});
        final valCompiled1D = expr.toComplexFunction1D('x')(Complex.zero);
        final valCompiled = expr.compileComplex()({'x': Complex.zero});

        check(valDirect).equals(Complex.zero);
        check(valCompiled1D).equals(Complex.zero);
        check(valCompiled).equals(Complex.zero);
      }

      // 2. x^0 at x = 0
      final x0 = x.pow(0);
      check(x0.evaluateComplex({'x': Complex.zero})).equals(Complex.one);
      check(x0.toComplexFunction1D('x')(Complex.zero)).equals(Complex.one);
      check(x0.compileComplex()({'x': Complex.zero})).equals(Complex.one);

      // 3. 0^x for x = 0, 1, 2, 0.5, 1+i
      final zeroPowX = const RationalNumber(0).pow(x);
      check(zeroPowX.evaluateComplex({'x': Complex.zero})).equals(Complex.one);
      check(zeroPowX.evaluateComplex({'x': Complex.one})).equals(Complex.zero);
      check(zeroPowX.evaluateComplex({'x': const Complex(2, 0)}))
          .equals(Complex.zero);
      check(zeroPowX.evaluateComplex({'x': const Complex(0.5, 0)}))
          .equals(Complex.zero);
      check(zeroPowX.evaluateComplex({'x': const Complex(1, 2)}))
          .equals(Complex.zero);

      // 4. 0^w for negative and pure imaginary exponents
      check(zeroPowX.evaluateComplex({'x': const Complex(-1, 0)}))
          .equals(const Complex(double.infinity, 0.0));
      check(zeroPowX.evaluateComplex({'x': Complex.i}).isNaN).isTrue();
      check(zeroPowX.evaluateComplex({'x': -Complex.i}).isNaN).isTrue();

      // 5. Parity between evaluators for runtime zero bases
      final poly1 =
          x * x + const RationalNumber(2) * x + const RationalNumber(1);
      final fPoly1 = poly1.toComplexFunction1D('x');
      final cPoly1 = poly1.compileComplex();
      check(poly1.evaluateComplex({'x': Complex.zero})).equals(Complex.one);
      check(fPoly1(Complex.zero)).equals(Complex.one);
      check(cPoly1({'x': Complex.zero})).equals(Complex.one);

      final shiftedSquare = (x - const RationalNumber(1)).pow(2);
      final fShifted = shiftedSquare.toComplexFunction1D('x');
      check(shiftedSquare.evaluateComplex({'x': Complex.one}))
          .equals(Complex.zero);
      check(fShifted(Complex.one)).equals(Complex.zero);

      final scaledImagSquare = (x * i).pow(2);
      final fScaledImag = scaledImagSquare.toComplexFunction1D('x');
      check(scaledImagSquare.evaluateComplex({'x': Complex.zero}))
          .equals(Complex.zero);
      check(fScaledImag(Complex.zero)).equals(Complex.zero);

      // 6. Multi-variable polynomial at origin (0, 0, 0)
      final multiPoly = x * x + y * y + z * i;
      final fMulti = multiPoly.compileComplex();
      final ctxOrigin = {'x': Complex.zero, 'y': Complex.zero, 'z': Complex.i};
      check(multiPoly.evaluateComplex(ctxOrigin)).equals(const Complex(-1, 0));
      check(fMulti(ctxOrigin)).equals(const Complex(-1, 0));
    });

    test('Complex expression arithmetic and canonical normal form folding', () {
      final c1 = const RationalNumber(1) + const RationalNumber(2) * i;
      final c2 = const RationalNumber(3) + const RationalNumber(4) * i;

      // Addition & Subtraction
      check((c1 + c2).simplify())
          .equals(const RationalNumber(4) + const RationalNumber(6) * i);
      check((c1 - c2).simplify())
          .equals(const RationalNumber(-2) - const RationalNumber(2) * i);
      check((c1 - c1).simplify()).equals(RationalNumber.zero);
      check(
        (c1 + (const RationalNumber(-1) - const RationalNumber(2) * i))
            .simplify(),
      ).equals(RationalNumber.zero);

      // Cancellation of imaginary part leaves RationalNumber
      check((c1 - (const RationalNumber(2) * i)).simplify())
          .equals(RationalNumber.one);

      // Cancellation of real part leaves imaginary term
      check((c1 - const RationalNumber(1)).simplify())
          .equals(const RationalNumber(2) * i);

      // Mixing with Rationals and Reals
      check((c1 + const RationalNumber(5)).simplify())
          .equals(const RationalNumber(6) + const RationalNumber(2) * i);
      check((const RationalNumber(5) + c1).simplify())
          .equals(const RationalNumber(6) + const RationalNumber(2) * i);
      check((c1 + const RealNumber(0.5)).simplify())
          .equals(const RealNumber(1.5) + const RationalNumber(2) * i);
      check((c1 + i).simplify())
          .equals(const RationalNumber(1) + const RationalNumber(3) * i);

      // Multiplication
      check((c1 * c2).expand().simplify())
          .equals(const RationalNumber(-5) + const RationalNumber(10) * i);

      // Complex conjugate product gives pure rational sum of squares
      final cConj = const RationalNumber(3) - const RationalNumber(4) * i;
      check((c2 * cConj).expand().simplify()).equals(const RationalNumber(25));

      // Multiplication by scalar and imaginary unit
      check((c1 * const RationalNumber(3)).expand().simplify())
          .equals(const RationalNumber(3) + const RationalNumber(6) * i);
      check((const RationalNumber(3) * c1).expand().simplify())
          .equals(const RationalNumber(3) + const RationalNumber(6) * i);
      check((c1 * i).expand().simplify()).equals(const RationalNumber(-2) + i);
      check((c1 * (-i)).expand().simplify())
          .equals(const RationalNumber(2) - i);

      // Annihilation and identity
      check((c1 * RationalNumber.zero).simplify()).equals(RationalNumber.zero);
      check((RationalNumber.zero * c1).simplify()).equals(RationalNumber.zero);
      check((c1 * RationalNumber.one).simplify()).equals(c1);
      check((RationalNumber.one * c1).simplify()).equals(c1);
      check((c1 * const RationalNumber(-2)).expand().simplify())
          .equals(const RationalNumber(-2) - const RationalNumber(4) * i);

      // Division
      final cNum = RationalNumber.one + i;
      final cDen = RationalNumber.one - i;
      check((cNum / cDen).evaluateComplex()).equals(Complex.i);

      // Complex multiplication gives exact Gaussian integers
      check((cNum * cNum).expand().simplify())
          .equals(const RationalNumber(2) * i);
      check((cNum.pow(2).evaluateComplex() - const Complex(0, 2)).abs())
          .isLessThan(1e-15);
      check(c1.pow(0).simplify()).equals(RationalNumber.one);
      check(c1.pow(1).simplify()).equals(c1);

      // Polynomial expansion with complex coefficients
      final p1 = x + (RationalNumber.one + const RationalNumber(2) * i);
      final p2 = x + (RationalNumber.one - const RationalNumber(2) * i);
      final expandedProduct = (p1 * p2).expand().simplify();
      check(expandedProduct).equals(
        x.pow(2) + const RationalNumber(2) * x + const RationalNumber(5),
      );
    });

    test('LaTeX and MathML parenthesization on pure imaginary powers and negative factors', () {
      final c2I = const RationalNumber(2) * i;
      final cNeg2I = -(const RationalNumber(2) * i);
      final cNegI = -i;
      final cBinomNeg = const RationalNumber(-1) - const RationalNumber(2) * i;

      // 1. Powers of pure imaginary receive parentheses in LaTeX
      check(c2I.pow(2).toLatex()).equals(r'{(2 \cdot i)}^{2}');
      check(cNeg2I.pow(2).toLatex()).equals(r'{(-2 \cdot i)}^{2}');
      check(cNegI.pow(2).toLatex()).equals(r'{(-i)}^{2}');
      check(i.pow(2).toLatex())
          .equals(r'{i}^{2}'); // Unit i does not have redundant parens
      check(c2I.pow(-1).toLatex()).equals(r'{(2 \cdot i)}^{-1}');

      // Powers in MathML
      check(c2I.pow(2).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mn>2</mn><mo>&#x22c5;</mo><mi>i</mi></mrow><mo>)</mo></mrow><mn>2</mn></msup></math>',
      );
      check(cNegI.pow(2).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow><mn>2</mn></msup></math>',
      );

      // 2. Negative factors in multiplication receive parentheses in LaTeX
      check((x * cNegI).toLatex()).equals(r'x \cdot (-i)');
      check((cNegI * x).toLatex()).equals(r'(-i) \cdot x');
      check((x * cNeg2I).toLatex()).equals(r'x \cdot (-2 \cdot i)');
      check((cNeg2I * x).toLatex()).equals(r'(-2 \cdot i) \cdot x');
      check((x * cBinomNeg).toLatex()).equals(r'x \cdot (-1 - 2 \cdot i)');
      check((cBinomNeg * x).toLatex()).equals(r'(-1 - 2 \cdot i) \cdot x');

      // Multiplication in MathML
      check((x * cNegI).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>&#x22c5;</mo><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check((cNegI * x).toMathMl()).equals(
        '<math><mrow><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow><mo>&#x22c5;</mo><mi>x</mi></mrow></math>',
      );

      // 3. Subtraction of negative terms receives parentheses
      check((x - cNegI).toLatex()).equals(r'x - (-i)');
      check((x - cNeg2I).toLatex()).equals(r'x - (-2 \cdot i)');
      check((x - cBinomNeg).toLatex()).equals(r'x - (-1 - 2 \cdot i)');

      // Subtraction in MathML
      check((x - cNegI).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>-</mo><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check((x - cNeg2I).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>-</mo><mrow><mo>(</mo><mrow><mo>-</mo><mrow><mn>2</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow><mo>)</mo></mrow></mrow></math>',
      );

      // 4. Double negation receives parentheses
      check((-cNegI).toLatex()).equals(r'-(-i)');
      check((-cNeg2I).toLatex()).equals(r'-(-2 \cdot i)');
      check((-cBinomNeg).toLatex()).equals(r'-(-1 - 2 \cdot i)');

      // Double negation in MathML
      check((-cNegI).toMathMl()).equals(
        '<math><mrow><mo>-</mo><mrow><mo>(</mo><mrow><mo>-</mo><mi>i</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check((-cNeg2I).toMathMl()).equals(
        '<math><mrow><mo>-</mo><mrow><mo>(</mo><mrow><mo>-</mo><mrow><mn>2</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow><mo>)</mo></mrow></mrow></math>',
      );
    });
  });
}
