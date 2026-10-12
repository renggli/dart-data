import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/data.dart';
import 'package:data/numeric.dart' as num_tools;
import 'package:test/test.dart';

void main() {
  group('M1: Sqrt AST Elimination & MathML Radical Rendering', () {
    test('sqrt and pow parse canonically to Pow AST node', () {
      final sqrtExpr = Expr.parse('sqrt(x)');
      check(sqrtExpr).isA<Pow>();
      final powNode = sqrtExpr as Pow;
      check(powNode.base).equals(const Variable('x'));
      check(powNode.exponent).equals(const RationalNumber(1, 2));

      final powExpr = Expr.parse('pow(x, 3)');
      check(powExpr).isA<Pow>();
      final powNode2 = powExpr as Pow;
      check(powNode2.base).equals(const Variable('x'));
      check(powNode2.exponent).equals(const RationalNumber(3));

      final nestedSqrt = Expr.parse('sqrt(x^2 + 1)');
      check(nestedSqrt).isA<Pow>();
      check((nestedSqrt as Pow).exponent).equals(const RationalNumber(1, 2));
    });

    test('MathML radical formatting produces valid <mrow> wrapping', () {
      final sqrtExpr = Expr.parse('sqrt(x)');
      final mathmlSqrt = sqrtExpr.toMathMl(root: false);
      check(mathmlSqrt).contains('<msqrt><mrow><mi>x</mi></mrow></msqrt>');

      const rootExpr = Pow(Variable('x'), RationalNumber(1, 3));
      final mathmlRoot = rootExpr.toMathMl(root: false);
      check(mathmlRoot).contains('<mroot>');
      check(mathmlRoot).contains('<mrow><mi>x</mi></mrow>');
      check(mathmlRoot).contains('<mrow><mn>3</mn></mrow>');
    });

    test('Calculus on canonical Pow(x, 1/2)', () {
      final sqrtExpr = Expr.parse('sqrt(x)');
      final deriv = sqrtExpr.derivative('x').simplify();
      // d/dx(x^(1/2)) = 1/2 * x^(-1/2) = 1 / (2 * sqrt(x))
      check(deriv.evaluate({'x': 4.0})).isCloseTo(0.25, 1e-6);

      final integral = sqrtExpr.integrate('x', from: 0, to: 4);
      // \int_0^4 x^(1/2) dx = [2/3 * x^(3/2)]_0^4 = 2/3 * 8 = 16/3
      check(integral.evaluate({})).isCloseTo(16.0 / 3.0, 1e-5);
    });
  });

  group('M2: Algebra Modularization (expand, factor, simplify)', () {
    test('Expr.expand distributes products and powers', () {
      const x = Variable('x');
      const y = Variable('y');

      final prod = (x - 2) * (x - 3);
      final expandedProd = prod.expand();
      check(expandedProd.evaluate({'x': 5.0})).equals(6.0); // 3 * 2 = 6
      check(expandedProd.evaluate({'x': 2.0})).equals(0.0);
      check(expandedProd.evaluate({'x': 3.0})).equals(0.0);

      final cube = (x + y).pow(3);
      final expandedCube = cube.expand();
      check(expandedCube.evaluate({'x': 1.0, 'y': 2.0})).equals(27.0);

      final nested = ((x + 1) * (x - 1) * (x + 2)).expand();
      check(nested.evaluate({'x': 0.0})).equals(-2.0);
      check(nested.evaluate({'x': 1.0})).equals(0.0);
      check(nested.evaluate({'x': -1.0})).equals(0.0);
      check(nested.evaluate({'x': -2.0})).equals(0.0);
    });

    test('Expr.factor factors polynomials over Q[x]', () {
      const x = Variable('x');

      // x^2 - 5x + 6 -> (x - 2)(x - 3)
      final poly1 =
          x * x - const RationalNumber(5) * x + const RationalNumber(6);
      final factored1 = poly1.factor();
      check(factored1.evaluate({'x': 2.0})).equals(0.0);
      check(factored1.evaluate({'x': 3.0})).equals(0.0);

      // x^2 - 9 -> (x - 3)(x + 3)
      final poly2 = x * x - const RationalNumber(9);
      final factored2 = poly2.factor();
      check(factored2.evaluate({'x': 3.0})).equals(0.0);
      check(factored2.evaluate({'x': -3.0})).equals(0.0);

      // x^3 - 6x^2 + 11x - 6 -> (x - 1)(x - 2)(x - 3)
      final poly3 =
          x.pow(3) -
          const RationalNumber(6) * x.pow(2) +
          const RationalNumber(11) * x -
          const RationalNumber(6);
      final factored3 = poly3.factor();
      check(factored3.evaluate({'x': 1.0})).equals(0.0);
      check(factored3.evaluate({'x': 2.0})).equals(0.0);
      check(factored3.evaluate({'x': 3.0})).equals(0.0);
    });

    test('Expr.simplify confluent identity reductions', () {
      const x = Variable('x');

      // Pythagorean: sin^2(x) + cos^2(x) -> 1
      final pyth = const Sin(x) * const Sin(x) + const Cos(x) * const Cos(x);
      check(pyth.simplify()).equals(const RationalNumber(1));

      // Parity: sin(-x) -> -sin(x), cos(-x) -> cos(x)
      check(Sin(-x).simplify()).equals(-const Sin(x));
      check(Cos(-x).simplify()).equals(const Cos(x));

      // Logarithmic and exponential inverse identities
      check(const Ln(Exp(x)).simplify()).equals(x);
      check(const Exp(Ln(x)).simplify()).equals(x);
      check(const Ln(RationalNumber(1)).simplify())
          .equals(const RationalNumber(0));
      check(const Ln(ConstantNumber.e).simplify())
          .equals(const RationalNumber(1));

      // Idempotency: simplify(simplify(e)) == simplify(e)
      final complexExpr =
          (x + 0) * 1 +
          (x * 0) +
          const Sin(x) * const Sin(x) +
          const Cos(x) * const Cos(x);
      final s1 = complexExpr.simplify();
      final s2 = s1.simplify();
      check(s1).equals(s2);
    });
  });

  group('M3: Complex Numbers & Imaginary Constant i', () {
    test('Imaginary unit powers and simplification', () {
      // i^2 -> -1
      check((i * i).simplify()).equals(const RationalNumber(-1));
      check(i.pow(2).simplify()).equals(const RationalNumber(-1));

      // i^3 -> -i
      check(i.pow(3).simplify()).equals(-i);

      // i^4 -> 1
      check(i.pow(4).simplify()).equals(const RationalNumber(1));

      // i^5 -> i
      check(i.pow(5).simplify()).equals(i);

      // i^6 -> -1
      check(i.pow(6).simplify()).equals(const RationalNumber(-1));

      // i^7 -> -i
      check(i.pow(7).simplify()).equals(-i);

      // i^8 -> 1
      check(i.pow(8).simplify()).equals(const RationalNumber(1));

      // Multiplicative scaling: (2 * i) * (3 * i) -> -6
      final prod =
          (const RationalNumber(2) * i) * (const RationalNumber(3) * i);
      check(prod.simplify()).equals(const RationalNumber(-6));
    });

    test('Complex evaluation and JIT compilation', () {
      const x = Variable('x');
      final expr = x * x + 1;

      // evaluateComplex at x = i
      final res = expr.evaluateComplex({'x': const Complex(0, 1)});
      check(res.a).isCloseTo(0.0, 1e-12);
      check(res.b).isCloseTo(0.0, 1e-12);

      // JIT toComplexFunction1D
      final fComplex = expr.toComplexFunction1D('x');
      final val1 = fComplex(const Complex(0, 1));
      check(val1.a).isCloseTo(0.0, 1e-12);
      check(val1.b).isCloseTo(0.0, 1e-12);

      final val2 = fComplex(
        const Complex(1, 1),
      ); // (1 + i)^2 + 1 = 1 + 2i - 1 + 1 = 1 + 2i
      check(val2.a).isCloseTo(1.0, 1e-12);
      check(val2.b).isCloseTo(2.0, 1e-12);

      // compileComplex
      const y = Variable('y');
      final multiF = (x + y).compileComplex();
      final multiVal = multiF({
        'x': const Complex(1, 2),
        'y': const Complex(3, 4),
      });
      check(multiVal.a).equals(4.0);
      check(multiVal.b).equals(6.0);
    });

    test('Complex textualization', () {
      final z = ComplexNumber.fromCartesian(3, 4);
      check(z.toString()).equals('3 + 4 * i');
      check(z.toLatex()).equals('3 + 4 i');
      check(z.toMathMl(root: false)).contains(
        '<mn>3</mn><mo>+</mo><mrow><mn>4</mn><mo>&#x22c5;</mo><mi>i</mi></mrow>',
      );
    });
  });

  group('M4: Analytical Equation Solver', () {
    test(
      'Quadratic equations with negative discriminant yield complex roots',
      () {
        const x = Variable('x');

        // x^2 + 1 = 0 -> roots: i, -i
        final roots1 = (x * x + 1).solve('x');
        check(roots1.length).equals(2);
        check(roots1).contains(i);
        check(roots1).contains(-i);

        // x^2 + 4 = 0 -> roots: 2i, -2i
        final roots2 = (x * x + 4).solve('x');
        check(roots2.length).equals(2);
        final simplifiedRoots2 = roots2.map((r) => r.simplify()).toList();
        check(simplifiedRoots2).contains(const RationalNumber(2) * i);
        check(simplifiedRoots2).contains(const RationalNumber(-2) * i);

        // x^2 - 2x + 5 = 0 -> discriminant = 4 - 20 = -16 -> roots: 1 + 2i, 1 - 2i
        final roots3 = (x * x - const RationalNumber(2) * x + 5).solve('x');
        check(roots3.length).equals(2);
        for (final r in roots3) {
          final val = (x * x - const RationalNumber(2) * x + 5).evaluateComplex(
            {'x': r.evaluateComplex()},
          );
          check(val.a).isCloseTo(0.0, 1e-10);
          check(val.b).isCloseTo(0.0, 1e-10);
        }
      },
    );

    test('Trigonometric equation solving', () {
      const x = Variable('x');

      // sin(x) = 0 -> root 0
      final sinRoots = const Sin(x).solve('x');
      check(sinRoots).isNotEmpty();
      check(sinRoots).contains(const RationalNumber(0));

      // cos(x) = 0 -> root pi/2
      final cosRoots = const Cos(x).solve('x');
      check(cosRoots).isNotEmpty();
      check(cosRoots.map((r) => r.evaluate({}))).contains(math.pi / 2.0);

      // tan(x) = 0 -> root 0
      final tanRoots = const Tan(x).solve('x');
      check(tanRoots).isNotEmpty();
      check(tanRoots).contains(const RationalNumber(0));
    });

    test('Higher-degree polynomial solving', () {
      const x = Variable('x');

      // Cubic: x^3 - 6x^2 + 11x - 6 = 0 -> roots 1, 2, 3
      final cubic =
          x.pow(3) -
          const RationalNumber(6) * x.pow(2) +
          const RationalNumber(11) * x -
          const RationalNumber(6);
      final cubicRoots = cubic.solve('x');
      check(cubicRoots.length).equals(3);
      check(cubicRoots).contains(const RationalNumber(1));
      check(cubicRoots).contains(const RationalNumber(2));
      check(cubicRoots).contains(const RationalNumber(3));

      // Quartic biquadratic: x^4 - 5x^2 + 4 = 0 -> roots 1, -1, 2, -2
      final quartic = x.pow(4) - const RationalNumber(5) * x.pow(2) + 4;
      final quarticRoots = quartic.solve('x');
      check(quarticRoots.length).equals(4);
      check(quarticRoots).contains(const RationalNumber(1));
      check(quarticRoots).contains(const RationalNumber(-1));
      check(quarticRoots).contains(const RationalNumber(2));
      check(quarticRoots).contains(const RationalNumber(-2));

      // Factored cubic: x^3 - x = 0 -> roots 0, 1, -1
      final cubic2 = x.pow(3) - x;
      final rootsCubic2 = cubic2.solve('x');
      check(rootsCubic2.length).equals(3);
      check(rootsCubic2).contains(const RationalNumber(0));
      check(rootsCubic2).contains(const RationalNumber(1));
      check(rootsCubic2).contains(const RationalNumber(-1));
    });
  });

  group('M5: Doc Comment Examples Verification', () {
    test('lib/symbolic.dart library example', () {
      final f = Expr.parse('x^3 + 2 * x');
      final df = f.derivative('x').simplify();
      check(df.toString()).isNotEmpty();
      check(df.toLatex().isNotEmpty).isTrue();
      final fn = df.toFunction1D('x');
      check(fn(2.0)).isCloseTo(14.0, 1e-6);
    });

    test('Expr evaluation, parse, and tryParse', () {
      const x = Variable('x');
      final expr = x * x + x * 2 + 1;
      final val = expr.evaluate({'x': 3.0});
      check(val).equals(16.0);

      final str = formatExpr(x * x + 1);
      check(str).equals('x * x + 1');

      final f = Expr.parse('sin(pi * x) + 2 * x');
      check(f.evaluate({'x': 0.5})).isCloseTo(2.0, 1e-6);

      final expr2 = Expr.tryParse('2 * x + 1');
      check(expr2).isNotNull();
    });

    test('ComplexNumber doc examples', () {
      final z = ComplexNumber.fromCartesian(3, 4);
      check(z.complexValue).equals(const Complex(3, 4));

      const x = Variable('x');
      final expr = x * x + 1;
      final result = expr.evaluateComplex({'x': const Complex(0, 1)});
      check(result.a).isCloseTo(0.0, 1e-12);
      check(result.b).isCloseTo(0.0, 1e-12);

      final f = (x * x + 1).toComplexFunction1D('x');
      final y = f(const Complex(0, 1));
      check(y.a).isCloseTo(0.0, 1e-12);
      check(y.b).isCloseTo(0.0, 1e-12);
    });

    test('Structural order doc example', () {
      const x = Variable('x');
      final cmp = compareStructural(const RationalNumber(1), x);
      check(cmp).isA<int>();
      check(cmp < 0).isTrue();
    });

    test('Linear form and multivariable doc examples', () {
      const x = Variable('x');
      const y = Variable('y');

      final lin = (x * 2 + 5).matchLinear('x');
      check(lin).isNotNull();
      check(lin!.a).equals(const RationalNumber(2));
      check(lin.b).equals(const RationalNumber(5));

      final k = (x * 6).matchScalarMultiple(x * 2, 'x');
      check(k).equals(const RationalNumber(3));

      final scaled = (x + 2).scale(const RationalNumber(3));
      check(scaled.evaluate({'x': 1.0})).equals(9.0);

      final grad = (x * x + y * y).gradient(['x', 'y']);
      check(grad.length).equals(2);

      final h = (x * x + x * y * 3).hessian(['x', 'y']);
      check(h.length).equals(2);
      check(h[0].length).equals(2);

      final jac = [x * y, x + y].jacobian(['x', 'y']);
      check(jac.length).equals(2);
      check(jac[0].length).equals(2);
    });

    test('Vector and tensor compilation doc examples', () {
      const x = Variable('x');
      const y = Variable('y');

      final fVec = (x + y * 2).toVectorFunction(['x', 'y']);
      check(fVec(Vector.fromList([3.0, 4.0]))).equals(11.0);

      final fPos = (x + y * 2).compile(['x', 'y']);
      check(fPos([3.0, 4.0])).equals(11.0);

      final kernel = (x * 2).compileTensorKernel(['x']);
      final input = Float64List.fromList([1.0, 2.0, 3.0]);
      final output = Float64List(3);
      kernel([input], output);
      check(output[0]).equals(2.0);
      check(output[1]).equals(4.0);
      check(output[2]).equals(6.0);
    });
  });

  group('End-to-End Pipeline & Numeric Parity', () {
    test(
      'End-to-End: Parse -> Expand -> Derivative -> Factor -> Solve -> Compile',
      () {
        // 1. Parse factored polynomial
        final parsed = Expr.parse('(x - 1) * (x - 2) * (x - 3)');

        // 2. Expand
        final expanded = parsed.expand();
        check(expanded.evaluate({'x': 4.0})).equals(6.0); // 3 * 2 * 1 = 6

        // 3. Exact derivative of expanded form
        final deriv = expanded.derivative('x').simplify();

        // 4. Parity check: Compare symbolic derivative against numerical differentiation
        final fn = expanded.toFunction1D('x');
        final dfn = deriv.toFunction1D('x');
        for (final testX in [0.0, 1.5, 2.5, 5.0]) {
          final numDeriv = num_tools.derivative(fn, testX);
          final symDeriv = dfn(testX);
          check(symDeriv).isCloseTo(numDeriv, 1e-4);
        }

        // 5. Solve original equation
        final roots = expanded.solve('x');
        check(roots.length).equals(3);
        check(roots).contains(const RationalNumber(1));
        check(roots).contains(const RationalNumber(2));
        check(roots).contains(const RationalNumber(3));

        // 6. Integrate expanded polynomial from 0 to 1
        final integral = expanded.integrate('x', from: 0, to: 1);
        final numInt = num_tools.integrate(fn, 0.0, 1.0);
        check(integral.evaluate({})).isCloseTo(numInt, 1e-5);
      },
    );

    test(
      'End-to-End Complex Pipeline: Quadratic solve -> verify roots in C',
      () {
        // Equation: x^2 + 2x + 5 = 0
        final expr = Expr.parse('x^2 + 2 * x + 5');
        final roots = expr.solve('x');
        check(roots.length).equals(2);

        final complexFn = expr.toComplexFunction1D('x');
        for (final root in roots) {
          final cVal = root.evaluateComplex();
          final evalResult = complexFn(cVal);
          check(evalResult.a).isCloseTo(0.0, 1e-10);
          check(evalResult.b).isCloseTo(0.0, 1e-10);
        }
      },
    );
  });

  group('Empirical Challenger: Deep Parity Stress Battery', () {
    test('Analytical vs Numerical Derivative across transcendental suite', () {
      const x = Variable('x');
      final testCases = <({Expr expr, double point, double tol})>[
        (expr: const Sin(x) * const Cos(x), point: 0.7, tol: 1e-4),
        (expr: Exp(-x * x), point: 0.5, tol: 1e-4),
        (expr: Ln(x * x + 1), point: 1.2, tol: 1e-4),
        (expr: const Tanh(x), point: 0.8, tol: 1e-4),
        (expr: x / (x * x + 1), point: 1.5, tol: 1e-4),
        (
          expr: Pow(x * x + 1, const RationalNumber(1, 2)),
          point: 2.0,
          tol: 1e-4,
        ),
        (expr: const Atan(x), point: 0.6, tol: 1e-4),
        (expr: const Asin(x), point: 0.4, tol: 1e-4),
        (expr: x * x * x - x * x * 5 + x * 2 - 7, point: 3.0, tol: 1e-3),
      ];

      for (final tc in testCases) {
        final analyticalDeriv = tc.expr.derivative('x').simplify();
        final symFn = analyticalDeriv.toFunction1D('x');
        final baseFn = tc.expr.toFunction1D('x');
        final numVal = num_tools.derivative(baseFn, tc.point);
        final symVal = symFn(tc.point);
        check(symVal).isCloseTo(numVal, tc.tol);
      }
    });

    test('Definite Integral Parity across diverse functions', () {
      const x = Variable('x');
      final testCases = <({Expr expr, double a, double b, double tol})>[
        (expr: x.pow(3), a: 0.0, b: 1.0, tol: 1e-5),
        (expr: const Cos(x), a: 0.0, b: math.pi / 2.0, tol: 1e-5),
        (expr: const Exp(x), a: 0.0, b: 1.0, tol: 1e-5),
        (expr: const Pow(x, RationalNumber(1, 2)), a: 0.01, b: 4.0, tol: 1e-5),
        (expr: const Sinh(x), a: -1.0, b: 1.0, tol: 1e-5),
        (expr: const Cosh(x), a: 0.0, b: 1.0, tol: 1e-5),
      ];

      for (final tc in testCases) {
        final symIntegral = tc.expr.integrate('x', from: tc.a, to: tc.b);
        final baseFn = tc.expr.toFunction1D('x');
        final numVal = num_tools.integrate(baseFn, tc.a, tc.b);
        final symVal = symIntegral is Number
            ? symIntegral.value
            : symIntegral.evaluate(const {});
        check(symVal).isCloseTo(numVal, tc.tol);
      }
    });

    test('Real vs Complex Evaluation Consistency on Real Axis', () {
      const x = Variable('x');
      final expressions = <Expr>[
        x + 2,
        x * 3 - 5,
        x.pow(2) + x - 1,
        const Sin(x),
        const Cos(x),
        const Tan(x),
        const Sinh(x),
        const Cosh(x),
        const Tanh(x),
        const Exp(x),
        const Ln(x),
        const Atan(x),
        Abs(x - 2),
      ];

      for (final expr in expressions) {
        for (final val in [0.2, 0.7, 1.3, 2.5]) {
          final realVal = expr.evaluate({'x': val});
          final complexVal = expr.evaluateComplex({'x': Complex(val, 0)});
          check(complexVal.a).isCloseTo(realVal, 1e-10);
          check(complexVal.b).isCloseTo(0.0, 1e-10);
        }
      }
    });

    test('Multivariable Gradient & Hessian Parity', () {
      const x = Variable('x');
      const y = Variable('y');
      // f(x, y) = x^2 * y + y^3
      final f = x * x * y + y.pow(3);
      final grad = f.gradient(['x', 'y']);
      final gradX = grad[0].simplify();
      final gradY = grad[1].simplify();
      check(gradX.evaluate({'x': 2.0, 'y': 3.0})).equals(12.0);
      check(gradY.evaluate({'x': 2.0, 'y': 3.0})).equals(31.0);

      final h = f.hessian(['x', 'y']);
      check(h[0][0].simplify().evaluate({'x': 2.0, 'y': 3.0})).equals(6.0);
      check(h[0][1].simplify().evaluate({'x': 2.0, 'y': 3.0})).equals(4.0);
      check(h[1][0].simplify().evaluate({'x': 2.0, 'y': 3.0})).equals(4.0);
      check(h[1][1].simplify().evaluate({'x': 2.0, 'y': 3.0})).equals(18.0);
    });
  });

  group('Empirical Challenger: AST Canonicalization & Invariance Battery', () {
    test(
      'Simplification Idempotence (f(f(x)) == f(x)) across diverse expressions',
      () {
        const x = Variable('x');
        final candidates = <Expr>[
          (x + 0) * 1 + (x * 0),
          const Sin(x) * const Sin(x) + const Cos(x) * const Cos(x),
          Exp(Ln(x + 1)),
          Ln(Exp(x * x)),
          (i * i * i * i),
          const Pow(Pow(x, RationalNumber(2)), RationalNumber(1, 2)),
          (x * 4 + 8) / const RationalNumber(4),
        ];

        for (final expr in candidates) {
          final s1 = expr.simplify();
          final s2 = s1.simplify();
          check(s1).equals(s2);
        }
      },
    );

    test('Complex powers cyclic modulo-4 exhaustiveness', () {
      for (var k = -8; k <= 8; k++) {
        final simp = i.pow(k).simplify();
        final mod = ((k % 4) + 4) % 4;
        switch (mod) {
          case 0:
            check(simp).equals(const RationalNumber(1));
          case 1:
            check(simp).equals(i);
          case 2:
            check(simp).equals(const RationalNumber(-1));
          case 3:
            check(simp).equals(-i);
        }
      }
    });

    test('Factor and expand preservation across polynomial expressions', () {
      const x = Variable('x');
      final poly = (x - 1) * (x - 2) * (x - 3);
      final expanded = poly.expand();
      final factored = expanded.factor();
      for (final pt in [-2.0, 0.0, 1.5, 4.0, 10.0]) {
        check(factored.evaluate({'x': pt}))
            .isCloseTo(expanded.evaluate({'x': pt}), 1e-10);
      }
    });

    test('Analytical solver complex conjugate pairs', () {
      const x = Variable('x');
      // 2x^2 + 2x + 5 = 0: roots (-2 +/- sqrt(4 - 40))/4 = (-2 +/- 6i)/4 = -1/2 +/- 3/2 i
      final eq = x * x * 2 + x * 2 + 5;
      final roots = eq.solve('x');
      check(roots.length).equals(2);
      for (final r in roots) {
        final c = r.evaluateComplex();
        check(c.a).isCloseTo(-0.5, 1e-10);
        check(c.b.abs()).isCloseTo(1.5, 1e-10);
        final evalVal = eq.evaluateComplex({'x': c});
        check(evalVal.a).isCloseTo(0.0, 1e-10);
        check(evalVal.b).isCloseTo(0.0, 1e-10);
      }
    });
  });
}
