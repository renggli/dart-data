import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('PowerSeries algebra and properties', () {
    test('inspects valuation, poleOrder, leadingTerm, and constantTerm', () {
      final zero = PowerSeries('x', IntegerNumber.zero, const {}, 5);
      check(zero.valuation).equals(5);
      check(zero.poleOrder).equals(0);
      check(zero.leadingTerm).isNull;
      check(zero.constantTerm).equals(IntegerNumber.zero);
      check(zero.toExpr(includeOrder: false)).equals(IntegerNumber.zero);
      check(zero.toExpr()).equals(OrderTerm('x', 5));

      final laurent = PowerSeries('x', IntegerNumber.zero, {
        -2: IntegerNumber.of(3),
        0: IntegerNumber.of(5),
        7: IntegerNumber.one,
      }, 4);
      check(laurent.valuation).equals(-2);
      check(laurent.poleOrder).equals(2);
      check(laurent.leadingTerm)
          .equals((exponent: -2, coefficient: IntegerNumber.of(3)));
      check(laurent.constantTerm).equals(IntegerNumber.of(5));
      check(laurent.coefficients.containsKey(7)).isFalse;
    });

    test('performs addition, subtraction, negation, scaling, and division', () {
      final s1 = PowerSeries('x', IntegerNumber.zero, {
        0: IntegerNumber.one,
        1: IntegerNumber.two,
      }, 4);
      final s2 = PowerSeries('x', IntegerNumber.zero, {
        0: IntegerNumber.one,
        2: IntegerNumber.of(3),
      }, 3);

      final sum = s1 + s2;
      check(sum.order).equals(3);
      check(sum.coefficients[0]).equals(IntegerNumber.two);
      check(sum.coefficients[1]).equals(IntegerNumber.two);
      check(sum.coefficients[2]).equals(IntegerNumber.of(3));

      final diff = s1 - s2;
      check(diff.coefficients[0]).isNull;
      check(diff.coefficients[1]).equals(IntegerNumber.two);
      check(diff.coefficients[2]).equals(IntegerNumber.of(-3));

      final neg = -s1;
      check(neg.coefficients[0]).equals(IntegerNumber.negativeOne);
      check(neg.coefficients[1]).equals(IntegerNumber.of(-2));

      check(s1.scale(IntegerNumber.zero).coefficients).isEmpty;
      check(s1.scale(IntegerNumber.of(3)).coefficients[1])
          .equals(IntegerNumber.of(6));

      final quot = s1 / s2;
      check((quot * s2).coefficients[0]).equals(IntegerNumber.one);
      check((quot * s2).coefficients[1]).equals(IntegerNumber.two);

      check(
        () => PowerSeries('x', IntegerNumber.zero, const {}, 4).reciprocal(),
      ).throws<UnsupportedError>();

      check(() => s1 + PowerSeries('y', IntegerNumber.zero, const {}, 4))
          .throws<ArgumentError>();
      check(() => s1 + PowerSeries('x', IntegerNumber.one, const {}, 4))
          .throws<ArgumentError>();
    });

    test(
      'computes integer and fractional powers, derivative, and integral',
      () {
        final s = (IntegerNumber.one + x).toPowerSeries('x', order: 4);
        check(s.pow(IntegerNumber.zero).toExpr(includeOrder: false))
            .equals(IntegerNumber.one);
        check(s.pow(IntegerNumber.one)).equals(s);
        check(s.pow(IntegerNumber.two).coefficients[2])
            .equals(IntegerNumber.one);
        check(s.pow(IntegerNumber.negativeOne).coefficients[1])
            .equals(IntegerNumber.negativeOne);

        final zero = PowerSeries('x', IntegerNumber.zero, const {}, 4);
        check(zero.pow(FractionNumber.half).coefficients).isEmpty;

        final shifted =
            (Pow.of(x, IntegerNumber.two) + Pow.of(x, IntegerNumber.of(3)))
                .toPowerSeries('x', order: 5);
        final sqrtShifted = shifted.pow(FractionNumber.half);
        check(sqrtShifted.valuation).equals(1);
        check(sqrtShifted.coefficients[1]).equals(IntegerNumber.one);
        check(sqrtShifted.coefficients[2]).equals(FractionNumber.half);

        check(() => x.toPowerSeries('x', order: 4).pow(FractionNumber.half))
            .throws<UnsupportedError>();

        final deriv = s.derivative();
        check(deriv.order).equals(3);
        check(deriv.toExpr(includeOrder: false)).equals(IntegerNumber.one);

        final integ = deriv.integrate(constant: IntegerNumber.of(5));
        check(integ.order).equals(4);
        check(integ.coefficients[0]).equals(IntegerNumber.of(5));
        check(integ.coefficients[1]).equals(IntegerNumber.one);

        check(
          () =>
              (IntegerNumber.one / x).toPowerSeries('x', order: 3).integrate(),
        ).throws<UnsupportedError>();
      },
    );

    test('formats PowerSeries to Expr around zero and non-zero points', () {
      final single = PowerSeries('x', IntegerNumber.zero, {
        1: IntegerNumber.one,
      }, 3);
      check(single.toExpr(includeOrder: false)).equals(x);

      final centered = PowerSeries('x', IntegerNumber.one, {
        0: IntegerNumber.two,
        1: IntegerNumber.negativeOne,
        2: IntegerNumber.of(3),
      }, 3);
      check(centered.toExpr().evaluate({'x': 2.0})).equals(4.0);
    });
  });

  group('Elementary function series expansions', () {
    test('expands constants, variables, products, and poles', () {
      check(IntegerNumber.of(3).series('x', order: 3))
          .equals(IntegerNumber.of(3) + OrderTerm('x', 3));
      check(Constant.pi.series('x', order: 3))
          .equals(Constant.pi + OrderTerm('x', 3));
      check(y.series('x', order: 3)).equals(y + OrderTerm('x', 3));
      check(Fn.sin(y).series('x', order: 3))
          .equals(Fn.sin(y) + OrderTerm('x', 3));
      check(x.series('x', point: IntegerNumber.one, order: 3).toString())
          .equals('x + O((x - 1)^3)');

      final laurent = Expr.parse('sin(x) / x^2').series('x', order: 3);
      check(laurent.toString()).equals('-1/6 * x + 1 / x + O(x^3)');

      final leftPole = ((IntegerNumber.one / x) * Fn.sin(x)).series(
        'x',
        order: 3,
      );
      check(leftPole.toString()).equals('1 - 1/6 * x ^ 2 + O(x^3)');

      final bothPoles =
          ((IntegerNumber.one / x) *
                  (IntegerNumber.one / (x + Pow.of(x, IntegerNumber.two))))
              .series('x', order: 2);
      check(bothPoles.removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(1.0 / (0.1 * 0.11), 1e-1);

      final tripleNoPole = (x * Fn.sin(x) * Fn.cos(x)).series('x', order: 5);
      check(tripleNoPole.removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(0.1 * 0.1 - 2.0 / 3.0 * 0.0001, 1e-12);

      final tripleWithPole =
          (x *
                  Fn.sin(x) *
                  Pow.of(
                    x + Pow.of(x, IntegerNumber.two),
                    IntegerNumber.negativeOne,
                  ))
              .series('x', order: 3);
      check(tripleWithPole.removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(0.1 - 0.01, 1e-12);

      // Multi-factor product with pole order loss regression test
      final ps = Expr.parse('exp(x) * sin(x) / x').toPowerSeries('x', order: 3);
      check(ps.toExpr().toString()).equals('1 + x + 1/3 * x ^ 2 + O(x^3)');
      check(ps.poleOrder).equals(0);
    });

    test('expands exponentials, logarithms, and powers', () {
      check(Expr.parse('exp(x)').series('x', order: 4).toString())
          .equals('1 + x + 1/2 * x ^ 2 + 1/6 * x ^ 3 + O(x^4)');
      check(
        Expr.parse('exp(x + 1)')
            .series('x', order: 3)
            .removeOrder()
            .evaluate({'x': 0.0}),
      ).isCloseTo(2.718281828459045, 1e-12);

      check(Expr.parse('ln(1 + x)').series('x', order: 4).toString())
          .equals('x - 1/2 * x ^ 2 + 1/3 * x ^ 3 + O(x^4)');
      check(
        Expr.parse('ln(2 + x)')
            .series('x', order: 3)
            .removeOrder()
            .evaluate({'x': 0.1}),
      ).isCloseTo(0.6931471805599453 + 0.05 - 0.01 / 8.0, 1e-12);

      check(
        Pow.of(
          Fn.sin(x),
          IntegerNumber.of(-2),
        ).series('x', order: 1).removeOrder().evaluate({'x': 0.1}),
      ).isCloseTo(100.0 + 1.0 / 3.0, 1e-12);

      // Pole base raised to positive power preserves requested order:
      final polePow = Pow.of(
        IntegerNumber.one / x + x,
        IntegerNumber.two,
      ).series('x', order: 3);
      check(polePow.toString()).equals('2 + x ^ (-2) + x ^ 2 + O(x^3)');

      check(
        Pow.of(
          IntegerNumber.one + x,
          x,
        ).series('x', order: 3).removeOrder().evaluate({'x': 0.1}),
      ).isCloseTo(1.0 + 0.01, 1e-12);
    });

    test('expands trigonometric, hyperbolic, and inverse functions', () {
      check(Expr.parse('cos(x)').series('x', order: 5).toString())
          .equals('1 - 1/2 * x ^ 2 + 1/24 * x ^ 4 + O(x^5)');
      check(Expr.parse('tan(x)').series('x', order: 4).toString())
          .equals('x + 1/3 * x ^ 3 + O(x^4)');
      check(
        Fn.sin(x)
            .series('x', point: IntegerNumber.one, order: 3)
            .removeOrder()
            .evaluate({'x': 1.05}),
      ).isCloseTo(Fn.sin(x).evaluate({'x': 1.05}), 1e-4);

      check(Fn.sinh(x).series('x', order: 4).toString())
          .equals('x + 1/6 * x ^ 3 + O(x^4)');
      check(Fn.cosh(x).series('x', order: 4).toString())
          .equals('1 + 1/2 * x ^ 2 + O(x^4)');
      check(Fn.tanh(x).series('x', order: 4).toString())
          .equals('x - 1/3 * x ^ 3 + O(x^4)');

      check(Fn.asin(x).series('x', order: 4).toString())
          .equals('x + 1/6 * x ^ 3 + O(x^4)');
      check(Fn.acos(x).series('x', order: 4).removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(1.5707963267948966 - 0.1 - 0.001 / 6.0, 1e-12);
      check(Fn.atan(x).series('x', order: 4).toString())
          .equals('x - 1/3 * x ^ 3 + O(x^4)');

      check(Fn.asinh(x).series('x', order: 4).toString())
          .equals('x - 1/6 * x ^ 3 + O(x^4)');
      check(Fn.atanh(x).series('x', order: 4).toString())
          .equals('x + 1/3 * x ^ 3 + O(x^4)');
      check(
        Fn.acosh(x)
            .series('x', point: IntegerNumber.two, order: 3)
            .removeOrder()
            .evaluate({'x': 2.05}),
      ).isCloseTo(Fn.acosh(x).evaluate({'x': 2.05}), 1e-4);
    });
  });

  group('Special functions, Piecewise, and singularity errors', () {
    test('expands Abs, LambertW, Erf, Erfc, and Piecewise', () {
      check(Fn.abs(x + IntegerNumber.two).series('x', order: 3).removeOrder())
          .equals(IntegerNumber.two + x);
      check(Fn.abs(x - IntegerNumber.two).series('x', order: 3).removeOrder())
          .equals(IntegerNumber.two - x);

      check(Fn.lambertW(x).series('x', order: 4).toString())
          .equals('x - x ^ 2 + 3/2 * x ^ 3 + O(x^4)');
      check(
        Fn.lambertW(x).series('x', point: Constant.e, order: 3).simplify(),
      ).equals(
        Expr.parse('1 + (x - e)/(2*e) - 3*(x - e)^2/(16*e^2) + O((x - e)^3)')
            .simplify(),
      );
      check(() => Expr.parse('asin(x)').series('x', point: 1, order: 3))
          .throws<UnsupportedError>();
      check(() => Expr.parse('atanh(x)').series('x', point: 1, order: 3))
          .throws<UnsupportedError>();
      check(
        () =>
            Fn.lambertW(x)
                .series('x', point: -IntegerNumber.one / Constant.e, order: 3),
      ).throws<UnsupportedError>();

      check(Fn.erf(x).series('x', order: 4).removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(Fn.erf(x).evaluate({'x': 0.1}), 1e-5);
      check(Fn.erfc(x).series('x', order: 4).removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(Fn.erfc(x).evaluate({'x': 0.1}), 1e-5);

      final pw = Piecewise([
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
      ], otherwise: Pow.of(x, IntegerNumber.two));
      check(
        pw
            .series('x', point: IntegerNumber.negativeOne, order: 3)
            .removeOrder(),
      ).equals(IntegerNumber.one - (x - IntegerNumber.negativeOne));
      check(
        pw
            .series('x', point: IntegerNumber.one, order: 3)
            .removeOrder()
            .evaluate({'x': 2.0}),
      ).equals(4.0);

      // Sign, Floor, Ceil, Round at non-singular points
      check(
        Fn.sign(x)
            .series('x', point: IntegerNumber.two, order: 3)
            .removeOrder(),
      ).equals(IntegerNumber.one);
      check(
        Fn.sign(x)
            .series('x', point: IntegerNumber.negativeOne, order: 3)
            .removeOrder(),
      ).equals(IntegerNumber.negativeOne);
      check(
        Fn.floor(x)
            .series('x', point: RationalNumber(3, 2), order: 3)
            .removeOrder(),
      ).equals(IntegerNumber.one);
      check(
        Fn.ceil(x)
            .series('x', point: RationalNumber(6, 5), order: 3)
            .removeOrder(),
      ).equals(IntegerNumber.two);
      check(
        Fn.round(x)
            .series('x', point: RationalNumber(6, 5), order: 3)
            .removeOrder(),
      ).equals(IntegerNumber.one);

      // Gamma, Digamma, Polygamma, Zeta, BesselJ at analytic points
      final gammaS = Fn.gamma(x)
          .toPowerSeries('x', point: IntegerNumber.one, order: 2);
      check(gammaS.coefficients[0]).equals(IntegerNumber.one);
      check(gammaS.coefficients[1]).equals(Fn.digamma(IntegerNumber.one));

      final zetaS = Fn.zeta(x)
          .toPowerSeries('x', point: IntegerNumber.two, order: 1);
      check(zetaS.coefficients[0])
          .equals(Fn.zeta(IntegerNumber.two).simplify());

      check(Fn.besselJ(IntegerNumber.zero, x).series('x', order: 5).toString())
          .equals('1 - 1/4 * x ^ 2 + 1/64 * x ^ 4 + O(x^5)');
      check(Fn.besselJ(IntegerNumber.one, x).series('x', order: 5).toString())
          .equals('1/2 * x - 1/16 * x ^ 3 + O(x^5)');
    });

    test('throws UnsupportedError on singularities and unsupported nodes', () {
      check(() => Pow.of(Constant.e, IntegerNumber.one / x).series('x'))
          .throws<UnsupportedError>();
      check(() => Fn.ln(x).series('x')).throws<UnsupportedError>();
      check(() => Fn.abs(x).series('x')).throws<UnsupportedError>();
      check(() => Fn.lambertW(x, IntegerNumber.negativeOne).series('x'))
          .throws<UnsupportedError>();
      check(() => Fn.acosh(x).series('x')).throws<UnsupportedError>();

      final pw = Piecewise([
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
      ], otherwise: x);
      check(() => pw.series('x', point: IntegerNumber.zero))
          .throws<UnsupportedError>();
      check(() => pw.series('x', point: y)).throws<UnsupportedError>();

      final pwNoOtherwise = Piecewise([
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
      ]);
      check(() => pwNoOtherwise.series('x', point: IntegerNumber.one))
          .throws<UnsupportedError>();

      check(() => Fn.gamma(x).series('x')).throws<UnsupportedError>();
      check(() => Fn.gamma(x).series('x', point: IntegerNumber.negativeOne))
          .throws<UnsupportedError>();
      check(() => Fn.zeta(x).series('x', point: IntegerNumber.one))
          .throws<UnsupportedError>();
      check(() => Fn.sign(x).series('x', point: IntegerNumber.zero))
          .throws<UnsupportedError>();
      check(() => Fn.floor(x).series('x', point: IntegerNumber.one))
          .throws<UnsupportedError>();
      check(() => Fn.ceil(x).series('x', point: IntegerNumber.one))
          .throws<UnsupportedError>();
      check(() => Fn.round(x).series('x', point: RealNumber.fromDouble(1.5)))
          .throws<UnsupportedError>();
      check(
        () => Fn.besselJ(
          FractionNumber.half,
          x,
        ).series('x', point: IntegerNumber.zero),
      ).throws<UnsupportedError>();
      check(() => Fn.beta(x, IntegerNumber.two).series('x'))
          .throws<UnsupportedError>();
      check(() => Relational.lessThan(x, IntegerNumber.zero).series('x'))
          .throws<UnsupportedError>();
      check(() => Integral(Fn.sin(x), 'x').series('x'))
          .throws<UnsupportedError>();
      check(() => OrderTerm('x', 3).series('x')).throws<UnsupportedError>();
      check(() => Fn.sin(x).series('x', point: '??? invalid'))
          .throws<ArgumentError>();
    });

    test('expands with includeOrder: false and int, BigInt, double, and symbolic points', () {
      final sinTaylor = Fn.sin(x).series('x', order: 6, includeOrder: false);
      check(sinTaylor.toString()).equals('x - 1/6 * x ^ 3 + 1/120 * x ^ 5');

      final lnTaylor = Fn.ln(x)
          .series('x', point: 1, order: 4, includeOrder: false);
      check(lnTaylor.evaluate({'x': 1.1}))
          .isCloseTo(0.1 - 0.01 / 2 + 0.001 / 3, 1e-12);

      final bigPoint = (x * x).series(
        'x',
        point: BigInt.two,
        order: 3,
        includeOrder: false,
      );
      check(bigPoint.evaluate({'x': 3.0})).isCloseTo(9.0, 1e-12);

      final rationalCenter = (x * x).series(
        'x',
        point: 0.5,
        order: 3,
        includeOrder: false,
      );
      check(rationalCenter.evaluate({'x': 1.5})).isCloseTo(2.25, 1e-12);

      final realCenter = Fn.sin(x)
          .series('x', point: 3.141592653589793, order: 4, includeOrder: false);
      check(realCenter.evaluate({'x': 3.141592653589793 + 0.1}))
          .isCloseTo(-0.09983341664682815, 1e-5);

      final absPlusPi = Fn.abs(x + Constant.pi)
          .series('x', point: 0, order: 3, includeOrder: false);
      check(absPlusPi).equals(Constant.pi + x);

      final absMinusPi = Fn.abs(x - Constant.pi)
          .series('x', point: 0, order: 3, includeOrder: false);
      check(absMinusPi).equals(Constant.pi - x);
    });
  });

  group('Expr.toPolynomial', () {
    test('exact polynomial recovery around 0.0', () {
      const x = Variable('x');
      // P(x) = 1 + 2x + 3x^2
      final expr =
          IntegerNumber.of(1) +
          (IntegerNumber.of(2) * x) +
          (IntegerNumber.of(3) * x.pow(IntegerNumber.of(2)));
      final poly = expr.toPolynomial<double>('x', order: 2);

      check(poly.degree).equals(2);
      check(poly[0]).isCloseTo(1.0, 1e-9);
      check(poly[1]).isCloseTo(2.0, 1e-9);
      check(poly[2]).isCloseTo(3.0, 1e-9);
    });

    test('Taylor expansion of exp(x) around 0.0', () {
      const x = Variable('x');
      final expr = Pow.of(Constant.e, x);
      final poly = expr.toPolynomial<double>('x', order: 4);

      check(poly.degree).equals(4);
      check(poly[0]).isCloseTo(1.0, 1e-9); // 1/0!
      check(poly[1]).isCloseTo(1.0, 1e-9); // 1/1!
      check(poly[2]).isCloseTo(0.5, 1e-9); // 1/2!
      check(poly[3]).isCloseTo(1.0 / 6.0, 1e-9); // 1/3!
      check(poly[4]).isCloseTo(1.0 / 24.0, 1e-9); // 1/4!

      // Evaluates close to e^0.5
      check(poly.evaluate(0.5)).isCloseTo(1.6484375, 1e-4);
    });

    test('Taylor expansion of sin(x) and cos(x) around 0.0', () {
      const x = Variable('x');
      final sinPoly = Fn.sin(x).toPolynomial<double>('x', order: 5);
      // sin(x) = x - x^3/6 + x^5/120
      check(sinPoly[0]).isCloseTo(0.0, 1e-9);
      check(sinPoly[1]).isCloseTo(1.0, 1e-9);
      check(sinPoly[2]).isCloseTo(0.0, 1e-9);
      check(sinPoly[3]).isCloseTo(-1.0 / 6.0, 1e-9);
      check(sinPoly[4]).isCloseTo(0.0, 1e-9);
      check(sinPoly[5]).isCloseTo(1.0 / 120.0, 1e-9);

      final cosPoly = Fn.cos(x).toPolynomial<double>('x', order: 4);
      // cos(x) = 1 - x^2/2 + x^4/24
      check(cosPoly[0]).isCloseTo(1.0, 1e-9);
      check(cosPoly[1]).isCloseTo(0.0, 1e-9);
      check(cosPoly[2]).isCloseTo(-0.5, 1e-9);
      check(cosPoly[3]).isCloseTo(0.0, 1e-9);
      check(cosPoly[4]).isCloseTo(1.0 / 24.0, 1e-9);
    });

    test('Taylor expansion around non-zero point', () {
      const x = Variable('x');
      // f(x) = (x - 2)^3 = x^3 - 6x^2 + 12x - 8
      final expr = (x - IntegerNumber.of(2)).pow(IntegerNumber.of(3));
      final poly = expr.toPolynomial<double>('x', point: 2.0, order: 3);

      check(poly.degree).equals(3);
      check(poly[0]).isCloseTo(-8.0, 1e-9);
      check(poly[1]).isCloseTo(12.0, 1e-9);
      check(poly[2]).isCloseTo(-6.0, 1e-9);
      check(poly[3]).isCloseTo(1.0, 1e-9);

      check(poly.evaluate(2.0)).isCloseTo(0.0, 1e-9);
      check(poly.evaluate(3.0)).isCloseTo(1.0, 1e-9);
      check(poly.evaluate(4.0)).isCloseTo(8.0, 1e-9);
    });

    test('negative order returns zero polynomial', () {
      const x = Variable('x');
      final poly = Pow.of(Constant.e, x).toPolynomial<double>('x', order: -1);
      check(poly.degree).equals(-1);
    });

    test('handles removable singularities and symbolic Expr coefficients via toPowerSeries', () {
      const x = Variable('x');
      final sinc = Fn.sin(x) / x;
      final poly = sinc.toPolynomial<double>('x', order: 4);
      check(poly.degree).equals(4);
      check(poly[0]).isCloseTo(1.0, 1e-12);
      check(poly[1]).isCloseTo(0.0, 1e-12);
      check(poly[2]).isCloseTo(-1.0 / 6.0, 1e-12);
      check(poly[3]).isCloseTo(0.0, 1e-12);
      check(poly[4]).isCloseTo(1.0 / 120.0, 1e-12);

      final symPoly = sinc.toPolynomial<Expr>(
        'x',
        order: 2,
        type: exprDataType,
      );
      check(symPoly[0]).equals(IntegerNumber.one);
      check(symPoly[1]).equals(IntegerNumber.zero);
      check(symPoly[2]).equals(RationalNumber(-1, 6));

      check(() => (IntegerNumber.one / x).toPolynomial<double>('x', order: 2))
          .throws<UnsupportedError>();

      // toPolynomial<double> with non-Number constant coefficients (Constant.pi) around 0 and 1
      final piPoly0 = (Constant.pi * x).toPolynomial<double>('x', order: 1);
      check(piPoly0[1]).isCloseTo(3.141592653589793, 1e-12);
      final piPoly1 = (Constant.pi * x).toPolynomial<double>(
        'x',
        point: 1.0,
        order: 1,
      );
      check(piPoly1[1]).isCloseTo(3.141592653589793, 1e-12);

      // toPolynomial<Expr> around non-zero point = 1
      final symPoly1 = (x + IntegerNumber.one).toPolynomial<Expr>(
        'x',
        point: 1,
        order: 1,
        type: exprDataType,
      );
      check(symPoly1[0]).equals(IntegerNumber.one);
      check(symPoly1[1]).equals(IntegerNumber.one);
    });

    test('expands special integral and elliptic functions', () {
      const x = Variable('x');
      check(
        Fn.erfi(x)
            .series('x', order: 4, includeOrder: false)
            .expand()
            .simplify(),
      ).equals(
        Expr.parse('2/sqrt(pi)*x + 2/(3*sqrt(pi))*x^3').expand().simplify(),
      );
      check(
        Fn.fresnelS(x).series('x', order: 4, includeOrder: false).simplify(),
      ).equals(Expr.parse('pi/6*x^3').simplify());
      check(
        Fn.fresnelC(x).series('x', order: 2, includeOrder: false).simplify(),
      ).equals(x);
      check(Fn.si(x).series('x', order: 4, includeOrder: false).simplify())
          .equals(Expr.parse('x - x^3/18').simplify());
      check(Fn.shi(x).series('x', order: 4, includeOrder: false).simplify())
          .equals(Expr.parse('x + x^3/18').simplify());
      check(
        Fn.polylog(
          IntegerNumber.two,
          x,
        ).series('x', order: 4, includeOrder: false).simplify(),
      ).equals(Expr.parse('x + x^2/4 + x^3/9').simplify());
      check(
        Fn.ellipticF(
          x,
          FractionNumber.half,
        ).series('x', order: 4, includeOrder: false).simplify(),
      ).equals(Expr.parse('x + x^3/24').simplify());
      check(
        Fn.ellipticE(
          x,
          FractionNumber.half,
        ).series('x', order: 4, includeOrder: false).simplify(),
      ).equals(Expr.parse('x - x^3/24').simplify());
      final kSeries = Fn.ellipticK(x)
          .series('x', order: 5, includeOrder: false)
          .simplify();
      check(kSeries)
          .equals(Expr.parse('pi/2 + pi/8*x^2 + 9*pi/128*x^4').simplify());
      check(kSeries.evaluate({'x': 0.2}))
          .isCloseTo(Fn.ellipticK(const RealNumber(0.2)).evaluate(), 2e-5);
      check(
        Fn.ellipticK(x)
            .series('x', order: 7, includeOrder: false)
            .evaluate({'x': 0.2}),
      ).isCloseTo(Fn.ellipticK(const RealNumber(0.2)).evaluate(), 1e-6);
      final eSeries = Fn.ellipticE(x)
          .series('x', order: 5, includeOrder: false)
          .simplify();
      check(eSeries)
          .equals(Expr.parse('pi/2 - pi/8*x^2 - 3*pi/128*x^4').simplify());
      check(eSeries.evaluate({'x': 0.2}))
          .isCloseTo(Fn.ellipticE(const RealNumber(0.2)).evaluate(), 1e-5);
      check(
        Fn.ellipticE(x)
            .series('x', order: 7, includeOrder: false)
            .evaluate({'x': 0.2}),
      ).isCloseTo(Fn.ellipticE(const RealNumber(0.2)).evaluate(), 1e-6);
      check(
        Fn.ei(x)
            .series('x', point: 1, order: 2, includeOrder: false)
            .simplify(),
      ).equals(Expr.parse('Ei(1) + e*(x - 1)').simplify());
      check(
        Fn.li(x)
            .series('x', point: 2, order: 2, includeOrder: false)
            .simplify(),
      ).equals(Expr.parse('li(2) + (x - 2)/ln(2)').simplify());
      check(
        Fn.ci(x)
            .series('x', point: 1, order: 2, includeOrder: false)
            .simplify(),
      ).equals(Expr.parse('Ci(1) + cos(1)*(x - 1)').simplify());
      check(
        Fn.chi(x)
            .series('x', point: 1, order: 2, includeOrder: false)
            .simplify(),
      ).equals(Expr.parse('Chi(1) + cosh(1)*(x - 1)').simplify());
      check(
        Fn.upperGamma(
          IntegerNumber.two,
          x,
        ).series('x', point: 1, order: 2, includeOrder: false).simplify(),
      ).equals(
        (Fn.upperGamma(IntegerNumber.two, IntegerNumber.one) -
                (x - IntegerNumber.one) / Constant.e)
            .simplify(),
      );
      check(
        Fn.lowerGamma(
          IntegerNumber.two,
          x,
        ).series('x', point: 1, order: 2, includeOrder: false).simplify(),
      ).equals(
        (Fn.lowerGamma(IntegerNumber.two, IntegerNumber.one) +
                (x - IntegerNumber.one) / Constant.e)
            .simplify(),
      );
    });

    test(
      'expands BesselI, Factorial, Beta, and Binomial into Taylor series',
      () {
        const x = Variable('x');
        check(Fn.besselI(IntegerNumber.zero, x).series('x', order: 4)).equals(
          (IntegerNumber.one +
                  RationalNumber(1, 4) * Pow.of(x, IntegerNumber.two) +
                  OrderTerm('x', 4))
              .simplify(),
        );
        check(Fn.factorial(x).series('x', order: 2).toString())
            .equals('1 + x * digamma(1) + O(x^2)');
        check(
          Fn.beta(
            x,
            IntegerNumber.one,
          ).series('x', point: 1, order: 2).toString(),
        ).equals('2 - x + O((x - 1)^2)');
        check(Fn.binomial(x, IntegerNumber.two).series('x', order: 3)).equals(
          (FractionNumber.negativeHalf * x +
                  FractionNumber.half * Pow.of(x, IntegerNumber.two) +
                  OrderTerm('x', 3))
              .simplify(),
        );
      },
    );

    test('expands Maclaurin series for Erf, Erfc, Erfi, Si, Shi, FresnelS, FresnelC', () {
      check(
        (Expr.parse('erf(x)').series('x', order: 4) -
                Expr.parse('2 / sqrt(pi) * x - 2 / (3 * sqrt(pi)) * x^3'))
            .simplify(),
      ).equals(OrderTerm('x', 4));
      check(
        (Expr.parse('erfc(x)').series('x', order: 4) -
                Expr.parse('1 - 2 / sqrt(pi) * x + 2 / (3 * sqrt(pi)) * x^3'))
            .simplify(),
      ).equals(OrderTerm('x', 4));
      check(
        (Expr.parse('erfi(x)').series('x', order: 4) -
                Expr.parse('2 / sqrt(pi) * x + 2 / (3 * sqrt(pi)) * x^3'))
            .simplify(),
      ).equals(OrderTerm('x', 4));
      check(
        (Expr.parse('Si(x)').series('x', order: 4) -
                Expr.parse('x - 1/18 * x^3'))
            .simplify(),
      ).equals(OrderTerm('x', 4));
      check(
        (Expr.parse('Shi(x)').series('x', order: 4) -
                Expr.parse('x + 1/18 * x^3'))
            .simplify(),
      ).equals(OrderTerm('x', 4));
      check(
        (Expr.parse('fresnelS(x)').series('x', order: 4) -
                Expr.parse('1/6 * pi * x^3'))
            .simplify(),
      ).equals(OrderTerm('x', 4));
      check(
        (Expr.parse('fresnelC(x)').series('x', order: 4) - Expr.parse('x'))
            .simplify(),
      ).equals(OrderTerm('x', 4));
    });

    test('handles OrderTerm derivatives, discrete errors, Tan/Tanh poles, and Piecewise', () {
      const x = Variable('x');
      check(OrderTerm('x', 0).derivative('x')).equals(OrderTerm('x', 0));
      check(() => Fn.floor(x).series('x')).throws<UnsupportedError>();
      check(() => Fn.ceil(x).series('x')).throws<UnsupportedError>();
      check(() => Fn.round(x).series('x', point: RationalNumber(1, 2)))
          .throws<UnsupportedError>();
      check(() => Fn.sign(x).series('x')).throws<UnsupportedError>();
      check(
        Expr.parse('1 / cos(x)')
            .series(
              'x',
              point: (Constant.pi / IntegerNumber.two).simplify(),
              order: 2,
            )
            .toString(),
      ).contains('x - 1/2 * pi');
      check(
        Piecewise([
              (
                relation: Relational.greaterThan(x, IntegerNumber.zero),
                expr: Fn.sin(x),
              ),
            ], otherwise: -Fn.sin(x))
            .series('x', point: IntegerNumber.one, order: 3)
            .removeOrder()
            .evaluate({'x': 1.1}),
      ).isCloseTo(math.sin(1.1), 1e-3);
    });

    test('expands shifted SinIntegral/SinhIntegral, zero-leading powers, order-0, and branch singularities', () {
      const x = Variable('x');
      final siShifted = Fn.si(x + IntegerNumber.one).series('x', order: 3);
      check(siShifted.removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(Fn.si(const RealNumber(1.1)).evaluate(), 1e-3);
      final shiShifted = Fn.shi(x + IntegerNumber.one).series('x', order: 3);
      check(shiShifted.removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(Fn.shi(const RealNumber(1.1)).evaluate(), 1e-3);

      final zeroLead = Pow.of(
        IntegerNumber.one - Fn.cos(x),
        FractionNumber.half,
      ).series('x', order: 3);
      check(zeroLead.removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(math.sqrt(1.0 - math.cos(0.1)), 1e-4);

      final ord0 = Fn.si(x).series('x', order: 0);
      check(ord0).equals(OrderTerm('x', 0));
      check(Fn.shi(x).series('x', order: 0)).equals(OrderTerm('x', 0));

      check(() => Fn.sign(const RealNumber(0.0) + x).series('x'))
          .throws<UnsupportedError>();
      check(() => Fn.floor(const RealNumber(1.0) + x).series('x'))
          .throws<UnsupportedError>();
      check(() => Fn.ceil(const RealNumber(1.0) + x).series('x'))
          .throws<UnsupportedError>();
      check(() => Fn.round(const RealNumber(0.5) + x).series('x'))
          .throws<UnsupportedError>();
      check(() => Fn.asin(x).series('x', point: IntegerNumber.one))
          .throws<UnsupportedError>();
      check(() => Fn.acos(x).series('x', point: IntegerNumber.one))
          .throws<UnsupportedError>();

      check(Fn.digamma(x + IntegerNumber.one).series('x', order: 2))
          .isNotNull();
      check(() => Fn.digamma(x - IntegerNumber.one).series('x', order: 2))
          .throws<UnsupportedError>();
      check(
        Fn.polygamma(
          IntegerNumber.one,
          x + IntegerNumber.one,
        ).series('x', order: 2),
      ).isNotNull();
      check(
        () => Fn.polygamma(
          IntegerNumber.one,
          x - IntegerNumber.one,
        ).series('x', order: 2),
      ).throws<UnsupportedError>();
      check(
        Fn.binomial(
          x + IntegerNumber.two,
          x + IntegerNumber.one,
        ).series('x', order: 2),
      ).isNotNull();
      check(() => Fn.atan2(x, -x - IntegerNumber.one).series('x', order: 2))
          .throws<UnsupportedError>();
    });
  });
}
