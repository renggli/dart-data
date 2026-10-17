import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Numeric approximation of numbers and constants', () {
    test('converts RationalNumber and preserves RealNumber', () {
      check(IntegerNumber.of(5).approximate()).equals(const RealNumber(5.0));
      check(FractionNumber.half.approximate()).equals(const RealNumber(0.5));
      check(const RealNumber(1.25).approximate())
          .equals(const RealNumber(1.25));
    });

    test('converts ComplexNumber components to RealNumber', () {
      final c = ComplexNumber.of(
        IntegerNumber.of(3),
        const FractionNumber(Integer.one, Integer(4)),
      );
      final approx = c.approximate();
      check(approx).isA<ComplexNumber>();
      final ac = approx as ComplexNumber;
      check(ac.real).equals(const RealNumber(3.0));
      check(ac.imaginary).equals(const RealNumber(0.25));
    });

    test(
      'evaluates mathematical constants and preserves special constants',
      () {
        check((Constant.pi.approximate() as RealNumber).value)
            .isCloseTo(math.pi, 1e-15);
        check((Constant.e.approximate() as RealNumber).value)
            .isCloseTo(math.e, 1e-15);
        check(Constant.infinity.approximate()).equals(Constant.infinity);
        check(Constant.undefined.approximate()).equals(Constant.undefined);

        const nanConst = Constant('nan', Complex.nan);
        check(nanConst.approximate()).equals(Constant.undefined);

        const infComplexConst = Constant(
          'inf_c',
          Complex(1.0, double.infinity),
        );
        check(infComplexConst.approximate()).equals(Constant.undefined);

        const complexConst = Constant('omega', Complex(1.5, 2.5));
        check(complexConst.approximate()).equals(
          ComplexNumber.of(const RealNumber(1.5), const RealNumber(2.5)),
        );
      },
    );

    test('substitutes bindings before approximation', () {
      final expr = Expr.parse('pi * x + y / 4');
      final approx = expr.approximate({
        'x': IntegerNumber.two,
        'y': IntegerNumber.of(3),
      });
      check(approx).isA<RealNumber>();
      check((approx as RealNumber).value).isCloseTo(2 * math.pi + 0.75, 1e-12);
    });
  });

  group(
    'Numeric approximation of composite and transcendental expressions',
    () {
      test('folds closed expressions with unary functions', () {
        check((Expr.parse('sin(1)').approximate() as RealNumber).value)
            .isCloseTo(math.sin(1.0), 1e-12);
        check((Expr.parse('cos(1)').approximate() as RealNumber).value)
            .isCloseTo(math.cos(1.0), 1e-12);
        check((Expr.parse('tan(1)').approximate() as RealNumber).value)
            .isCloseTo(math.tan(1.0), 1e-12);
        check((Expr.parse('asin(1/2)').approximate() as RealNumber).value)
            .isCloseTo(math.asin(0.5), 1e-12);
        check((Expr.parse('acos(1/2)').approximate() as RealNumber).value)
            .isCloseTo(math.acos(0.5), 1e-12);
        check((Expr.parse('atan(1)').approximate() as RealNumber).value)
            .isCloseTo(math.atan(1.0), 1e-12);
        check((Expr.parse('sinh(1)').approximate() as RealNumber).value)
            .isCloseTo((math.exp(1.0) - math.exp(-1.0)) / 2, 1e-12);
        check((Expr.parse('cosh(1)').approximate() as RealNumber).value)
            .isCloseTo((math.exp(1.0) + math.exp(-1.0)) / 2, 1e-12);
        check(
          (Expr.parse('tanh(1)').approximate() as RealNumber).value,
        ).isCloseTo(
          (math.exp(1.0) - math.exp(-1.0)) / (math.exp(1.0) + math.exp(-1.0)),
          1e-12,
        );
        check((Asinh(IntegerNumber.one).approximate() as RealNumber).value)
            .isCloseTo(math.log(1.0 + math.sqrt(2.0)), 1e-12);
        check((Acosh(IntegerNumber.two).approximate() as RealNumber).value)
            .isCloseTo(math.log(2.0 + math.sqrt(3.0)), 1e-12);
        check((Atanh(FractionNumber.half).approximate() as RealNumber).value)
            .isCloseTo(0.5 * math.log(3.0), 1e-12);
        check((Ln(IntegerNumber.two).approximate() as RealNumber).value)
            .isCloseTo(math.ln2, 1e-12);
        check((Erf(IntegerNumber.one).approximate() as RealNumber).value)
            .isCloseTo(0.8427007929497149, 1e-7);
        check((Erfc(IntegerNumber.one).approximate() as RealNumber).value)
            .isCloseTo(1.0 - 0.8427007929497149, 1e-7);
        check((Gamma(FractionNumber.half).approximate() as RealNumber).value)
            .isCloseTo(math.sqrt(math.pi), 1e-12);
        check((LambertW(IntegerNumber.one).approximate() as RealNumber).value)
            .isCloseTo(0.5671432904097838, 1e-12);
      });

      test('evaluates complex-valued unary and power expressions', () {
        // Negative base with fractional exponent in _approximatePow
        final negPow = Pow(
          IntegerNumber.of(-2),
          FractionNumber.third,
        ).approximate();
        check(negPow).isA<ComplexNumber>();
        final np = negPow as ComplexNumber;
        check(np.real.toDouble())
            .isCloseTo(math.pow(2, 1 / 3) * math.cos(math.pi / 3), 1e-12);
        check(np.imaginary.toDouble())
            .isCloseTo(math.pow(2, 1 / 3) * math.sin(math.pi / 3), 1e-12);

        // Overflow in negative base fractional power returns Constant.undefined
        final overflowPow = Pow(
          const RealNumber(-1e200),
          const RealNumber(200.5),
        ).approximate();
        check(overflowPow).equals(Constant.undefined);

        // Unary function where real evaluation is NaN but complex evaluation succeeds
        final lnNeg1 = Ln(IntegerNumber.negativeOne).approximate();
        check(lnNeg1).isA<ComplexNumber>();
        check((lnNeg1 as ComplexNumber).imaginary.toDouble())
            .isCloseTo(math.pi, 1e-12);

        // Unary function on ComplexNumber producing ComplexNumber
        final sinComplex = Sin(
          ComplexNumber.of(IntegerNumber.one, IntegerNumber.one),
        ).approximate();
        check(sinComplex).isA<ComplexNumber>();

        // Unary function on ComplexNumber producing real result (im == 0)
        final absComplex = Abs(
          ComplexNumber.of(IntegerNumber.of(3), IntegerNumber.of(4)),
        ).approximate();
        check(absComplex).equals(const RealNumber(5.0));

        // Unary function where complex evaluation is NaN or infinite
        final badUnary = LambertW(IntegerNumber.negativeOne).approximate();
        check(badUnary).equals(Constant.undefined);

        final infUnary = Sinh(
          ComplexNumber.of(const RealNumber(1000.0), IntegerNumber.one),
        ).approximate();
        check(infUnary).equals(Constant.undefined);
      });

      test('evaluates BinaryExpr (Beta) for real and symbolic inputs', () {
        final realBeta = Beta(
          FractionNumber.half,
          FractionNumber.half,
        ).approximate();
        check(realBeta).isA<RealNumber>();
        check((realBeta as RealNumber).value).isCloseTo(math.pi, 1e-10);

        final nanBeta = Beta(
          IntegerNumber.zero,
          IntegerNumber.one,
        ).approximate();
        check(nanBeta).equals(Constant.undefined);

        final symBeta = Beta(const Variable('x'), Constant.pi).approximate();
        check(symBeta).isA<Beta>();
        check((symBeta as Beta).left).isA<RealNumber>();
      });

      test(
        'approximates Piecewise, RelationalExpr, Integral, and OrderTerm',
        () {
          final rel = LessThan(Constant.pi, IntegerNumber.of(4)).approximate();
          check(rel).equals(IntegerNumber.one);

          final pw = Piecewise([
            (
              relation: LessThan(const Variable('x'), Constant.pi),
              expr: FractionNumber.half,
            ),
          ], otherwise: Constant.e).approximate();
          check(pw).isA<Piecewise>();

          final defInt = Integral(
            const Variable('x'),
            'x',
            lower: IntegerNumber.zero,
            upper: IntegerNumber.two,
          ).approximate();
          check(defInt).isA<RealNumber>();
          check((defInt as RealNumber).value).isCloseTo(2.0, 1e-10);

          final symInt = Integral(
            const Variable('x') * Constant.pi,
            'x',
          ).approximate();
          check(symInt).isA<Integral>();

          final symPow = Pow(const Variable('x'), Constant.pi).approximate();
          check(symPow).isA<Pow>();

          final symUnary = Sin(const Variable('x')).approximate();
          check(symUnary).isA<Sin>();

          const ord = OrderTerm('x', 3);
          check(ord.approximate()).equals(ord);
        },
      );
    },
  );

  group('Rationalization via continued fractions', () {
    test('recovers exact fractions from RealNumber and ComplexNumber', () {
      check(const RealNumber(0.0).rationalize()).equals(IntegerNumber.zero);
      check(const RealNumber(-0.75).rationalize())
          .equals(RationalNumber(-3, 4));
      check(const RealNumber(0.3333333333333333).rationalize())
          .equals(FractionNumber.third);
      check(const RealNumber(3.5).rationalize(tolerance: 0.0))
          .equals(RationalNumber(7, 2));

      // Respects maxDenominator bound
      check(const RealNumber(math.pi).rationalize(maxDenominator: 10))
          .equals(RationalNumber(22, 7));

      // ComplexNumber with both RealNumber and RationalNumber components
      final c1 = ComplexNumber.of(
        const RealNumber(0.5),
        const RealNumber(-0.25),
      ).rationalize();
      check(c1).equals(
        ComplexNumber.of(
          FractionNumber.half,
          const FractionNumber(Integer.negativeOne, Integer(4)),
        ),
      );

      final c2 = ComplexNumber.of(
        FractionNumber.half,
        const RealNumber(0.25),
      ).rationalize();
      check(
        c2,
      ).equals(ComplexNumber.of(FractionNumber.half, FractionNumber.quarter));
    });

    test(
      'rationalizes composite expressions and leaves symbolic leaves intact',
      () {
        final expr = Add([
          Mul([const RealNumber(0.5), const Variable('x')]),
          const RealNumber(0.125),
          Constant.pi,
          const OrderTerm('x', 4),
        ]);
        final rat = expr.rationalize();
        check(rat.anyNode((n) => n is RealNumber)).isFalse();
        check(rat.anyNode((n) => n == FractionNumber.half)).isTrue();
        check(rat.anyNode((n) => n == RationalNumber(1, 8))).isTrue();
      },
    );
  });
}
