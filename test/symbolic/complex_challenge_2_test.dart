import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('Challenger 2 - Cyclic Power Simplification & Modulo Arithmetic', () {
    test('positive integer exponents of i', () {
      check(i.pow(0).simplify()).equals(RationalNumber.one);
      check(i.pow(1).simplify()).equals(i);
      check(i.pow(2).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(3).simplify()).equals(-i);
      check(i.pow(4).simplify()).equals(RationalNumber.one);
      check(i.pow(5).simplify()).equals(i);
      check(i.pow(6).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(7).simplify()).equals(-i);
      check(i.pow(8).simplify()).equals(RationalNumber.one);
      check(i.pow(100).simplify()).equals(RationalNumber.one);
      check(i.pow(101).simplify()).equals(i);
      check(i.pow(102).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(103).simplify()).equals(-i);
    });

    test('negative integer exponents of i', () {
      check(i.pow(-1).simplify()).equals(-i);
      check(i.pow(-2).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(-3).simplify()).equals(i);
      check(i.pow(-4).simplify()).equals(RationalNumber.one);
      check(i.pow(-5).simplify()).equals(-i);
      check(i.pow(-6).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(-7).simplify()).equals(i);
      check(i.pow(-8).simplify()).equals(RationalNumber.one);
      check(i.pow(-100).simplify()).equals(RationalNumber.one);
      check(i.pow(-101).simplify()).equals(-i);
    });

    test('powers of (-i) modulo 4', () {
      final negI = -i;
      check(negI.pow(0).simplify()).equals(RationalNumber.one);
      check(negI.pow(1).simplify()).equals(-i);
      check(negI.pow(2).simplify()).equals(RationalNumber.negativeOne);
      check(negI.pow(3).simplify()).equals(i);
      check(negI.pow(4).simplify()).equals(RationalNumber.one);
      check(negI.pow(5).simplify()).equals(-i);
      check(negI.pow(6).simplify()).equals(RationalNumber.negativeOne);
      check(negI.pow(7).simplify()).equals(i);
      check(negI.pow(8).simplify()).equals(RationalNumber.one);

      check(negI.pow(-1).simplify()).equals(i);
      check(negI.pow(-2).simplify()).equals(RationalNumber.negativeOne);
      check(negI.pow(-3).simplify()).equals(-i);
      check(negI.pow(-4).simplify()).equals(RationalNumber.one);
    });

    test('real number integer powers of i and (-i)', () {
      check(const Pow(i, RealNumber(2.0)).simplify())
          .equals(RationalNumber.negativeOne);
      check(const Pow(i, RealNumber(4.0)).simplify())
          .equals(RationalNumber.one);
      check(const Pow(i, RealNumber(3.0)).simplify()).equals(-i);
      check(Pow(-i, const RealNumber(2.0)).simplify())
          .equals(RationalNumber.negativeOne);
      check(Pow(-i, const RealNumber(3.0)).simplify()).equals(i);
    });

    test('fractional powers of i remain unreduced or evaluated properly', () {
      const halfPower = Pow(i, RationalNumber(1, 2));
      final simplified = halfPower.simplify();
      check(simplified).equals(halfPower);

      // sqrt(i) = exp(i * pi / 4) = cos(pi/4) + i * sin(pi/4) ~ 0.7071 + 0.7071i
      final evaluated = halfPower.evaluateComplex();
      final expectedSqrt2Over2 = math.sqrt(2) / 2;
      check((evaluated.a - expectedSqrt2Over2).abs()).isLessThan(1e-10);
      check((evaluated.b - expectedSqrt2Over2).abs()).isLessThan(1e-10);
    });
  });

  group('Challenger 2 - Multiplicative and Division Invariants', () {
    test('multiplication identities involving i and -i', () {
      check((i * i).simplify()).equals(RationalNumber.negativeOne);
      check((i * (-i)).simplify()).equals(RationalNumber.one);
      check(((-i) * i).simplify()).equals(RationalNumber.one);
      check(((-i) * (-i)).simplify()).equals(RationalNumber.negativeOne);

      check((i * 0).simplify()).equals(RationalNumber.zero);
      check((const RationalNumber(0) * i).simplify())
          .equals(RationalNumber.zero);
      check((i * 1).simplify()).equals(i);
      check((const RationalNumber(1) * i).simplify()).equals(i);
      check((i * -1).simplify()).equals(-i);
      check((const RationalNumber(-1) * i).simplify()).equals(-i);
    });

    test('multiplication scalar ordering canonicalization', () {
      // Numbers are pulled to the left
      check((x * i).simplify()).equals(i * x);
      check((i * 3).simplify()).equals(const RationalNumber(3) * i);
      check((const RationalNumber(3) * i).simplify())
          .equals(const RationalNumber(3) * i);
      check((i * const RationalNumber(2, 5)).simplify())
          .equals(const RationalNumber(2, 5) * i);
      check((const RationalNumber(2, 5) * i).simplify())
          .equals(const RationalNumber(2, 5) * i);
      check((i * const RealNumber(2.5)).simplify())
          .equals(const RealNumber(2.5) * i);
    });

    test('division by i and -i', () {
      check((RationalNumber.one / i).simplify()).equals(-i);
      check((RationalNumber.one / (-i)).simplify()).equals(i);
      check((i / i).simplify()).equals(RationalNumber.one);
      check(((-i) / i).simplify()).equals(RationalNumber.negativeOne);
      check((i / (-i)).simplify()).equals(RationalNumber.negativeOne);
      check(((-i) / (-i)).simplify()).equals(RationalNumber.one);
      check((RationalNumber.zero / i).simplify()).equals(RationalNumber.zero);

      final divVar = (x / i).simplify();
      check(divVar).equals(-(i * x));

      final divNegVar = (x / (-i)).simplify();
      check(divNegVar).equals(i * x);

      check(() => (i / RationalNumber.zero).simplify())
          .throws<UnsupportedError>();
    });
  });

  group('Challenger 2 - TermAccumulator Grouping & Polynomial Reductions', () {
    test('exact Gaussian sum and difference reduction', () {
      final z1 = const RationalNumber(2) + (const RationalNumber(3) * i);
      final z2 = const RationalNumber(4) + (const RationalNumber(5) * i);

      // (2 + 3i) + (4 + 5i) = 6 + 8i
      check((z1 + z2).simplify())
          .equals(const RationalNumber(6) + (const RationalNumber(8) * i));

      // (2 + 3i) - (4 + 5i) = -2 - 2i
      check((z1 - z2).simplify())
          .equals(const RationalNumber(-2) - (const RationalNumber(2) * i));

      // self cancellation: z1 - z1 = 0
      check((z1 - z1).simplify()).equals(RationalNumber.zero);

      // complex conjugate sum: (a + bi) + (a - bi) = 2a
      final conj = const RationalNumber(2) - (const RationalNumber(3) * i);
      check((z1 + conj).simplify()).equals(const RationalNumber(4));

      // complex conjugate difference: (a + bi) - (a - bi) = 2bi
      check((z1 - conj).simplify()).equals(const RationalNumber(6) * i);
    });

    test('polynomial expressions with complex coefficients', () {
      // (x^2 + 2*i*x + 1) + (3*x^2 - i*x + 4) = 4*x^2 + i*x + 5
      final p1 =
          x.pow(2) +
          (const RationalNumber(2) * (i * x)) +
          const RationalNumber(1);
      final p2 =
          (const RationalNumber(3) * x.pow(2)) -
          (i * x) +
          const RationalNumber(4);

      final sum = (p1 + p2).simplify();
      check(sum).equals(
        (const RationalNumber(4) * x.pow(2)) +
            (i * x) +
            const RationalNumber(5),
      );

      // (p1 - p1) = 0
      check((p1 - p1).simplify()).equals(RationalNumber.zero);
    });

    test('Expr.expand() followed by simplify() on complex polynomials', () {
      // (x + i) * (x - i) = x^2 + 1
      final p = (x + i) * (x - i);
      final expanded = p.expand();
      check(expanded.simplify()).equals(x.pow(2) + RationalNumber.one);

      // (x + i)^2 = x^2 + 2*i*x - 1
      final pSq = (x + i).pow(2);
      check(pSq.expand().simplify()).equals(
        x.pow(2) + (const RationalNumber(2) * (i * x)) - RationalNumber.one,
      );

      // (x + 1 + i) * (x + 1 - i) = x^2 + 2*x + 2
      final pShifted =
          (x + RationalNumber.one + i) * (x + RationalNumber.one - i);
      check(pShifted.expand().simplify()).equals(
        x.pow(2) + (const RationalNumber(2) * x) + const RationalNumber(2),
      );

      // Gaussian product expansion: (2 + 3i) * (4 + 5i) = -7 + 22i
      final zProd =
          (const RationalNumber(2) + const RationalNumber(3) * i) *
          (const RationalNumber(4) + const RationalNumber(5) * i);
      check(zProd.expand().simplify())
          .equals(const RationalNumber(-7) + const RationalNumber(22) * i);
    });
  });

  group(
    'Challenger 2 - Structural Order Stability & Total Ordering Invariants',
    () {
      final testNodes = <Expr>[
        RationalNumber.zero,
        RationalNumber.one,
        RationalNumber.negativeOne,
        const RationalNumber(1, 2),
        const RealNumber(0.5),
        const RealNumber(2.718),
        ConstantNumber.e,
        ConstantNumber.pi,
        ConstantNumber.i,
        const ComplexNumber(Complex(0, 1)),
        const ComplexNumber(Complex(1, 2)),
        const ComplexNumber(Complex(2, -1)),
        x,
        y,
        -x,
        -i,
        x + 1,
        x + i,
        x * i,
        i * x,
        x.pow(2),
        const Pow(i, RationalNumber(2)),
        const Sin(x),
        const Cos(i),
        Exp(i * ConstantNumber.pi),
        const Ln(x),
      ];

      test('structural order satisfies reflexivity', () {
        for (final node in testNodes) {
          check(compareStructural(node, node)).equals(0);
        }
      });

      test('structural order satisfies antisymmetry', () {
        for (var j = 0; j < testNodes.length; j++) {
          for (var k = 0; k < testNodes.length; k++) {
            final cmpJK = compareStructural(testNodes[j], testNodes[k]);
            final cmpKJ = compareStructural(testNodes[k], testNodes[j]);
            if (cmpJK == 0) {
              check(cmpKJ).equals(0);
            } else if (cmpJK < 0) {
              check(cmpKJ).isGreaterThan(0);
            } else {
              check(cmpKJ).isLessThan(0);
            }
          }
        }
      });

      test('structural order satisfies transitivity', () {
        for (var a = 0; a < testNodes.length; a++) {
          for (var b = 0; b < testNodes.length; b++) {
            final cmpAB = compareStructural(testNodes[a], testNodes[b]);
            if (cmpAB <= 0) {
              for (var c = 0; c < testNodes.length; c++) {
                final cmpBC = compareStructural(testNodes[b], testNodes[c]);
                if (cmpBC <= 0) {
                  final cmpAC = compareStructural(testNodes[a], testNodes[c]);
                  check(cmpAC).isLessOrEqual(0);
                }
              }
            }
          }
        }
      });

      test('sorting expressions is stable and deterministic', () {
        final list1 = List<Expr>.from(testNodes)..shuffle(math.Random(42));
        final list2 = List<Expr>.from(testNodes)..shuffle(math.Random(99));
        list1.sort(compareStructural);
        list2.sort(compareStructural);
        check(list1).deepEquals(list2);
      });

      test('ComplexNumber comparison order', () {
        const c1 = ComplexNumber(Complex(1, 2));
        const c2 = ComplexNumber(Complex(1, 3));
        const c3 = ComplexNumber(Complex(2, 0));
        const c4 = ComplexNumber(Complex(1, 2));

        check(compareStructural(c1, c4)).equals(0);
        check(compareStructural(c1, c2)).isLessThan(0);
        check(compareStructural(c2, c1)).isGreaterThan(0);
        check(compareStructural(c1, c3)).isLessThan(0);
        check(compareStructural(c3, c1)).isGreaterThan(0);
      });
    },
  );

  group('Challenger 2 - Transcendentals on Complex Domain', () {
    test('Euler identity: exp(i * pi) + 1 = 0', () {
      final euler = Exp(i * ConstantNumber.pi) + RationalNumber.one;
      final evaluated = euler.evaluateComplex();
      check(evaluated.a.abs()).isLessThan(1e-12);
      check(evaluated.b.abs()).isLessThan(1e-12);

      final compiled1D = euler.toComplexFunction1D('x');
      final val1D = compiled1D(Complex.zero);
      check(val1D.a.abs()).isLessThan(1e-12);
      check(val1D.b.abs()).isLessThan(1e-12);

      final compiledMap = euler.compileComplex();
      final valMap = compiledMap({});
      check(valMap.a.abs()).isLessThan(1e-12);
      check(valMap.b.abs()).isLessThan(1e-12);
    });

    test('exp(i * pi / 2) = i and exp(i * 2 * pi) = 1', () {
      final expHalfPi = Exp(i * (ConstantNumber.pi / const RationalNumber(2)));
      final valHalfPi = expHalfPi.evaluateComplex();
      check(valHalfPi.a.abs()).isLessThan(1e-12);
      check((valHalfPi.b - 1.0).abs()).isLessThan(1e-12);

      final exp2Pi = Exp(i * (const RationalNumber(2) * ConstantNumber.pi));
      final val2Pi = exp2Pi.evaluateComplex();
      check((val2Pi.a - 1.0).abs()).isLessThan(1e-12);
      check(val2Pi.b.abs()).isLessThan(1e-12);
    });

    test('trigonometric and hyperbolic bridge identities', () {
      // sin(i * z) delegates directly to Complex.sin()
      final sinIZ = Sin(i * const RealNumber(1.5)).evaluateComplex();
      final expectedSin = const Complex(0, 1.5).sin();
      check((sinIZ - expectedSin).abs()).isLessThan(1e-12);

      // cos(i * z) delegates directly to Complex.cos()
      final cosIZ = Cos(i * const RealNumber(1.5)).evaluateComplex();
      final expectedCos = const Complex(0, 1.5).cos();
      check((cosIZ - expectedCos).abs()).isLessThan(1e-12);

      // tan(i * z) delegates directly to Complex.tan()
      final tanIZ = Tan(i * const RealNumber(1.5)).evaluateComplex();
      final expectedTan = const Complex(0, 1.5).tan();
      check((tanIZ - expectedTan).abs()).isLessThan(1e-12);
    });

    test('complex logarithms and branch cuts', () {
      // ln(-1) = i * pi
      final lnNeg1 = const Ln(RationalNumber.negativeOne).evaluateComplex();
      check(lnNeg1.a.abs()).isLessThan(1e-12);
      check((lnNeg1.b - math.pi).abs()).isLessThan(1e-12);

      // ln(i) = i * pi / 2
      final lnI = const Ln(i).evaluateComplex();
      check(lnI.a.abs()).isLessThan(1e-12);
      check((lnI.b - math.pi / 2).abs()).isLessThan(1e-12);

      // ln(-e) = 1 + i * pi
      final lnNegE = Ln(-ConstantNumber.e).evaluateComplex();
      check((lnNegE.a - 1.0).abs()).isLessThan(1e-12);
      check((lnNegE.b - math.pi).abs()).isLessThan(1e-12);
    });

    test('complex absolute value and roots', () {
      // |3 + 4i| = 5
      final absZ = const Abs(ComplexNumber(Complex(3, 4))).evaluateComplex();
      check((absZ.a - 5.0).abs()).isLessThan(1e-12);
      check(absZ.b).equals(0.0);

      // sqrt(-4) = (-4)^(1/2) = 2i
      final sqrtNeg4 = const Pow(
        RationalNumber(-4),
        RationalNumber(1, 2),
      ).evaluateComplex();
      check(sqrtNeg4.a.abs()).isLessThan(1e-12);
      check((sqrtNeg4.b - 2.0).abs()).isLessThan(1e-12);
    });
  });

  group('Challenger 2 - Parity: evaluateComplex vs toComplexFunction1D vs compileComplex', () {
    final random = math.Random(12345);

    List<Complex> generateTestPoints() {
      final points = <Complex>[
        Complex.zero,
        Complex.one,
        -Complex.one,
        Complex.i,
        -Complex.i,
        const Complex(0.5, 0.5),
        const Complex(-0.5, 0.5),
        const Complex(-0.5, -0.5),
        const Complex(0.5, -0.5),
        const Complex(2.0, 0.0),
        const Complex(-2.0, 0.0),
        const Complex(0.0, 2.0),
        const Complex(0.0, -2.0),
      ];

      // Add 100 randomized complex numbers across various radii and angles
      for (var j = 0; j < 100; j++) {
        final r = math.exp(
          (random.nextDouble() - 0.5) * 6,
        ); // radii in [e^-3, e^3]
        final theta = (random.nextDouble() * 2 - 1) * math.pi;
        points.add(Complex.fromPolar(r, theta));
      }
      return points;
    }

    final testPoints = generateTestPoints();

    void verifyParity(Expr expr, {bool avoidPoles = false}) {
      final fn1D = expr.toComplexFunction1D('x');
      final fnMap = expr.compileComplex();

      for (final pt in testPoints) {
        if (avoidPoles &&
            (pt.abs() < 1e-4 || (pt - Complex.one).abs() < 1e-4)) {
          continue;
        }

        Complex valInterpreted;
        try {
          valInterpreted = expr.evaluateComplex({'x': pt});
        } catch (_) {
          continue;
        }

        final val1D = fn1D(pt);
        final valMap = fnMap({'x': pt});

        if (valInterpreted.isNaN) {
          check(val1D.isNaN).isTrue();
          check(valMap.isNaN).isTrue();
        } else if (valInterpreted.isInfinite) {
          check(val1D.isInfinite).isTrue();
          check(valMap.isInfinite).isTrue();
        } else {
          check((val1D.a - valInterpreted.a).abs()).isLessThan(1e-9);
          check((val1D.b - valInterpreted.b).abs()).isLessThan(1e-9);
          check((valMap.a - valInterpreted.a).abs()).isLessThan(1e-9);
          check((valMap.b - valInterpreted.b).abs()).isLessThan(1e-9);
        }
      }
    }

    test('polynomial parity with complex coefficients: x^3 - 2*i*x^2 + (3 - i)*x + 5', () {
      final expr =
          x.pow(3) -
          (const RationalNumber(2) * (i * x.pow(2))) +
          ((const RationalNumber(3) - i) * x) +
          const RationalNumber(5);
      verifyParity(expr);
    });

    test('rational function parity: (x + i) / (x - i)', () {
      final expr = (x + i) / (x - i);
      verifyParity(expr, avoidPoles: true);
    });

    test('transcendental parity: sin(x * i) + cos(x)', () {
      final expr = Sin(x * i) + const Cos(x);
      verifyParity(expr);
    });

    test('hyperbolic parity: sinh(x) + cosh(x * i)', () {
      final expr = const Sinh(x) + Cosh(x * i);
      verifyParity(expr);
    });

    test('exponential & logarithmic parity: exp(x) - ln(x + 5)', () {
      final expr = const Exp(x) - Ln(x + const RationalNumber(5));
      verifyParity(expr, avoidPoles: true);
    });

    test('arbitrary base logarithm: log(x + 2, x + 5)', () {
      final expr = Log(
        x + const RationalNumber(2),
        x + const RationalNumber(5),
      );
      verifyParity(expr, avoidPoles: true);
    });

    test('absolute value and complex root: abs(x) + sqrt(x)', () {
      final expr = const Abs(x) + const Pow(x, RationalNumber(1, 2));
      verifyParity(expr, avoidPoles: true);
    });

    test('inverse trigonometric parity: asin(x) + acos(x) + atan(x)', () {
      final expr = const Asin(x) + const Acos(x) + const Atan(x);
      verifyParity(expr, avoidPoles: true);
    });

    test('inverse hyperbolic parity: tanh(x)', () {
      const expr = Tanh(x);
      verifyParity(expr);
    });

    test('multi-variable compileComplex parity across random 2D grids', () {
      final expr =
          (x * x) + (const RationalNumber(2) * (i * (x * y))) - (y * y);
      final fn = expr.compileComplex();

      for (var j = 0; j < 25; j++) {
        final ptX = Complex.fromPolar(
          math.exp(random.nextDouble() * 2),
          random.nextDouble() * 2 * math.pi,
        );
        final ptY = Complex.fromPolar(
          math.exp(random.nextDouble() * 2),
          random.nextDouble() * 2 * math.pi,
        );

        final interpreted = expr.evaluateComplex({'x': ptX, 'y': ptY});
        final compiled = fn({'x': ptX, 'y': ptY});

        check((compiled.a - interpreted.a).abs()).isLessThan(1e-9);
        check((compiled.b - interpreted.b).abs()).isLessThan(1e-9);
      }
    });
  });

  group('Challenger 2 - Textualization, Precedence & Parser Round-trips', () {
    test('String formatting with complex precedence and parenthesization', () {
      check(i.toString()).equals('i');
      check((-i).toString()).equals('-i');
      check((const RationalNumber(2) * i).toString()).equals('2 * i');
      check((-const RationalNumber(2) * i).toString()).equals('-2 * i');

      const cSum = ComplexNumber(Complex(1, 2));
      const cDiff = ComplexNumber(Complex(3, -4));
      check(cSum.toString()).equals('1 + 2 * i');
      check(cDiff.toString()).equals('3 - 4 * i');

      // Multiplication by a sum should parenthesize the complex number
      const mulComplex = Mul(RationalNumber(5), cSum);
      check(formatExpr(mulComplex)).equals('5 * (1 + 2 * i)');

      // Power base should parenthesize
      const powComplex = Pow(cSum, RationalNumber(2));
      check(formatExpr(powComplex)).equals('(1 + 2 * i) ^ 2');
    });

    test('LaTeX serialization with complex numbers', () {
      check(i.toLatex()).equals('i');
      check((-i).toLatex()).equals('-i');
      check((const RationalNumber(3) * i).toLatex()).equals('3 \\cdot i');

      const c = ComplexNumber(Complex(2, -3));
      check(c.toLatex()).equals('2 - 3 i');

      const mul = Mul(RationalNumber(4), c);
      check(mul.toLatex()).equals('4 \\cdot (2 - 3 i)');

      const pow = Pow(c, RationalNumber(3));
      check(pow.toLatex()).equals('{(2 - 3 i)}^{3}');
    });

    test('MathML serialization with complex numbers', () {
      check(i.toMathMl()).equals('<math><mi>i</mi></math>');
      check((-i).toMathMl())
          .equals('<math><mrow><mo>-</mo><mi>i</mi></mrow></math>');

      const c = ComplexNumber(Complex(1, 1));
      check(c.toMathMl())
          .equals('<math><mrow><mn>1</mn><mo>+</mo><mi>i</mi></mrow></math>');

      const cScaled = ComplexNumber(Complex(2, 3));
      check(cScaled.toMathMl()).equals(
        '<math><mrow><mn>2</mn><mo>+</mo><mrow><mn>3</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow></math>',
      );

      const mul = Mul(RationalNumber(5), cScaled);
      check(mul.toMathMl()).equals(
        '<math><mrow><mn>5</mn><mo>&#x22c5;</mo><mrow><mo>(</mo><mrow><mn>2</mn><mo>+</mo><mrow><mn>3</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow><mo>)</mo></mrow></mrow></math>',
      );
    });

    test('Parser round-trip and identifier distinction', () {
      check(Expr.parse('i')).equals(ConstantNumber.i);
      check(Expr.parse('2 * i')).equals(const RationalNumber(2) * i);
      check(Expr.parse('1 + 2 * i'))
          .equals(const RationalNumber(1) + const RationalNumber(2) * i);

      // 'identity' should parse as Variable('identity'), not ConstantNumber.i * dentity
      final varIdent = Expr.parse('identity');
      check(varIdent).isA<Variable>();
      check((varIdent as Variable).name).equals('identity');

      // 'item' should parse as Variable('item')
      final varItem = Expr.parse('item');
      check(varItem).isA<Variable>();
      check((varItem as Variable).name).equals('item');

      // Parsing expression string round-trip
      final expr =
          (const RationalNumber(2) * x.pow(2)) + (const RationalNumber(3) * i);
      final parsed = Expr.parse(expr.toString());
      check(parsed.evaluateComplex({'x': const Complex(1, 1)}))
          .equals(expr.evaluateComplex({'x': const Complex(1, 1)}));
    });
  });

  group('Challenger 2 - Calculus and Real-Compatibility Guards', () {
    test('differentiation of complex and imaginary expressions', () {
      // d/dx [i] = 0
      check(i.derivative('x')).equals(RationalNumber.zero);

      // d/dx [ComplexNumber(1, 2)] = 0
      check(const ComplexNumber(Complex(1, 2)).derivative('x'))
          .equals(RationalNumber.zero);

      // d/dx [x * i] = i
      check((x * i).derivative('x').simplify()).equals(i);

      // d/dx [i * x^2] = 2 * i * x
      check((i * x.pow(2)).derivative('x').simplify())
          .equals(const RationalNumber(2) * (i * x));

      // d/dx [exp(i * x)] = i * exp(i * x)
      check(Exp(i * x).derivative('x').simplify()).equals(i * Exp(i * x));
    });

    test(
      'real evaluators and compilers safely reject imaginary expressions',
      () {
        // evaluate() on ConstantNumber.i throws UnsupportedError
        check(() => (x + i).evaluate({'x': 1.0})).throws<UnsupportedError>();

        // evaluate() on ComplexNumber with b != 0 throws UnsupportedError
        check(
          () => (x + const ComplexNumber(Complex(1, 1))).evaluate({'x': 1.0}),
        ).throws<UnsupportedError>();

        // evaluate() on ComplexNumber with b == 0 succeeds
        check((x + const ComplexNumber(Complex(5, 0))).evaluate({'x': 1.0}))
            .equals(6.0);

        // toFunction1D rejects i
        check(() => (x * i).toFunction1D('x')).throws<UnsupportedError>();

        // compile rejects i
        check(() => (x * i).compile(['x'])).throws<UnsupportedError>();

        // compileTensorKernel rejects i
        check(() => (x * i).compileTensorKernel(['x']))
            .throws<UnsupportedError>();

        // compileTensorKernel rejects ComplexNumber
        check(
          () => (x + const ComplexNumber(Complex(1, 2))).compileTensorKernel([
            'x',
          ]),
        ).throws<UnsupportedError>();
      },
    );

    test('powers of zero in complex domain and ComplexNumber leaf node simplification', () {
      final xSq = x.pow(2);
      final valPow = xSq.evaluateComplex({'x': Complex.zero});
      check(valPow).equals(Complex.zero);

      final xMul = x * x;
      final valMul = xMul.evaluateComplex({'x': Complex.zero});
      check(valMul).equals(Complex.zero);

      final fnFast = xMul.toComplexFunction1D('x');
      final valFast = fnFast(Complex.zero);
      check(valFast).equals(Complex.zero);

      // ComplexNumber leaf node simplification
      const c1 = ComplexNumber(Complex(1, 2));
      const c2 = ComplexNumber(Complex(3, 4));
      check((c1 + c2).simplify())
          .equals(const RationalNumber(4) + const RationalNumber(6) * i);
    });
  });

  group('Challenger 2 - Higher Degree Polynomials with Complex Roots & Multi-Factor Expansion', () {
    test('expanding and simplifying products of complex linear factors', () {
      // (x + i) * (x - i) * (x + 2*i) * (x - 2*i) = (x^2 + 1) * (x^2 + 4) = x^4 + 5*x^2 + 4
      final p1 =
          ((x + i) * (x - i)) *
          ((x + const RationalNumber(2) * i) *
              (x - const RationalNumber(2) * i));
      final expanded1 = p1.expand().simplify();
      check(expanded1).equals(
        x.pow(4) +
            (const RationalNumber(5) * x.pow(2)) +
            const RationalNumber(4),
      );

      // (x - (1 + i)) * (x - (1 - i)) * (x - 2*i) * (x + 2*i)
      // = (x^2 - 2*x + 2) * (x^2 + 4) = x^4 - 2*x^3 + 6*x^2 - 8*x + 8
      final p2 =
          ((x - RationalNumber.one - i) * (x - RationalNumber.one + i)) *
          ((x - const RationalNumber(2) * i) *
              (x + const RationalNumber(2) * i));
      final expanded2 = p2.expand().simplify();
      check(expanded2).equals(
        x.pow(4) -
            (const RationalNumber(2) * x.pow(3)) +
            (const RationalNumber(6) * x.pow(2)) -
            (const RationalNumber(8) * x) +
            const RationalNumber(8),
      );

      // Expanding products with ComplexNumber leaf nodes
      final pComplexNodes =
          ((x - const ComplexNumber(Complex(1, 1))) *
              (x - const ComplexNumber(Complex(1, -1)))) *
          ((x - const ComplexNumber(Complex(0, 2))) *
              (x + const ComplexNumber(Complex(0, 2))));
      final expandedComplex = pComplexNodes.expand().simplify();
      check(expandedComplex).equals(
        x.pow(4) -
            (const RationalNumber(2) * x.pow(3)) +
            (const RationalNumber(6) * x.pow(2)) -
            (const RationalNumber(8) * x) +
            const RationalNumber(8),
      );
    });

    test('expanding higher-degree powers of complex binomials', () {
      // (x + i)^3 = x^3 + 3*i*x^2 - 3*x - i
      final pCube = (x + i).pow(3);
      check(pCube.expand().simplify()).equals(
        x.pow(3) +
            (const RationalNumber(3) * (i * x.pow(2))) -
            (const RationalNumber(3) * x) -
            i,
      );

      // (x - i)^4 = x^4 - 4*i*x^3 - 6*x^2 + 4*i*x + 1
      final pQuad = (x - i).pow(4);
      check(pQuad.expand().simplify()).equals(
        x.pow(4) -
            (const RationalNumber(4) * (i * x.pow(3))) -
            (const RationalNumber(6) * x.pow(2)) +
            (const RationalNumber(4) * (i * x)) +
            RationalNumber.one,
      );

      // (x + 1 + i)^2 = x^2 + 2*x + 2*i*x + 2*i
      final pShiftSq = (x + RationalNumber.one + i).pow(2);
      check(pShiftSq.expand().simplify()).equals(
        x.pow(2) +
            (const RationalNumber(2) * (i * x)) +
            (const RationalNumber(2) * x) +
            (const RationalNumber(2) * i),
      );
    });

    test('evaluation of degree 4 polynomial with complex roots at 0 and complex points', () {
      final p =
          ((x - RationalNumber.one - i) * (x - RationalNumber.one + i)) *
          ((x - const RationalNumber(2) * i) *
              (x + const RationalNumber(2) * i));
      final fn = p.toComplexFunction1D('x');
      final compiled = p.compileComplex();

      void checkAt(Complex z, Complex expected) {
        final valEval = p.evaluateComplex({'x': z});
        final valFn = fn(z);
        final valCompiled = compiled({'x': z});
        check((valEval.a - expected.a).abs()).isLessThan(1e-10);
        check((valEval.b - expected.b).abs()).isLessThan(1e-10);
        check((valFn.a - expected.a).abs()).isLessThan(1e-10);
        check((valFn.b - expected.b).abs()).isLessThan(1e-10);
        check((valCompiled.a - expected.a).abs()).isLessThan(1e-10);
        check((valCompiled.b - expected.b).abs()).isLessThan(1e-10);
      }

      // Evaluated at 0: p(0) = (-1 - i)(-1 + i)(-2i)(2i) = 2 * 4 = 8
      checkAt(Complex.zero, const Complex(8, 0));

      // Evaluated at roots: 1 + i, 1 - i, 2i, -2i -> 0
      checkAt(const Complex(1, 1), Complex.zero);
      checkAt(const Complex(1, -1), Complex.zero);
      checkAt(const Complex(0, 2), Complex.zero);
      checkAt(const Complex(0, -2), Complex.zero);

      // Evaluated at complex points:
      // p(i) = (i^2 - 2i + 2)(i^2 + 4) = (1 - 2i)(3) = 3 - 6i
      checkAt(const Complex(0, 1), const Complex(3, -6));
      // p(1) = (1 - 2 + 2)(1 + 4) = 5
      checkAt(const Complex(1, 0), const Complex(5, 0));
    });

    test('evaluation of degree 6 polynomial with complex roots at 0 and complex points', () {
      // Q(x) = (x^2 + 1) * (x^2 + 4) * (x^2 + 9)
      final q =
          (x.pow(2) + RationalNumber.one) *
          (x.pow(2) + const RationalNumber(4)) *
          (x.pow(2) + const RationalNumber(9));
      final fn = q.toComplexFunction1D('x');
      final compiled = q.compileComplex();

      void checkAt(Complex z, Complex expected) {
        final valEval = q.evaluateComplex({'x': z});
        final valFn = fn(z);
        final valCompiled = compiled({'x': z});
        check((valEval.a - expected.a).abs()).isLessThan(1e-10);
        check((valEval.b - expected.b).abs()).isLessThan(1e-10);
        check((valFn.a - expected.a).abs()).isLessThan(1e-10);
        check((valFn.b - expected.b).abs()).isLessThan(1e-10);
        check((valCompiled.a - expected.a).abs()).isLessThan(1e-10);
        check((valCompiled.b - expected.b).abs()).isLessThan(1e-10);
      }

      // At x = 0: Q(0) = 1 * 4 * 9 = 36
      checkAt(Complex.zero, const Complex(36, 0));

      // At roots: +-i, +-2i, +-3i
      checkAt(const Complex(0, 1), Complex.zero);
      checkAt(const Complex(0, -1), Complex.zero);
      checkAt(const Complex(0, 2), Complex.zero);
      checkAt(const Complex(0, -2), Complex.zero);
      checkAt(const Complex(0, 3), Complex.zero);
      checkAt(const Complex(0, -3), Complex.zero);

      // At x = 1: Q(1) = (2)(5)(10) = 100
      checkAt(const Complex(1, 0), const Complex(100, 0));

      // At x = 1 + i: (1+i)^2 = 2i; (1+2i)(4+2i)(9+2i) = -20 + 90i
      checkAt(const Complex(1, 1), const Complex(-20, 90));
    });

    test(
      'rational function with complex roots evaluated at 0 and complex points',
      () {
        // H(x) = (x^2 + 1) / (x^2 + 4)
        final h =
            (x.pow(2) + RationalNumber.one) /
            (x.pow(2) + const RationalNumber(4));
        final fn = h.toComplexFunction1D('x');
        final compiled = h.compileComplex();

        void checkAt(Complex z, Complex expected) {
          final valEval = h.evaluateComplex({'x': z});
          final valFn = fn(z);
          final valCompiled = compiled({'x': z});
          check((valEval.a - expected.a).abs()).isLessThan(1e-10);
          check((valEval.b - expected.b).abs()).isLessThan(1e-10);
          check((valFn.a - expected.a).abs()).isLessThan(1e-10);
          check((valFn.b - expected.b).abs()).isLessThan(1e-10);
          check((valCompiled.a - expected.a).abs()).isLessThan(1e-10);
          check((valCompiled.b - expected.b).abs()).isLessThan(1e-10);
        }

        // At x = 0: H(0) = 1 / 4 = 0.25
        checkAt(Complex.zero, const Complex(0.25, 0));

        // At roots of numerator: +-i -> 0
        checkAt(const Complex(0, 1), Complex.zero);
        checkAt(const Complex(0, -1), Complex.zero);

        // At x = 1: H(1) = 2 / 5 = 0.4
        checkAt(const Complex(1, 0), const Complex(0.4, 0));

        // At x = 3i: H(3i) = (-9 + 1) / (-9 + 4) = -8 / -5 = 1.6
        checkAt(const Complex(0, 3), const Complex(1.6, 0));
      },
    );

    test('multi-factor chained product expansion and odd binomial power 5', () {
      // ((x + 1) * (x + i) * (x - i)) = (x + 1) * (x^2 + 1) = x^3 + x^2 + x + 1
      final pChain = (x + RationalNumber.one) * (x + i) * (x - i);
      check(pChain.expand().simplify())
          .equals(x.pow(3) + x.pow(2) + x + RationalNumber.one);

      // (x + i) * (x + 2*i) * (x + 3*i)
      // = (x^2 + 3*i*x - 2) * (x + 3*i) = x^3 + 6*i*x^2 - 11*x - 6*i
      final pThreeRoots =
          (x + i) *
          (x + const RationalNumber(2) * i) *
          (x + const RationalNumber(3) * i);
      check(pThreeRoots.expand().simplify()).equals(
        x.pow(3) +
            (const RationalNumber(6) * (i * x.pow(2))) -
            (const RationalNumber(11) * x) -
            (const RationalNumber(6) * i),
      );

      // (x - i)^5 = x^5 - 5*i*x^4 - 10*x^3 + 10*i*x^2 + 5*x - i
      final pPower5 = (x - i).pow(5);
      final expanded5 = pPower5.expand().simplify();
      check(expanded5).equals(
        x.pow(5) -
            (const RationalNumber(5) * (i * x.pow(4))) -
            (const RationalNumber(10) * x.pow(3)) +
            (const RationalNumber(10) * (i * x.pow(2))) +
            (const RationalNumber(5) * x) -
            i,
      );

      // Evaluate at x = 0: (0 - i)^5 = -i
      final atZero = pPower5.evaluateComplex({'x': Complex.zero});
      check(atZero.a.abs()).isLessThan(1e-10);
      check((atZero.b - (-1.0)).abs()).isLessThan(1e-10);
      check(expanded5.evaluateComplex({'x': Complex.zero}))
          .equals(const Complex(0, -1));

      // Evaluate at root x = i: (i - i)^5 = 0
      check(pPower5.evaluateComplex({'x': const Complex(0, 1)}))
          .equals(Complex.zero);
      final atRoot = expanded5.evaluateComplex({'x': const Complex(0, 1)});
      check(atRoot.a.abs()).isLessThan(1e-10);
      check(atRoot.b.abs()).isLessThan(1e-10);
    });

    test('differentiation commutes with expansion on complex polynomials', () {
      // P(x) = (x + i)^4 = x^4 + 4*i*x^3 - 6*x^2 - 4*i*x + 1
      // d/dx [P(x)] = 4*x^3 + 12*i*x^2 - 12*x - 4*i
      final p = (x + i).pow(4);
      final d1 = p.derivative('x').expand().simplify();
      final d2 = p.expand().simplify().derivative('x').simplify();
      check(d1).equals(d2);
      check(d1).equals(
        (const RationalNumber(4) * x.pow(3)) +
            (const RationalNumber(12) * (i * x.pow(2))) -
            (const RationalNumber(12) * x) -
            (const RationalNumber(4) * i),
      );
    });
  });
}
