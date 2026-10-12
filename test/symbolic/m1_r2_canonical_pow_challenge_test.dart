import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Challenger M1: Stress test Expr.parse and Expr.tryParse', () {
    const x = Variable('x');
    const y = Variable('y');

    test('nested radicals and composite powers', () {
      // sqrt(sqrt(x))
      final sqrtSqrtX = Expr.parse('sqrt(sqrt(x))');
      check(
        sqrtSqrtX,
      ).equals(const Pow(Pow(x, RationalNumber(1, 2)), RationalNumber(1, 2)));
      check(Expr.tryParse('sqrt(sqrt(x))')).equals(sqrtSqrtX);

      // sqrt(pow(x, 2))
      final sqrtPowX2 = Expr.parse('sqrt(pow(x, 2))');
      check(sqrtPowX2)
          .equals(const Pow(Pow(x, RationalNumber(2)), RationalNumber(1, 2)));
      check(Expr.tryParse('sqrt(pow(x, 2))')).equals(sqrtPowX2);

      // pow(sqrt(x), 2)
      final powSqrtX2 = Expr.parse('pow(sqrt(x), 2)');
      check(powSqrtX2)
          .equals(const Pow(Pow(x, RationalNumber(1, 2)), RationalNumber(2)));

      // Deeply nested radicals: sqrt(sqrt(sqrt(16)))
      final deepSqrt = Expr.parse('sqrt(sqrt(sqrt(16)))');
      check(deepSqrt.evaluate({})).isCloseTo(math.pow(16.0, 1.0 / 8.0), 1e-12);

      // Nested powers: pow(pow(x, 2), 3)
      final nestedPow = Expr.parse('pow(pow(x, 2), 3)');
      check(nestedPow)
          .equals(const Pow(Pow(x, RationalNumber(2)), RationalNumber(3)));
      check(nestedPow.evaluate({'x': 2.0})).equals(64.0);

      // Complex composite radical: sqrt(1 / (1 - x ^ 2))
      final compositeRadical = Expr.parse('sqrt(1 / (1 - x ^ 2))');
      check(compositeRadical).equals(
        const Pow(
          Div(
            RationalNumber(1),
            Sub(RationalNumber(1), Pow(x, RationalNumber(2))),
          ),
          RationalNumber(1, 2),
        ),
      );
    });

    test('multi-argument expressions: pow, root, log', () {
      // pow(x, y)
      check(Expr.parse('pow(x, y)')).equals(const Pow(x, y));
      check(Expr.tryParse('pow(x, y)')).equals(const Pow(x, y));

      // pow(x + 1, y - 1)
      check(
        Expr.parse('pow(x + 1, y - 1)'),
      ).equals(const Pow(Add(x, RationalNumber(1)), Sub(y, RationalNumber(1))));

      // pow(sin(x), cos(y))
      check(Expr.parse('pow(sin(x), cos(y))'))
          .equals(const Pow(Sin(x), Cos(y)));

      // root(3, x) -> Pow(x, 1/3)
      final root3 = Expr.parse('root(3, x)');
      check(root3)
          .equals(const Pow(x, Div(RationalNumber.one, RationalNumber(3))));
      check(root3.evaluate({'x': 27.0})).isCloseTo(3.0, 1e-9);

      // log(2, x)
      final log2 = Expr.parse('log(2, x)');
      check(log2).equals(const Log(RationalNumber(2), x));
      check(log2.evaluate({'x': 8.0})).isCloseTo(3.0, 1e-9);
    });

    test('negative powers and fractional exponents', () {
      // pow(x, -2) -> Pow(x, Neg(RationalNumber(2)))
      final powNeg2 = Expr.parse('pow(x, -2)');
      check(powNeg2).equals(const Pow(x, Neg(RationalNumber(2))));
      check(powNeg2.evaluate({'x': 2.0})).equals(0.25);

      // Parenthesized negative power: x ^ (-2)
      final xPowNeg2 = Expr.parse('x ^ (-2)');
      check(xPowNeg2).equals(const Pow(x, Neg(RationalNumber(2))));
      check(xPowNeg2.evaluate({'x': 4.0})).equals(1.0 / 16.0);

      // Unparenthesized x ^ -2 fails due to operator precedence (^ binds tighter than unary -)
      check(() => Expr.parse('x ^ -2')).throws<FormatException>();
      check(Expr.tryParse('x ^ -2')).isNull();

      // sqrt(x ^ (-2))
      final sqrtPowNeg = Expr.parse('sqrt(x ^ (-2))');
      check(
        sqrtPowNeg,
      ).equals(const Pow(Pow(x, Neg(RationalNumber(2))), RationalNumber(1, 2)));
      check(sqrtPowNeg.evaluate({'x': 4.0})).equals(0.25);

      // pow(x, -1/2) -> pow(x, -(1/2))
      final powNegFrac = Expr.parse('pow(x, -1 / 2)');
      check(powNegFrac)
          .equals(const Pow(x, Div(Neg(RationalNumber(1)), RationalNumber(2))));
      check(powNegFrac.evaluate({'x': 4.0})).equals(0.5);
    });

    test('whitespace variations in function calls', () {
      check(Expr.parse('  sqrt  (  x  )  '))
          .equals(const Pow(x, RationalNumber(1, 2)));
      check(Expr.parse('pow  (  x  ,  y  )  ')).equals(const Pow(x, y));
      check(Expr.parse('sqrt ( pow ( x , 2 ) )'))
          .equals(const Pow(Pow(x, RationalNumber(2)), RationalNumber(1, 2)));
      check(Expr.parse('pow( x , - 2 )'))
          .equals(const Pow(x, Neg(RationalNumber(2))));
    });

    test(
      'malformed syntax throws FormatException or returns null in tryParse',
      () {
        // Arity mismatch for sqrt
        check(() => Expr.parse('sqrt(x, y)')).throws<FormatException>();
        check(Expr.tryParse('sqrt(x, y)')).isNull();
        check(() => Expr.parse('sqrt(x, y, z)')).throws<FormatException>();
        check(Expr.tryParse('sqrt(x, y, z)')).isNull();

        // Arity mismatch for pow
        check(() => Expr.parse('pow(x)')).throws<FormatException>();
        check(Expr.tryParse('pow(x)')).isNull();
        check(() => Expr.parse('pow(x, y, z)')).throws<FormatException>();
        check(Expr.tryParse('pow(x, y, z)')).isNull();

        // Missing closing parenthesis
        check(() => Expr.parse('sqrt(x')).throws<FormatException>();
        check(Expr.tryParse('sqrt(x')).isNull();
        check(() => Expr.parse('pow(x, y')).throws<FormatException>();
        check(Expr.tryParse('pow(x, y')).isNull();

        // Unmatched closing parenthesis
        check(() => Expr.parse('sqrt)x(')).throws<FormatException>();
        check(Expr.tryParse('sqrt)x(')).isNull();

        // Empty arguments
        check(() => Expr.parse('pow(,)')).throws<FormatException>();
        check(Expr.tryParse('pow(,)')).isNull();
        check(() => Expr.parse('sqrt(,)')).throws<FormatException>();
        check(Expr.tryParse('sqrt(,)')).isNull();
        check(() => Expr.parse('pow(x, )')).throws<FormatException>();
        check(Expr.tryParse('pow(x, )')).isNull();
        check(() => Expr.parse('pow(, y)')).throws<FormatException>();
        check(Expr.tryParse('pow(, y)')).isNull();

        // Zero-arg call behavior:
        // Due to parser design, name() matches empty argument list and falls back to Variable(name)
        check(Expr.parse('sqrt()')).equals(const Variable('sqrt'));
        check(Expr.parse('pow()')).equals(const Variable('pow'));
      },
    );
  });

  group('Challenger M1: Evaluation & JIT compilation verification', () {
    const x = Variable('x');

    test('direct evaluate() on square roots and powers', () {
      // sqrt(4) = 2
      const sqrt4 = Pow(RationalNumber(4), RationalNumber(1, 2));
      check(sqrt4.evaluate({})).equals(2.0);

      // sqrt(0) = 0
      const sqrt0 = Pow(RationalNumber(0), RationalNumber(1, 2));
      check(sqrt0.evaluate({})).equals(0.0);

      // sqrt(-1) = NaN
      const sqrtNeg = Pow(RationalNumber(-1), RationalNumber(1, 2));
      check(sqrtNeg.evaluate({}).isNaN).isTrue();

      // sqrt(x^2) for positive and negative numbers
      const sqrtX2 = Pow(Pow(x, RationalNumber(2)), RationalNumber(1, 2));
      check(sqrtX2.evaluate({'x': 5.0})).equals(5.0);
      check(sqrtX2.evaluate({'x': -5.0})).equals(5.0);

      // pow(x, -2) for x = 4
      const xPowNeg2 = Pow(x, RationalNumber(-2));
      check(xPowNeg2.evaluate({'x': 4.0})).equals(0.0625);

      // pow(0, -1) = Infinity
      const div0 = Pow(RationalNumber(0), RationalNumber(-1));
      check(div0.evaluate({})).equals(double.infinity);
    });

    test('toFunction1D JIT compilation', () {
      final fSqrt = Expr.parse('sqrt(x)').toFunction1D('x');
      check(fSqrt(0.0)).equals(0.0);
      check(fSqrt(1.0)).equals(1.0);
      check(fSqrt(4.0)).equals(2.0);
      check(fSqrt(9.0)).equals(3.0);
      check(fSqrt(16.0)).equals(4.0);
      check(fSqrt(-1.0).isNaN).isTrue();

      final fSqrtSqrt = Expr.parse('sqrt(sqrt(x))').toFunction1D('x');
      check(fSqrtSqrt(16.0)).equals(2.0);
      check(fSqrtSqrt(81.0)).equals(3.0);

      final fSqrtX2 = Expr.parse('sqrt(pow(x, 2))').toFunction1D('x');
      check(fSqrtX2(5.0)).equals(5.0);
      check(fSqrtX2(-5.0)).equals(5.0);

      final fPowNeg = Expr.parse('pow(x, -2)').toFunction1D('x');
      check(fPowNeg(2.0)).equals(0.25);
      check(fPowNeg(4.0)).equals(0.0625);
    });

    test('multi-variable compile() and toVectorFunction()', () {
      final fPos = Expr.parse('sqrt(pow(x, 2) + pow(y, 2))')
          .compile(['x', 'y']);
      check(fPos([3.0, 4.0])).equals(5.0);
      check(fPos([5.0, 12.0])).equals(13.0);
      check(fPos([-3.0, -4.0])).equals(5.0);

      final fVec = Expr.parse('pow(x, y)').toVectorFunction(['x', 'y']);
      check(fVec(Vector.fromList([2.0, 3.0]))).equals(8.0);
      check(fVec(Vector.fromList([3.0, 2.0]))).equals(9.0);
      check(fVec(Vector.fromList([4.0, 0.5]))).equals(2.0);
    });

    test('compileTensorKernel() zero-allocation execution and accuracy', () {
      final kernelSqrt = Expr.parse('sqrt(x)').compileTensorKernel(['x']);
      final input = Float64List.fromList([0.0, 1.0, 4.0, 9.0, 16.0, 25.0]);
      final output = Float64List(6);
      kernelSqrt([input], output);

      check(output[0]).equals(0.0);
      check(output[1]).equals(1.0);
      check(output[2]).equals(2.0);
      check(output[3]).equals(3.0);
      check(output[4]).equals(4.0);
      check(output[5]).equals(5.0);

      // Multi-input kernel: pow(x, y)
      final kernelPow = Expr.parse('pow(x, y)').compileTensorKernel(['x', 'y']);
      final inX = Float64List.fromList([2.0, 3.0, 4.0]);
      final inY = Float64List.fromList([3.0, 2.0, 0.5]);
      final outPow = Float64List(3);
      kernelPow([inX, inY], outPow);

      check(outPow[0]).equals(8.0);
      check(outPow[1]).equals(9.0);
      check(outPow[2]).equals(2.0);

      // Stress kernel: nested sqrt(pow(x, 2))
      final kernelNested = Expr.parse('sqrt(pow(x, 2))')
          .compileTensorKernel(['x']);
      final inNeg = Float64List.fromList([-5.0, -3.0, 0.0, 2.0, 4.0]);
      final outNested = Float64List(5);
      kernelNested([inNeg], outNested);

      check(outNested[0]).equals(5.0);
      check(outNested[1]).equals(3.0);
      check(outNested[2]).equals(0.0);
      check(outNested[3]).equals(2.0);
      check(outNested[4]).equals(4.0);
    });
  });

  group(
    'Challenger M1: Confirm Sqrt absence and Pow canonical equivalence',
    () {
      const x = Variable('x');

      test('Pow(base, RationalNumber(1, 2)) canonical properties', () {
        const pow1 = Pow(x, RationalNumber(1, 2));
        const pow2 = Pow(x, RationalNumber(1, 2));
        const powOther = Pow(x, RationalNumber(1, 3));

        // Structural equality & hashCode
        check(pow1 == pow2).isTrue();
        check(pow1.hashCode == pow2.hashCode).isTrue();
        check(pow1 == powOther).isFalse();

        // Free variables
        check(pow1.freeVariables).unorderedEquals({'x'});

        // Substitution
        final substituted = pow1.substitute('x', const RationalNumber(9));
        check(substituted)
            .equals(const Pow(RationalNumber(9), RationalNumber(1, 2)));
        check(substituted.evaluate({})).equals(3.0);

        // Calculus: derivative
        final deriv = pow1.derivative('x');
        // d/dx(x^(1/2)) = (1/2) * x^(-1/2)
        check(deriv.evaluate({'x': 4.0})).equals(0.25);

        // Calculus: integration
        final integral = pow1.integrate('x');
        // int(x^(1/2)) = (2/3) * x^(3/2)
        check(integral.evaluate({'x': 4.0})).isCloseTo(16.0 / 3.0, 1e-9);
      });

      test('Simplification behavior for canonical square roots', () {
        // Constant square root
        check(const Pow(RationalNumber(4), RationalNumber(1, 2)).simplify())
            .equals(const RationalNumber(2));
        check(const Pow(RationalNumber(9, 16), RationalNumber(1, 2)).simplify())
            .equals(const RationalNumber(3, 4));

        // Involution: (x^2)^(1/2) -> |x|
        check(
          const Pow(Pow(x, RationalNumber(2)), RationalNumber(1, 2)).simplify(),
        ).equals(const Abs(x));

        // (sqrt(x))^2 -> x
        check(
          const Pow(Pow(x, RationalNumber(1, 2)), RationalNumber(2)).simplify(),
        ).equals(x);

        // sqrt(x) * sqrt(x) -> x
        check(
          const Mul(
            Pow(x, RationalNumber(1, 2)),
            Pow(x, RationalNumber(1, 2)),
          ).simplify(),
        ).equals(x);

        // sqrt(x) / sqrt(x) -> 1
        check(
          const Div(
            Pow(x, RationalNumber(1, 2)),
            Pow(x, RationalNumber(1, 2)),
          ).simplify(),
        ).equals(RationalNumber.one);
      });

      test('Textualization of canonical Pow', () {
        const sqrtX = Pow(x, RationalNumber(1, 2));
        const sqrtXPlus1 = Pow(Add(x, RationalNumber(1)), RationalNumber(1, 2));
        const root3X = Pow(x, RationalNumber(1, 3));

        // MathML
        check(sqrtX.toMathMl())
            .equals('<math><msqrt><mrow><mi>x</mi></mrow></msqrt></math>');
        check(sqrtXPlus1.toMathMl()).equals(
          '<math><msqrt><mrow><mi>x</mi><mo>+</mo><mn>1</mn></mrow></msqrt></math>',
        );
        check(root3X.toMathMl()).equals(
          '<math><mroot><mrow><mi>x</mi></mrow><mrow><mn>3</mn></mrow></mroot></math>',
        );

        // Nested MathML radical: sqrt(sqrt(x))
        const sqrtSqrtX = Pow(
          Pow(x, RationalNumber(1, 2)),
          RationalNumber(1, 2),
        );
        check(sqrtSqrtX.toMathMl()).equals(
          '<math><msqrt><mrow><msqrt><mrow><mi>x</mi></mrow></msqrt></mrow></msqrt></math>',
        );

        // LaTeX
        check(sqrtX.toLatex()).equals(r'\sqrt{x}');
        check(sqrtXPlus1.toLatex()).equals(r'\sqrt{x + 1}');

        // String format
        check(sqrtX.toString()).equals('sqrt(x)');
        check(sqrtXPlus1.toString()).equals('sqrt(x + 1)');
      });

      test('Higher-order calculus derivatives of canonical Pow', () {
        const sqrtX = Pow(x, RationalNumber(1, 2));

        // 1st derivative: (1/2) * x^(-1/2)
        final d1 = sqrtX.derivative('x', order: 1);
        check(d1.evaluate({'x': 4.0})).equals(0.25);

        // 2nd derivative: -(1/4) * x^(-3/2)
        final d2 = sqrtX.derivative('x', order: 2);
        check(d2.evaluate({'x': 4.0})).equals(-0.03125);

        // 3rd derivative: (3/8) * x^(-5/2)
        final d3 = sqrtX.derivative('x', order: 3);
        check(d3.evaluate({'x': 4.0})).equals(3.0 / 256.0);
      });

      test('Integration of canonical radicals and quotient inverse trigonometric forms', () {
        const sqrtX = Pow(x, RationalNumber(1, 2));

        // int(x^(1/2)) = (2/3) * x^(3/2)
        final antiSqrt = sqrtX.integrate('x');
        check(antiSqrt.evaluate({'x': 4.0})).isCloseTo(16.0 / 3.0, 1e-9);

        // Definite integral of sqrt(x) from 0 to 4 is 16/3
        final defInt = sqrtX.integrate('x', from: 0, to: 4);
        check(defInt.evaluate(const {})).isCloseTo(16.0 / 3.0, 1e-9);

        // int(1 / sqrt(x)) = 2 * sqrt(x)
        const invSqrt = Pow(x, RationalNumber(-1, 2));
        final antiInvSqrt = invSqrt.integrate('x');
        check(antiInvSqrt.evaluate({'x': 4.0})).equals(4.0);

        // int(1 / sqrt(1 - x^2)) = asin(x)
        const asinIntegrand = Div(
          RationalNumber.one,
          Pow(
            Sub(RationalNumber.one, Pow(x, RationalNumber(2))),
            RationalNumber(1, 2),
          ),
        );
        final antiAsin = asinIntegrand.integrate('x');
        check(antiAsin).equals(const Asin(x));
      });

      test('Solver behavior on canonical radical equations', () {
        // sqrt(x) - 3 = 0 => x = 9
        const eq1 = Sub(Pow(x, RationalNumber(1, 2)), RationalNumber(3));
        final roots1 = eq1.solve('x');
        check(roots1.length).equals(1);
        check(roots1[0].evaluate({})).equals(9.0);

        // sqrt(x) + 2 = 0 => no real roots (even root cannot equal negative)
        const eq2 = Add(Pow(x, RationalNumber(1, 2)), RationalNumber(2));
        final roots2 = eq2.solve('x');
        check(roots2).isEmpty();
      });

      test('Tensor kernel large buffer throughput and edge conditions', () {
        final kernel = Expr.parse('sqrt(x) + pow(x, 2)')
            .compileTensorKernel(['x']);
        const size = 10000;
        final input = Float64List(size);
        for (var i = 0; i < size; i++) {
          input[i] = (i % 100).toDouble();
        }
        final output = Float64List(size);
        kernel([input], output);

        for (var i = 0; i < 100; i++) {
          final expected = math.sqrt(i.toDouble()) + (i * i).toDouble();
          check(output[i]).isCloseTo(expected, 1e-12);
        }

        // Zero-length buffer handling
        final emptyIn = Float64List(0);
        final emptyOut = Float64List(0);
        kernel([emptyIn], emptyOut);
        check(emptyOut.length).equals(0);
      });
    },
  );
}
