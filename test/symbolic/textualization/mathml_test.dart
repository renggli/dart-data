import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('MathML - Atomic Expressions', () {
    test('variables', () {
      check(const Variable('x').toMathMl()).equals('<math><mi>x</mi></math>');
      check(const Variable('theta').toMathMl())
          .equals('<math><mi>theta</mi></math>');
      check(const Variable('a&b').toMathMl())
          .equals('<math><mi>a&amp;b</mi></math>');
    });

    test('numbers', () {
      check(const RationalNumber(0).toMathMl())
          .equals('<math><mn>0</mn></math>');
      check(const RationalNumber(42).toMathMl())
          .equals('<math><mn>42</mn></math>');
      check(const RationalNumber(-7).toMathMl())
          .equals('<math><mn>-7</mn></math>');
      check(const RationalNumber(1, 2).toMathMl())
          .equals('<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>');
      check(const RealNumber(3.14).toMathMl())
          .equals('<math><mn>3.14</mn></math>');
      check(ConstantNumber.pi.toMathMl()).equals('<math><mi>π</mi></math>');
      check(ConstantNumber.e.toMathMl()).equals('<math><mi>e</mi></math>');
    });

    test('display and root configuration', () {
      const x = Variable('x');
      check(x.toMathMl(display: true))
          .equals('<math display="block"><mi>x</mi></math>');
      check(x.toMathMl(root: false)).equals('<mi>x</mi>');
    });
  });

  group('MathML - Arithmetic Operations', () {
    const x = Variable('x');
    const y = Variable('y');
    const z = Variable('z');

    test('addition', () {
      check((x + y).toMathMl())
          .equals('<math><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow></math>');
      check((x + y + z).toMathMl()).equals(
        '<math><mrow><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>+</mo><mi>z</mi></mrow></math>',
      );
    });

    test('subtraction and right associativity parentheses', () {
      check((x - y).toMathMl())
          .equals('<math><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow></math>');
      check((x - (y + z)).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>-</mo><mrow><mo>(</mo><mrow><mi>y</mi><mo>+</mo><mi>z</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check((x - (y - z)).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>-</mo><mrow><mo>(</mo><mrow><mi>y</mi><mo>-</mo><mi>z</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check(((x - y) - z).toMathMl()).equals(
        '<math><mrow><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow><mo>-</mo><mi>z</mi></mrow></math>',
      );
    });

    test('multiplication and precedence parentheses', () {
      check((x * y).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>&#x22c5;</mo><mi>y</mi></mrow></math>',
      );
      check((const RationalNumber(12) * x).toMathMl())
          .equals('<math><mrow><mn>12</mn><mi>x</mi></mrow></math>');
      check((const RationalNumber(12) * x * y).toMathMl()).equals(
        '<math><mrow><mrow><mn>12</mn><mi>x</mi></mrow><mo>&#x22c5;</mo><mi>y</mi></mrow></math>',
      );
      check(const Mul(RationalNumber(2), RationalNumber(3)).toMathMl()).equals(
        '<math><mrow><mn>2</mn><mo>&#x22c5;</mo><mn>3</mn></mrow></math>',
      );
      check(
        (const RationalNumber(2) * const RationalNumber(3).pow(x)).toMathMl(),
      ).equals(
        '<math><mrow><mn>2</mn><mo>&#x22c5;</mo><msup><mn>3</mn><mi>x</mi></msup></mrow></math>',
      );
      check(
        (const RationalNumber(2) *
                const RationalNumber(3).pow(const RationalNumber(1, 2)))
            .toMathMl(),
      ).equals(
        '<math><mrow><mn>2</mn><msqrt><mrow><mn>3</mn></mrow></msqrt></mrow></math>',
      );
      check(((x + y) * z).toMathMl()).equals(
        '<math><mrow><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow><mo>&#x22c5;</mo><mi>z</mi></mrow></math>',
      );
      check((x * (y + z)).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>&#x22c5;</mo><mrow><mo>(</mo><mrow><mi>y</mi><mo>+</mo><mi>z</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
    });

    test('multiplication with negative fraction does not add unnecessary parentheses on left', () {
      const halfNeg = RationalNumber(-1, 2);
      check((halfNeg * x).toMathMl()).equals(
        '<math><mrow><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow><mi>x</mi></mrow></math>',
      );
      check((x * halfNeg).toMathMl()).equals(
        '<math><mrow><mi>x</mi><mo>&#x22c5;</mo><mrow><mo>(</mo><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow><mo>)</mo></mrow></mrow></math>',
      );

      const sqrt3 = Pow(RationalNumber(3), RationalNumber(1, 2));
      final complexRadical = halfNeg * (ConstantNumber.i * sqrt3);
      check(complexRadical.toMathMl()).equals(
        '<math><mrow><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow><mrow><mi>i</mi><mo>&#x22c5;</mo><msqrt><mrow><mn>3</mn></mrow></msqrt></mrow></mrow></math>',
      );

      check(Expr.parse('1 + -2 * x ^ 3').toMathMl()).equals(
        '<math><mrow><mn>1</mn><mo>+</mo><mrow><mrow><mo>-</mo><mn>2</mn></mrow><msup><mi>x</mi><mn>3</mn></msup></mrow></mrow></math>',
      );
      check(
        Add(
          const RationalNumber(1),
          Mul(const RationalNumber(-2), x.pow(const RationalNumber(3))),
        ).toMathMl(),
      ).equals(
        '<math><mrow><mn>1</mn><mo>+</mo><mrow><mn>-2</mn><msup><mi>x</mi><mn>3</mn></msup></mrow></mrow></math>',
      );
    });

    test('piecewise formatting preserves non-breaking space after if', () {
      const pw = Piecewise([
        (LessThan(x, RationalNumber.zero), Neg(x)),
        (GreaterEqual(x, RationalNumber.zero), x),
      ]);
      check(pw.toMathMl()).contains('<mtext>if&#x00a0;</mtext>');
    });

    test('division formatting as mfrac', () {
      check((x / y).toMathMl())
          .equals('<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>');
      check(((x + y) / (x - y)).toMathMl()).equals(
        '<math><mfrac><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow></mfrac></math>',
      );
    });

    test('power formatting and base wrapping', () {
      check(x.pow(y).toMathMl())
          .equals('<math><msup><mi>x</mi><mi>y</mi></msup></math>');
      check((x + y).pow(z).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow><mi>z</mi></msup></math>',
      );
      check((x * y).pow(z).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mi>x</mi><mo>&#x22c5;</mo><mi>y</mi></mrow><mo>)</mo></mrow><mi>z</mi></msup></math>',
      );
      check((-x).pow(const RationalNumber(2)).toMathMl()).equals(
        '<math><msup><mrow><mo>(</mo><mrow><mo>-</mo><mi>x</mi></mrow><mo>)</mo></mrow><mn>2</mn></msup></math>',
      );
    });

    test('root formatting with msqrt and mroot', () {
      check(x.pow(const RationalNumber(1, 2)).toMathMl())
          .equals('<math><msqrt><mrow><mi>x</mi></mrow></msqrt></math>');
      check((x + y).pow(const RationalNumber(1, 2)).toMathMl()).equals(
        '<math><msqrt><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow></msqrt></math>',
      );
      check(x.pow(const RationalNumber(1, 3)).toMathMl()).equals(
        '<math><mroot><mrow><mi>x</mi></mrow><mrow><mn>3</mn></mrow></mroot></math>',
      );
      check(x.pow(const RationalNumber(1, 5)).toMathMl()).equals(
        '<math><mroot><mrow><mi>x</mi></mrow><mrow><mn>5</mn></mrow></mroot></math>',
      );
      check(x.pow(const RationalNumber(2, 3)).toMathMl()).equals(
        '<math><msup><mi>x</mi><mfrac><mn>2</mn><mn>3</mn></mfrac></msup></math>',
      );
      check(x.pow(const RationalNumber(-1, 2)).toMathMl()).equals(
        '<math><msup><mi>x</mi><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></msup></math>',
      );
    });

    test('unary negation', () {
      check((-x).toMathMl())
          .equals('<math><mrow><mo>-</mo><mi>x</mi></mrow></math>');
      check((-(x + y)).toMathMl()).equals(
        '<math><mrow><mo>-</mo><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
      check((-(x - y)).toMathMl()).equals(
        '<math><mrow><mo>-</mo><mrow><mo>(</mo><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow><mo>)</mo></mrow></mrow></math>',
      );
    });
  });

  group('MathML - Transcendentals', () {
    const x = Variable('x');
    const y = Variable('y');

    test('trigonometric and logarithm', () {
      check(const Sin(x).toMathMl()).equals(
        '<math><mrow><mi>sin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Cos(x).toMathMl()).equals(
        '<math><mrow><mi>cos</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Tan(x).toMathMl()).equals(
        '<math><mrow><mi>tan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Asin(x).toMathMl()).equals(
        '<math><mrow><mi>arcsin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Acos(x).toMathMl()).equals(
        '<math><mrow><mi>arccos</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Atan(x).toMathMl()).equals(
        '<math><mrow><mi>arctan</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Sinh(x).toMathMl()).equals(
        '<math><mrow><mi>sinh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Cosh(x).toMathMl()).equals(
        '<math><mrow><mi>cosh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Tanh(x).toMathMl()).equals(
        '<math><mrow><mi>tanh</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(const Abs(x).toMathMl())
          .equals('<math><mrow><mo>|</mo><mi>x</mi><mo>|</mo></mrow></math>');
      check(const Pow(x, RationalNumber(1, 2)).toMathMl())
          .equals('<math><msqrt><mrow><mi>x</mi></mrow></msqrt></math>');
      check(const Exp(x).toMathMl())
          .equals('<math><msup><mi>e</mi><mi>x</mi></msup></math>');
      check(const Ln(x).toMathMl()).equals(
        '<math><mrow><mi>ln</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>',
      );
      check(
        const Add(
          RationalNumber(3),
          Mul(RationalNumber(4), ConstantNumber.i),
        ).toMathMl(),
      ).equals(
        '<math><mrow><mn>3</mn><mo>+</mo><mrow><mn>4</mn><mi>i</mi></mrow></mrow></math>',
      );
      check(Sin(x + y).toMathMl()).equals(
        '<math><mrow><mi>sin</mi><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow></math>',
      );
    });

    test('composite calculus expressions', () {
      final f =
          (x.pow(const RationalNumber(2)) + const RationalNumber(1)) /
          (x - const RationalNumber(1));
      check(f.toMathMl()).equals(
        '<math><mfrac><mrow><msup><mi>x</mi><mn>2</mn></msup><mo>+</mo><mn>1</mn></mrow><mrow><mi>x</mi><mo>-</mo><mn>1</mn></mrow></mfrac></math>',
      );

      final g = Exp(-x.pow(const RationalNumber(2)));
      check(g.toMathMl()).equals(
        '<math><msup><mi>e</mi><mrow><mo>-</mo><msup><mi>x</mi><mn>2</mn></msup></mrow></msup></math>',
      );
    });
  });

  group('MathML - Square Roots (<msqrt>) Container Wrapping', () {
    const x = Variable('x');
    const y = Variable('y');
    const z = Variable('z');
    const w = Variable('w');

    test('atomic radicands wrap in <mrow>', () {
      final exprs = <Expr>[
        x.pow(const RationalNumber(1, 2)),
        const Variable('alpha_1').pow(const RationalNumber(1, 2)),
        const Variable('a&b').pow(const RationalNumber(1, 2)),
        const RationalNumber(0).pow(const RationalNumber(1, 2)),
        const RationalNumber(42).pow(const RationalNumber(1, 2)),
        const RationalNumber(-7).pow(const RationalNumber(1, 2)),
        const RealNumber(3.14).pow(const RationalNumber(1, 2)),
        const RealNumber(-2.718).pow(const RationalNumber(1, 2)),
        ConstantNumber.pi.pow(const RationalNumber(1, 2)),
        ConstantNumber.e.pow(const RationalNumber(1, 2)),
      ];

      for (final expr in exprs) {
        final mathml = expr.toMathMl();
        _assertValidMathMl(mathml);
        check(mathml).contains('<msqrt><mrow>');
        check(mathml).contains('</mrow></msqrt>');
      }

      check(x.pow(const RationalNumber(1, 2)).toMathMl())
          .equals('<math><msqrt><mrow><mi>x</mi></mrow></msqrt></math>');
      check(const Variable('a&b').pow(const RationalNumber(1, 2)).toMathMl())
          .equals('<math><msqrt><mrow><mi>a&amp;b</mi></mrow></msqrt></math>');
      check(const RationalNumber(42).pow(const RationalNumber(1, 2)).toMathMl())
          .equals('<math><msqrt><mrow><mn>42</mn></mrow></msqrt></math>');
      check(const RationalNumber(-7).pow(const RationalNumber(1, 2)).toMathMl())
          .equals('<math><msqrt><mrow><mn>-7</mn></mrow></msqrt></math>');
      check(ConstantNumber.pi.pow(const RationalNumber(1, 2)).toMathMl())
          .equals('<math><msqrt><mrow><mi>π</mi></mrow></msqrt></math>');
    });

    test('fractional radicands wrap in <mrow>', () {
      final divExpr = (x / y).pow(const RationalNumber(1, 2));
      final mathmlDiv = divExpr.toMathMl();
      _assertValidMathMl(mathmlDiv);
      check(mathmlDiv).equals(
        '<math><msqrt><mrow><mfrac><mi>x</mi><mi>y</mi></mfrac></mrow></msqrt></math>',
      );

      final ratExpr = const RationalNumber(
        1,
        2,
      ).pow(const RationalNumber(1, 2));
      final mathmlRat = ratExpr.toMathMl();
      _assertValidMathMl(mathmlRat);
      check(mathmlRat).equals(
        '<math><msqrt><mrow><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></msqrt></math>',
      );

      final negRatExpr = const RationalNumber(
        -1,
        2,
      ).pow(const RationalNumber(1, 2));
      final mathmlNegRat = negRatExpr.toMathMl();
      _assertValidMathMl(mathmlNegRat);
      check(mathmlNegRat).equals(
        '<math><msqrt><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></msqrt></math>',
      );

      final complexDiv = ((x + y) / (x - y)).pow(const RationalNumber(1, 2));
      final mathmlComplexDiv = complexDiv.toMathMl();
      _assertValidMathMl(mathmlComplexDiv);
      check(mathmlComplexDiv).equals(
        '<math><msqrt><mrow><mfrac><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow></mfrac></mrow></msqrt></math>',
      );
    });

    test(
      'sum and difference radicands wrap in <mrow> without duplicate wrapping',
      () {
        final sumExpr = (x + y).pow(const RationalNumber(1, 2));
        final mathmlSum = sumExpr.toMathMl();
        _assertValidMathMl(mathmlSum);
        check(mathmlSum).equals(
          '<math><msqrt><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow></msqrt></math>',
        );

        final subExpr = (x - y).pow(const RationalNumber(1, 2));
        final mathmlSub = subExpr.toMathMl();
        _assertValidMathMl(mathmlSub);
        check(mathmlSub).equals(
          '<math><msqrt><mrow><mi>x</mi><mo>-</mo><mi>y</mi></mrow></msqrt></math>',
        );

        final multiSumExpr = (x + y + z + w).pow(const RationalNumber(1, 2));
        final mathmlMultiSum = multiSumExpr.toMathMl();
        _assertValidMathMl(mathmlMultiSum);
        check(mathmlMultiSum).equals(
          '<math><msqrt><mrow><mrow><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>+</mo><mi>z</mi></mrow><mo>+</mo><mi>w</mi></mrow></msqrt></math>',
        );

        final nestedSubExpr = (x - (y + z)).pow(const RationalNumber(1, 2));
        final mathmlNestedSub = nestedSubExpr.toMathMl();
        _assertValidMathMl(mathmlNestedSub);
        check(mathmlNestedSub).equals(
          '<math><msqrt><mrow><mi>x</mi><mo>-</mo><mrow><mo>(</mo><mrow><mi>y</mi><mo>+</mo><mi>z</mi></mrow><mo>)</mo></mrow></mrow></msqrt></math>',
        );
      },
    );

    test('product radicands wrap in <mrow>', () {
      final prodExpr = (x * y).pow(const RationalNumber(1, 2));
      final mathmlProd = prodExpr.toMathMl();
      _assertValidMathMl(mathmlProd);
      check(mathmlProd).equals(
        '<math><msqrt><mrow><mi>x</mi><mo>&#x22c5;</mo><mi>y</mi></mrow></msqrt></math>',
      );

      final prodSum = ((x + y) * z).pow(const RationalNumber(1, 2));
      final mathmlProdSum = prodSum.toMathMl();
      _assertValidMathMl(mathmlProdSum);
      check(mathmlProdSum).equals(
        '<math><msqrt><mrow><mrow><mo>(</mo><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mo>)</mo></mrow><mo>&#x22c5;</mo><mi>z</mi></mrow></msqrt></math>',
      );
    });

    test('nested square roots wrap inner <msqrt> in <mrow>', () {
      final nestedSqrt = x
          .pow(const RationalNumber(1, 2))
          .pow(const RationalNumber(1, 2));
      final mathml = nestedSqrt.toMathMl();
      _assertValidMathMl(mathml);
      check(mathml).equals(
        '<math><msqrt><mrow><msqrt><mrow><mi>x</mi></mrow></msqrt></mrow></msqrt></math>',
      );

      final tripleNested = x
          .pow(const RationalNumber(1, 2))
          .pow(const RationalNumber(1, 2))
          .pow(const RationalNumber(1, 2));
      final mathmlTriple = tripleNested.toMathMl();
      _assertValidMathMl(mathmlTriple);
      check(mathmlTriple).equals(
        '<math><msqrt><mrow><msqrt><mrow><msqrt><mrow><mi>x</mi></mrow></msqrt></mrow></msqrt></mrow></msqrt></math>',
      );

      final sumOfSqrts =
          (x.pow(const RationalNumber(1, 2)) +
                  y.pow(const RationalNumber(1, 2)))
              .pow(const RationalNumber(1, 2));
      final mathmlSumSqrts = sumOfSqrts.toMathMl();
      _assertValidMathMl(mathmlSumSqrts);
      check(mathmlSumSqrts).equals(
        '<math><msqrt><mrow><msqrt><mrow><mi>x</mi></mrow></msqrt><mo>+</mo><msqrt><mrow><mi>y</mi></mrow></msqrt></mrow></msqrt></math>',
      );
    });

    test('transcendental, negation, and power radicands in <msqrt>', () {
      final sinSqrt = const Sin(x).pow(const RationalNumber(1, 2));
      check(sinSqrt.toMathMl()).equals(
        '<math><msqrt><mrow><mi>sin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></msqrt></math>',
      );
      _assertValidMathMl(sinSqrt.toMathMl());

      final expSqrt = const Exp(x).pow(const RationalNumber(1, 2));
      check(expSqrt.toMathMl()).equals(
        '<math><msqrt><mrow><msup><mi>e</mi><mi>x</mi></msup></mrow></msqrt></math>',
      );
      _assertValidMathMl(expSqrt.toMathMl());

      final negSqrt = (-x).pow(const RationalNumber(1, 2));
      check(
        negSqrt.toMathMl(),
      ).equals('<math><msqrt><mrow><mo>-</mo><mi>x</mi></mrow></msqrt></math>');
      _assertValidMathMl(negSqrt.toMathMl());

      final powSqrt = x
          .pow(const RationalNumber(2))
          .pow(const RationalNumber(1, 2));
      check(powSqrt.toMathMl()).equals(
        '<math><msqrt><mrow><msup><mi>x</mi><mn>2</mn></msup></mrow></msqrt></math>',
      );
      _assertValidMathMl(powSqrt.toMathMl());
    });
  });

  group('MathML - Arbitrary Roots (<mroot>) Container Wrapping', () {
    const x = Variable('x');
    const y = Variable('y');

    test('mroot wraps radicand and index in <mrow> containers', () {
      final exprs = <Expr>[
        x.pow(const RationalNumber(1, 3)),
        x.pow(const RationalNumber(1, 4)),
        x.pow(const RationalNumber(1, 5)),
        x.pow(const RationalNumber(1, 10)),
        x.pow(const RationalNumber(1, 100)),
      ];

      for (final expr in exprs) {
        final mathml = expr.toMathMl();
        _assertValidMathMl(mathml);
        check(mathml).contains('<mroot><mrow>');
        check(mathml).contains('</mrow><mrow><mn>');
        check(mathml).contains('</mn></mrow></mroot>');
      }

      check(x.pow(const RationalNumber(1, 3)).toMathMl()).equals(
        '<math><mroot><mrow><mi>x</mi></mrow><mrow><mn>3</mn></mrow></mroot></math>',
      );
      check(x.pow(const RationalNumber(1, 4)).toMathMl()).equals(
        '<math><mroot><mrow><mi>x</mi></mrow><mrow><mn>4</mn></mrow></mroot></math>',
      );
    });

    test('mroot with fraction, sum, product, and nested roots', () {
      final divRoot = (x / y).pow(const RationalNumber(1, 3));
      final mathmlDiv = divRoot.toMathMl();
      _assertValidMathMl(mathmlDiv);
      check(mathmlDiv).equals(
        '<math><mroot><mrow><mfrac><mi>x</mi><mi>y</mi></mfrac></mrow><mrow><mn>3</mn></mrow></mroot></math>',
      );

      final sumRoot = (x + y).pow(const RationalNumber(1, 5));
      final mathmlSum = sumRoot.toMathMl();
      _assertValidMathMl(mathmlSum);
      check(mathmlSum).equals(
        '<math><mroot><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mrow><mn>5</mn></mrow></mroot></math>',
      );

      final prodRoot = (x * y).pow(const RationalNumber(1, 4));
      final mathmlProd = prodRoot.toMathMl();
      _assertValidMathMl(mathmlProd);
      check(mathmlProd).equals(
        '<math><mroot><mrow><mi>x</mi><mo>&#x22c5;</mo><mi>y</mi></mrow><mrow><mn>4</mn></mrow></mroot></math>',
      );

      final sqrtInMroot = x
          .pow(const RationalNumber(1, 2))
          .pow(const RationalNumber(1, 3));
      final mathmlSqrtInMroot = sqrtInMroot.toMathMl();
      _assertValidMathMl(mathmlSqrtInMroot);
      check(mathmlSqrtInMroot).equals(
        '<math><mroot><mrow><msqrt><mrow><mi>x</mi></mrow></msqrt></mrow><mrow><mn>3</mn></mrow></mroot></math>',
      );

      final mrootInSqrt = x
          .pow(const RationalNumber(1, 3))
          .pow(const RationalNumber(1, 2));
      final mathmlMrootInSqrt = mrootInSqrt.toMathMl();
      _assertValidMathMl(mathmlMrootInSqrt);
      check(mathmlMrootInSqrt).equals(
        '<math><msqrt><mrow><mroot><mrow><mi>x</mi></mrow><mrow><mn>3</mn></mrow></mroot></mrow></msqrt></math>',
      );

      final mrootInMroot = x
          .pow(const RationalNumber(1, 3))
          .pow(const RationalNumber(1, 4));
      final mathmlMrootInMroot = mrootInMroot.toMathMl();
      _assertValidMathMl(mathmlMrootInMroot);
      check(mathmlMrootInMroot).equals(
        '<math><mroot><mrow><mroot><mrow><mi>x</mi></mrow><mrow><mn>3</mn></mrow></mroot></mrow><mrow><mn>4</mn></mrow></mroot></math>',
      );
    });
  });

  group('MathML - Non-radical Rational Exponents & Boundary Conditions', () {
    const x = Variable('x');

    test('non-unit numerators produce <msup>', () {
      final twoThirds = x.pow(const RationalNumber(2, 3));
      check(twoThirds.toMathMl()).equals(
        '<math><msup><mi>x</mi><mfrac><mn>2</mn><mn>3</mn></mfrac></msup></math>',
      );
      _assertValidMathMl(twoThirds.toMathMl());

      final fourThirds = x.pow(const RationalNumber(4, 3));
      check(fourThirds.toMathMl()).equals(
        '<math><msup><mi>x</mi><mfrac><mn>4</mn><mn>3</mn></mfrac></msup></math>',
      );
      _assertValidMathMl(fourThirds.toMathMl());
    });

    test('negative fractional exponents produce <msup>', () {
      final negHalf = x.pow(const RationalNumber(-1, 2));
      check(negHalf.toMathMl()).equals(
        '<math><msup><mi>x</mi><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></msup></math>',
      );
      _assertValidMathMl(negHalf.toMathMl());

      final negThird = x.pow(const RationalNumber(-1, 3));
      check(negThird.toMathMl()).equals(
        '<math><msup><mi>x</mi><mrow><mo>-</mo><mfrac><mn>1</mn><mn>3</mn></mfrac></mrow></msup></math>',
      );
      _assertValidMathMl(negThird.toMathMl());
    });

    test('denominator 1 produces <msup>', () {
      final pow1 = x.pow(const RationalNumber(1));
      check(pow1.toMathMl())
          .equals('<math><msup><mi>x</mi><mn>1</mn></msup></math>');
      _assertValidMathMl(pow1.toMathMl());

      final pow0 = x.pow(const RationalNumber(0));
      check(pow0.toMathMl())
          .equals('<math><msup><mi>x</mi><mn>0</mn></msup></math>');
      _assertValidMathMl(pow0.toMathMl());
    });
  });

  group('MathML - Cross-Format Parity (MathML, LaTeX, String)', () {
    const x = Variable('x');
    const y = Variable('y');

    final testCases = <({Expr expr, String mathml, String latex, String str})>[
      (
        expr: x.pow(const RationalNumber(1, 2)),
        mathml: '<math><msqrt><mrow><mi>x</mi></mrow></msqrt></math>',
        latex: r'\sqrt{x}',
        str: 'sqrt(x)',
      ),
      (
        expr: (x + y).pow(const RationalNumber(1, 2)),
        mathml: '<math><msqrt><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow></msqrt></math>',
        latex: r'\sqrt{x + y}',
        str: 'sqrt(x + y)',
      ),
      (
        expr: (x * y).pow(const RationalNumber(1, 2)),
        mathml: '<math><msqrt><mrow><mi>x</mi><mo>&#x22c5;</mo><mi>y</mi></mrow></msqrt></math>',
        latex: r'\sqrt{x \cdot y}',
        str: 'sqrt(x * y)',
      ),
      (
        expr: (x / y).pow(const RationalNumber(1, 2)),
        mathml: '<math><msqrt><mrow><mfrac><mi>x</mi><mi>y</mi></mfrac></mrow></msqrt></math>',
        latex: r'\sqrt{\frac{x}{y}}',
        str: 'sqrt(x / y)',
      ),
      (
        expr: x.pow(const RationalNumber(1, 2)).pow(const RationalNumber(1, 2)),
        mathml: '<math><msqrt><mrow><msqrt><mrow><mi>x</mi></mrow></msqrt></mrow></msqrt></math>',
        latex: r'\sqrt{\sqrt{x}}',
        str: 'sqrt(sqrt(x))',
      ),
      (
        expr: x.pow(const RationalNumber(1, 3)),
        mathml: '<math><mroot><mrow><mi>x</mi></mrow><mrow><mn>3</mn></mrow></mroot></math>',
        latex: r'\sqrt[3]{x}',
        str: 'x ^ (1/3)',
      ),
      (
        expr: (x + y).pow(const RationalNumber(1, 3)),
        mathml: '<math><mroot><mrow><mi>x</mi><mo>+</mo><mi>y</mi></mrow><mrow><mn>3</mn></mrow></mroot></math>',
        latex: r'\sqrt[3]{x + y}',
        str: '(x + y) ^ (1/3)',
      ),
      (
        expr: (x / y).pow(const RationalNumber(1, 4)),
        mathml: '<math><mroot><mrow><mfrac><mi>x</mi><mi>y</mi></mfrac></mrow><mrow><mn>4</mn></mrow></mroot></math>',
        latex: r'\sqrt[4]{\frac{x}{y}}',
        str: '(x / y) ^ (1/4)',
      ),
      (
        expr: (-x).pow(const RationalNumber(1, 2)),
        mathml: '<math><msqrt><mrow><mo>-</mo><mi>x</mi></mrow></msqrt></math>',
        latex: r'\sqrt{-x}',
        str: 'sqrt(-x)',
      ),
      (
        expr: const Sin(x).pow(const RationalNumber(1, 2)),
        mathml: '<math><msqrt><mrow><mi>sin</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></msqrt></math>',
        latex: r'\sqrt{\sin(x)}',
        str: 'sqrt(sin(x))',
      ),
      (
        expr: const Exp(x).pow(const RationalNumber(1, 2)),
        mathml: '<math><msqrt><mrow><msup><mi>e</mi><mi>x</mi></msup></mrow></msqrt></math>',
        latex: r'\sqrt{e^{x}}',
        str: 'sqrt(exp(x))',
      ),
      (
        expr: const RationalNumber(1, 2).pow(const RationalNumber(1, 2)),
        mathml: '<math><msqrt><mrow><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></msqrt></math>',
        latex: r'\sqrt{\frac{1}{2}}',
        str: 'sqrt(1/2)',
      ),
      (
        expr: x.pow(const RationalNumber(2, 3)),
        mathml: '<math><msup><mi>x</mi><mfrac><mn>2</mn><mn>3</mn></mfrac></msup></math>',
        latex: r'{x}^{\frac{2}{3}}',
        str: 'x ^ (2/3)',
      ),
      (
        expr: x.pow(const RationalNumber(-1, 2)),
        mathml: '<math><msup><mi>x</mi><mrow><mo>-</mo><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></msup></math>',
        latex: r'{x}^{-\frac{1}{2}}',
        str: 'x ^ (-1/2)',
      ),
    ];

    for (final testCase in testCases) {
      test('aligned textualization for ${testCase.str}', () {
        check(testCase.expr.toMathMl()).equals(testCase.mathml);
        _assertValidMathMl(testCase.expr.toMathMl());
        check(testCase.expr.toLatex()).equals(testCase.latex);
        check(testCase.expr.toString()).equals(testCase.str);
      });
    }

    test('parser round-trip for square root functions', () {
      final parsed1 = Expr.parse('sqrt(x)');
      check(parsed1).equals(x.pow(const RationalNumber(1, 2)));
      check(parsed1.toMathMl())
          .equals('<math><msqrt><mrow><mi>x</mi></mrow></msqrt></math>');

      final parsed2 = Expr.parse('sqrt(x + 1)');
      check(
        parsed2,
      ).equals((x + const RationalNumber(1)).pow(const RationalNumber(1, 2)));
      check(parsed2.toMathMl()).equals(
        '<math><msqrt><mrow><mi>x</mi><mo>+</mo><mn>1</mn></mrow></msqrt></math>',
      );

      final parsedNested = Expr.parse('sqrt(sqrt(x))');
      check(parsedNested).equals(
        x.pow(const RationalNumber(1, 2)).pow(const RationalNumber(1, 2)),
      );
      check(parsedNested.toMathMl()).equals(
        '<math><msqrt><mrow><msqrt><mrow><mi>x</mi></mrow></msqrt></mrow></msqrt></math>',
      );
    });
  });

  group('MathML - Generative Stress Fuzzing & Tree Invariant Enforcement', () {
    Expr generateRandomExpression(math.Random rng, int depth) {
      if (depth <= 0) {
        return switch (rng.nextInt(4)) {
          0 => const Variable('x'),
          1 => const Variable('y'),
          2 => RationalNumber(rng.nextInt(10) + 1),
          _ => RationalNumber(rng.nextInt(5) + 1, rng.nextInt(5) + 2),
        };
      }

      final op = rng.nextInt(9);
      final left = generateRandomExpression(rng, depth - 1);
      final right = generateRandomExpression(rng, depth - 1);

      return switch (op) {
        0 => left + right,
        1 => left - right,
        2 => left * right,
        3 => left / right,
        4 => left.pow(const RationalNumber(1, 2)), // square root
        5 => left.pow(
          RationalNumber(1, rng.nextInt(6) + 3),
        ), // higher-order root (3..8)
        6 => Sin(left),
        7 => Exp(left),
        _ => -left,
      };
    }

    test('generative stress test: 200 random ASTs produce strictly compliant MathML', () {
      final rng = math.Random(1337);
      for (var i = 0; i < 200; i++) {
        final depth = rng.nextInt(4) + 1;
        final expr = generateRandomExpression(rng, depth);
        final mathml = expr.toMathMl();
        _assertValidMathMl(mathml);

        // Verify that if <msqrt> is present, it directly encloses <mrow>
        if (mathml.contains('<msqrt>')) {
          check(mathml).contains('<msqrt><mrow>');
          check(mathml).contains('</mrow></msqrt>');
        }
        // Verify that if <mroot> is present, it directly encloses two <mrow> elements
        if (mathml.contains('<mroot>')) {
          check(mathml).contains('<mroot><mrow>');
          check(mathml).contains('</mrow><mrow><mn>');
          check(mathml).contains('</mn></mrow></mroot>');
        }

        // Verify LaTeX and String generation don't throw or produce empty output
        check(expr.toLatex()).isNotEmpty();
        check(expr.toString()).isNotEmpty();
      }
    });
  });
}

/// Lightweight XML DOM representation for validating MathML structure.
class _XmlNode {
  new(
    this.tag, {
    this.attributes = const {},
    this.isText = false,
    this.text = '',
  });

  final String tag;
  final Map<String, String> attributes;
  final bool isText;
  final String text;
  final List<_XmlNode> children = [];

  @override
  String toString() {
    if (isText) return text;
    final attrStr = attributes.isEmpty
        ? ''
        : ' ${attributes.entries.map((e) => '${e.key}="${e.value}"').join(' ')}';
    if (children.isEmpty) return '<$tag$attrStr/>';
    return '<$tag$attrStr>${children.map((c) => c.toString()).join()}</$tag>';
  }
}

/// Strict stack-based XML parser for MathML validation.
_XmlNode _parseXml(String xml) {
  final tagRegex = RegExp(r'<(/)?([a-zA-Z0-9_:]+)([^>]*)>|([^<]+)');
  final matches = tagRegex.allMatches(xml);

  final stack = <_XmlNode>[];
  _XmlNode? root;

  for (final match in matches) {
    final isClosing = match.group(1) == '/';
    final tagName = match.group(2);
    final attrString = match.group(3);
    final textContent = match.group(4);

    if (textContent != null) {
      if (textContent.trim().isNotEmpty) {
        final textNode = _XmlNode('#text', isText: true, text: textContent);
        if (stack.isNotEmpty) {
          stack.last.children.add(textNode);
        }
      }
    } else if (tagName != null) {
      if (isClosing) {
        if (stack.isEmpty) {
          throw FormatException('Unexpected closing tag </$tagName>');
        }
        final popped = stack.removeLast();
        if (popped.tag != tagName) {
          throw FormatException(
            'Mismatched closing tag: expected </${popped.tag}>, got </$tagName>',
          );
        }
      } else {
        // Opening tag
        final attrs = <String, String>{};
        if (attrString != null && attrString.trim().isNotEmpty) {
          final attrRegex = RegExp(r'([a-zA-Z0-9_:]+)="([^"]*)"');
          for (final attrMatch in attrRegex.allMatches(attrString)) {
            attrs[attrMatch.group(1)!] = attrMatch.group(2)!;
          }
        }
        final node = _XmlNode(tagName, attributes: attrs);
        if (stack.isNotEmpty) {
          stack.last.children.add(node);
        } else if (root == null) {
          root = node;
        } else {
          throw const FormatException('Multiple root elements in XML');
        }
        stack.add(node);
      }
    }
  }

  if (stack.isNotEmpty) {
    throw FormatException('Unclosed XML tag: <${stack.last.tag}>');
  }
  if (root == null) {
    throw const FormatException('Empty XML document');
  }
  return root;
}

/// Recursively validates W3C MathML compliance, focusing on radicals and layout safety.
void _validateMathMlTree(_XmlNode node) {
  // Filter out pure text nodes for element count checks
  final elementChildren = node.children.where((c) => !c.isText).toList();

  switch (node.tag) {
    case 'math':
      check(elementChildren.length).equals(1);
    case 'msqrt':
      // W3C container wrapping check: exactly 1 child, which MUST be <mrow>
      check(elementChildren.length).equals(1);
      final radicandContainer = elementChildren[0];
      check(radicandContainer.tag).equals('mrow');
    case 'mroot':
      // W3C mroot contract: exactly 2 children: radicand container and index container
      check(elementChildren.length).equals(2);
      final radicandContainer = elementChildren[0];
      final indexContainer = elementChildren[1];
      check(radicandContainer.tag).equals('mrow');
      check(indexContainer.tag).equals('mrow');
      // Index container must contain an <mn> with degree
      final indexElements = indexContainer.children
          .where((c) => !c.isText)
          .toList();
      check(indexElements.length).equals(1);
      check(indexElements[0].tag).equals('mn');
    case 'msup':
      // W3C msup contract: exactly 2 children (base and exponent)
      check(elementChildren.length).equals(2);
    case 'mfrac':
      // W3C mfrac contract: exactly 2 children (numerator and denominator)
      check(elementChildren.length).equals(2);
  }

  for (final child in elementChildren) {
    _validateMathMlTree(child);
  }
}

void _assertValidMathMl(String mathml) {
  final dom = _parseXml(mathml);
  _validateMathMlTree(dom);
}
