import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('ConstantNumber.i properties', () {
    test('symbolic identity and name', () {
      check(ConstantNumber.i.name).equals('i');
      check(i).equals(ConstantNumber.i);
      check(i.toString()).equals('i');
    });

    test('variable dependency and calculus properties', () {
      check(i.freeVariables).isEmpty();
      check(i.dependsOn('x')).isFalse();
      check(i.derivative('x')).equals(RationalNumber.zero);
    });

    test('type checks and value access', () {
      check(i.isReal).isFalse();
      check(i.complexValue).equals(Complex.i);
      check(() => i.value).throws<UnsupportedError>();
    });
  });

  group('Complex wrapping and conversion', () {
    test('operator overloads wrap Complex operands', () {
      final exprAdd = x + const Complex(1, 2);
      check(exprAdd).equals(
        const Add(
          x,
          Add(RationalNumber(1), Mul(RationalNumber(2), ConstantNumber.i)),
        ),
      );

      final exprMul = x * Complex.i;
      check(exprMul).equals(const Mul(x, ConstantNumber.i));

      final exprReal = x + const Complex(5, 0);
      check(exprReal).equals(const Add(x, RationalNumber(5)));
    });
  });

  group('Exact Gaussian arithmetic', () {
    test('addition of complex and imaginary terms', () {
      final expr1 =
          (const RationalNumber(2) * i) + (const RationalNumber(3) * i);
      check(expr1.simplify()).equals(const RationalNumber(5) * i);

      final expr2 = i + (-i);
      check(expr2.simplify()).equals(RationalNumber.zero);

      final expr3 =
          (const RationalNumber(1) + (const RationalNumber(2) * i)) +
          (const RationalNumber(3) - (const RationalNumber(2) * i));
      check(expr3.simplify()).equals(const RationalNumber(4));
    });

    test('subtraction of complex and imaginary terms', () {
      final expr1 =
          (const RationalNumber(5) * i) - (const RationalNumber(2) * i);
      check(expr1.simplify()).equals(const RationalNumber(3) * i);

      final expr2 = i - i;
      check(expr2.simplify()).equals(RationalNumber.zero);
    });

    test('multiplication reductions and constant ordering', () {
      final expr1 = i * i;
      check(expr1.simplify()).equals(RationalNumber.negativeOne);

      final expr2 =
          (const RationalNumber(2) * i) * (const RationalNumber(3) * i);
      check(expr2.simplify()).equals(const RationalNumber(-6));

      final expr3 = i * (-i);
      check(expr3.simplify()).equals(RationalNumber.one);

      final expr4 = (-i) * i;
      check(expr4.simplify()).equals(RationalNumber.one);

      final expr5 = (-i) * (-i);
      check(expr5.simplify()).equals(RationalNumber.negativeOne);

      final expr6 = i * const RationalNumber(3);
      check(expr6.simplify()).equals(const RationalNumber(3) * i);
    });

    test('division by imaginary unit', () {
      check((RationalNumber.one / i).simplify()).equals(-i);
      check((RationalNumber.negativeOne / i).simplify()).equals(i);
      check((i / i).simplify()).equals(RationalNumber.one);
      check((const RationalNumber(2) / i).simplify())
          .equals(const RationalNumber(-2) * i);
      check((x / i).simplify()).equals(-(i * x));
      check((x / (-i)).simplify()).equals(i * x);
    });

    test('polynomial expansion with Gaussian numbers', () {
      final expr = (RationalNumber.one + i) * (RationalNumber.one - i);
      check(expr.expand().simplify()).equals(const RationalNumber(2));
    });

    test('canonical reconstruction: a + b * i', () {
      final c1 =
          (const RationalNumber(2) + const RationalNumber(3) * i) +
          (const RationalNumber(4) + const RationalNumber(5) * i);
      check(c1.simplify())
          .equals(const RationalNumber(6) + const RationalNumber(8) * i);

      final c2 =
          (const RationalNumber(2) + const RationalNumber(3) * i) -
          (const RationalNumber(4) + const RationalNumber(5) * i);
      check(c2.simplify())
          .equals(const RationalNumber(-2) - const RationalNumber(2) * i);
    });

    test(
      'canonical reconstruction: a + b * i with fractional and radical parts',
      () {
        // Fraction simplification: -1/2 + 2/4*i -> -1/2 + 1/2*i
        final cFrac =
            const RationalNumber(-1, 2) + (const RationalNumber(2, 4) * i);
        check(cFrac.simplify()).equals(
          const RationalNumber(-1, 2) + (const RationalNumber(1, 2) * i),
        );

        // Ordering: real terms first, imaginary part at the end
        const sqrt3 = Pow(RationalNumber(3), RationalNumber(1, 2));
        final cRadical1 =
            (const RationalNumber(1, 2) * i * sqrt3) -
            const RationalNumber(1, 2);
        check(cRadical1.simplify()).equals(
          const RationalNumber(-1, 2) +
              (const RationalNumber(1, 2) * (i * sqrt3)),
        );

        final cRadical2 =
            (-const RationalNumber(1, 2) * i * sqrt3) -
            const RationalNumber(1, 2);
        check(cRadical2.simplify()).equals(
          const RationalNumber(-1, 2) -
              (const RationalNumber(1, 2) * (i * sqrt3)),
        );

        // Deterministic 4-tier ordering: variables < rational constants < transcendental constants < imaginary unit
        final mixed1 = ConstantNumber.pi + const RationalNumber(1);
        check(mixed1.simplify())
            .equals(const RationalNumber(1) + ConstantNumber.pi);

        final mixed2 =
            i +
            ConstantNumber.pi +
            ConstantNumber.e +
            const RationalNumber(1) +
            x;
        check(mixed2.simplify()).equals(
          x +
              const RationalNumber(1) +
              ConstantNumber.e +
              ConstantNumber.pi +
              i,
        );

        final mixed3 = ConstantNumber.pi + i;
        check(mixed3.simplify()).equals(ConstantNumber.pi + i);

        final mixed4 = ConstantNumber.e + i;
        check(mixed4.simplify()).equals(ConstantNumber.e + i);
      },
    );
  });

  group('Cyclic power simplification', () {
    test('positive integer exponents modulo 4', () {
      check(i.pow(0).simplify()).equals(RationalNumber.one);
      check(i.pow(1).simplify()).equals(i);
      check(i.pow(2).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(3).simplify()).equals(-i);
      check(i.pow(4).simplify()).equals(RationalNumber.one);
      check(i.pow(5).simplify()).equals(i);
      check(i.pow(6).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(7).simplify()).equals(-i);
      check(i.pow(8).simplify()).equals(RationalNumber.one);
      check(i.pow(17).simplify()).equals(i);
      check(i.pow(42).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(99).simplify()).equals(-i);
      check(i.pow(100).simplify()).equals(RationalNumber.one);
    });

    test('negative integer exponents modulo 4', () {
      check(i.pow(-1).simplify()).equals(-i);
      check(i.pow(-2).simplify()).equals(RationalNumber.negativeOne);
      check(i.pow(-3).simplify()).equals(i);
      check(i.pow(-4).simplify()).equals(RationalNumber.one);
      check(i.pow(-5).simplify()).equals(-i);
      check(i.pow(-100).simplify()).equals(RationalNumber.one);
    });

    test('powers of -i modulo 4', () {
      check((-i).pow(0).simplify()).equals(RationalNumber.one);
      check((-i).pow(1).simplify()).equals(-i);
      check((-i).pow(2).simplify()).equals(RationalNumber.negativeOne);
      check((-i).pow(3).simplify()).equals(i);
      check((-i).pow(4).simplify()).equals(RationalNumber.one);
    });

    test('powers of scaled imaginary terms', () {
      final expr = (const RationalNumber(2) * i).pow(2);
      check(expr.simplify()).equals(const RationalNumber(-4));
    });
  });

  group('Complex evaluation with evaluateComplex', () {
    test('evaluates real expressions into Complex domain', () {
      final expr = const RationalNumber(3) + const RationalNumber(4);
      check(expr.evaluateComplex()).equals(const Complex(7.0, 0.0));
    });

    test('evaluates i and complex expressions directly', () {
      check(i.evaluateComplex()).equals(Complex.i);
      check(
        (const RationalNumber(2) + const RationalNumber(3) * i)
            .evaluateComplex(),
      ).equals(const Complex(2, 3));
    });

    test('evaluates expressions with variables bound to Complex values', () {
      final expr = x * x + 1;
      check(expr.evaluateComplex({'x': Complex.i})).equals(Complex.zero);

      final val = expr.evaluateComplex({'x': const Complex(1.0, 2.0)});
      check(val).equals(const Complex(-2.0, 4.0));
    });

    test('evaluates zero base complex powers', () {
      const x = Variable('x');
      check(x.pow(2).evaluateComplex({'x': Complex.zero})).equals(Complex.zero);
      check(x.pow(0).evaluateComplex({'x': Complex.zero})).equals(Complex.one);
      check((x.pow(2) + 1).evaluateComplex({'x': Complex.zero}))
          .equals(Complex.one);
      check((x * x + 1).toComplexFunction1D('x')(Complex.zero))
          .equals(Complex.one);
      check((x * x).compileComplex()({'x': Complex.zero})).equals(Complex.zero);
    });

    test("verifies Euler's identity: exp(i * pi) + 1 = 0", () {
      final euler = Exp(i * ConstantNumber.pi) + RationalNumber.one;
      final result = euler.evaluateComplex();
      check(result.abs()).isLessThan(1e-12);
    });

    test('evaluates complex trigonometric and hyperbolic relationships', () {
      final cosIx = Cos(i * RationalNumber.one).evaluateComplex();
      final cosh1 = const Cosh(RationalNumber.one).evaluateComplex();
      check((cosIx - cosh1).abs()).isLessThan(1e-12);

      final sinIx = Sin(i * RationalNumber.one).evaluateComplex();
      check((sinIx - Complex.i.sin()).abs()).isLessThan(1e-12);

      final tanVal = const Tan(i).evaluateComplex();
      final expectedTanh = (math.exp(2.0) - 1.0) / (math.exp(2.0) + 1.0);
      check((tanVal.b - expectedTanh).abs()).isLessThan(1e-12);

      final sinhVal = const Sinh(i).evaluateComplex();
      check((sinhVal.b - math.sin(1.0)).abs()).isLessThan(1e-12);

      final coshVal = const Cosh(i).evaluateComplex();
      check((coshVal.a - math.cos(1.0)).abs()).isLessThan(1e-12);

      final tanhVal = const Tanh(i).evaluateComplex();
      check((tanhVal.b - math.tan(1.0)).abs()).isLessThan(1e-12);
    });

    test('evaluates inverse trigonometric and hyperbolic functions', () {
      final asinVal = const Asin(RationalNumber.zero).evaluateComplex();
      check(asinVal.abs()).isLessThan(1e-12);

      final acosVal = const Acos(RationalNumber.zero).evaluateComplex();
      check((acosVal.a - math.pi / 2).abs()).isLessThan(1e-12);

      final atanVal = const Atan(RationalNumber.one).evaluateComplex();
      check((atanVal.a - math.pi / 4).abs()).isLessThan(1e-12);
    });

    test('evaluates square root of negative numbers', () {
      final sqrtNegOne = RationalNumber.negativeOne.pow(
        const RationalNumber(1, 2),
      );
      check((sqrtNegOne.evaluateComplex() - Complex.i).abs()).isLessThan(1e-12);

      final sqrtNegFour = const RationalNumber(-4)
          .pow(const RationalNumber(1, 2));
      check((sqrtNegFour.evaluateComplex() - const Complex(0.0, 2.0)).abs())
          .isLessThan(1e-12);
    });

    test('evaluates logarithms of negative numbers and arbitrary base', () {
      final lnNegOne = const Ln(RationalNumber.negativeOne).evaluateComplex();
      check((lnNegOne - const Complex(0.0, math.pi)).abs()).isLessThan(1e-12);

      final logVal = const Log(
        RationalNumber(10),
        RationalNumber(100),
      ).evaluateComplex();
      check((logVal.a - 2.0).abs()).isLessThan(1e-12);
    });

    test('evaluates absolute value of complex numbers', () {
      final absVal = Abs(const RationalNumber(3) + const RationalNumber(4) * i)
          .evaluateComplex();
      check(absVal).equals(const Complex(5.0, 0.0));
    });

    test('throws ArgumentError on missing variable', () {
      check(() => x.evaluateComplex()).throws<ArgumentError>();
    });

    test('real evaluate() throws on imaginary expressions', () {
      final expr = x + i;
      check(() => expr.evaluate({'x': 1.0})).throws<UnsupportedError>();
    });
  });

  group('High-speed numerical JIT compilation', () {
    test('compiles univariate expression to Complex closure', () {
      final fn = (x * x + 1).toComplexFunction1D('x');
      check(fn(Complex.i).abs()).isLessThan(1e-12);
      check((fn(const Complex(1.0, 2.0)) - const Complex(-2.0, 4.0)).abs())
          .isLessThan(1e-12);
    });

    test('compiles transcendental function with i', () {
      final fn = Exp(i * x).toComplexFunction1D('x');
      final valPi = fn(const Complex(math.pi));
      check((valPi - const Complex(-1.0, 0.0)).abs()).isLessThan(1e-12);
    });

    test('compiles rational and algebraic fractions', () {
      final fn = ((x + 1) / (x - 1)).toComplexFunction1D('x');
      final valI = fn(Complex.i);
      check((valI - const Complex(0.0, -1.0)).abs()).isLessThan(1e-12);
    });

    test('compiles dictionary-based multi-variable complex closure', () {
      final fn = (x + y).compileComplex();
      final result = fn({'x': const Complex(1, 2), 'y': const Complex(3, 4)});
      check(result).equals(const Complex(4, 6));

      check(() => fn({'x': const Complex(1, 2)})).throws<ArgumentError>();
    });

    test('real compilers reject expressions with imaginary constant i', () {
      final expr = x + i;
      check(() => expr.toFunction1D('x')).throws<UnsupportedError>();
      check(() => expr.compile(['x'])).throws<UnsupportedError>();
      check(() => expr.toVectorFunction(['x'])).throws<UnsupportedError>();
      check(() => expr.compileTensorKernel(['x'])).throws<UnsupportedError>();
    });
  });

  group('Structural order with complex numbers', () {
    test('compares ConstantNumber without crashing', () {
      check(compareStructural(i, ConstantNumber.pi) != 0).isTrue();
      check(compareStructural(i, i)).equals(0);
      check(compareStructural(ConstantNumber.pi, i) != 0).isTrue();
    });

    test('compares complex expressions', () {
      final c1 = const RationalNumber(1) + const RationalNumber(2) * i;
      final c2 = const RationalNumber(1) + const RationalNumber(2) * i;
      final c3 = const RationalNumber(1) + const RationalNumber(3) * i;
      final c4 = const RationalNumber(2) + const RationalNumber(1) * i;

      check(compareStructural(c1, c2)).equals(0);
      check(compareStructural(c1, c3)).isLessThan(0);
      check(compareStructural(c3, c1)).isGreaterThan(0);
      check(compareStructural(c1, c4)).isLessThan(0);
    });

    test('compares powers with complex exponents without crashing', () {
      final p1 = x.pow(i);
      final p2 = x.pow(2);
      check(compareStructural(p1, p2) != 0).isTrue();
    });
  });

  group('Textualization: String, LaTeX, MathML', () {
    test('String formatting for ConstantNumber.i and complex expressions', () {
      check(formatExpr(i)).equals('i');
      check(formatExpr(-i)).equals('-i');
      check(formatExpr(const RationalNumber(2) * i)).equals('2 * i');
      check(formatExpr(const RationalNumber(2) + const RationalNumber(3) * i))
          .equals('2 + 3 * i');
      check(formatExpr(const RationalNumber(3) + const RationalNumber(4) * i))
          .equals('3 + 4 * i');
      check(formatExpr(const RationalNumber(3) - const RationalNumber(4) * i))
          .equals('3 - 4 * i');

      final c = const RationalNumber(3) + const RationalNumber(4) * i;
      check(formatExpr(c * x)).equals('(3 + 4 * i) * x');
      check(formatExpr(c.pow(2))).equals('(3 + 4 * i) ^ 2');
    });

    test('LaTeX serialization', () {
      check(i.toLatex()).equals('i');
      check((-i).toLatex()).equals('-i');
      check((const RationalNumber(2) * i).toLatex()).equals(r'2 \cdot i');
      check((const RationalNumber(2) + const RationalNumber(3) * i).toLatex())
          .equals(r'2 + 3 \cdot i');
      check((const RationalNumber(3) + const RationalNumber(4) * i).toLatex())
          .equals(r'3 + 4 \cdot i');
      check((const RationalNumber(3) - const RationalNumber(4) * i).toLatex())
          .equals(r'3 - 4 \cdot i');
      check(
        ((const RationalNumber(3) + const RationalNumber(4) * i) * x).toLatex(),
      ).equals(r'(3 + 4 \cdot i) \cdot x');
    });

    test('MathML serialization', () {
      check(i.toMathMl()).equals('<math><mi>i</mi></math>');
      check((-i).toMathMl())
          .equals('<math><mrow><mo>-</mo><mi>i</mi></mrow></math>');
      check((const RationalNumber(3) + const RationalNumber(4) * i).toMathMl())
          .equals(
            '<math><mrow><mn>3</mn><mo>+</mo><mrow><mn>4</mn><mo>&#x22c5;</mo><mi>i</mi></mrow></mrow></math>',
          );
    });
  });

  group('Parser recognition and round-trips', () {
    test('parses i in standard casing', () {
      check(Expr.parse('i')).equals(ConstantNumber.i);
      check(Expr.parse('I')).equals(ConstantNumber.i);
    });

    test('parses arithmetic and Gaussian expressions', () {
      check(Expr.parse('2 + 3 * i')).equals(
        const Add(RationalNumber(2), Mul(RationalNumber(3), ConstantNumber.i)),
      );
      check(Expr.parse('1/2 + 3/4 * i')).equals(
        const Add(
          Div(RationalNumber(1), RationalNumber(2)),
          Mul(Div(RationalNumber(3), RationalNumber(4)), ConstantNumber.i),
        ),
      );
      check(Expr.parse('i ^ 2'))
          .equals(const Pow(ConstantNumber.i, RationalNumber(2)));
      check(Expr.parse('exp(i * pi)'))
          .equals(const Exp(Mul(ConstantNumber.i, ConstantNumber.pi)));
      check(Expr.parse('-i')).equals(const Neg(ConstantNumber.i));
    });

    test('distinguishes i from multi-letter identifier prefixes', () {
      check(Expr.parse('item')).equals(const Variable('item'));
      check(Expr.parse('i1')).equals(const Variable('i1'));
      check(Expr.parse('imag')).equals(const Variable('imag'));
    });

    test('round-trip parsing and evaluation', () {
      final parsed = Expr.parse('2 + 3 * i');
      check(parsed.evaluateComplex()).equals(const Complex(2.0, 3.0));

      final euler = Expr.parse('exp(i * pi) + 1');
      check(euler.evaluateComplex().abs()).isLessThan(1e-12);
    });
  });
}
