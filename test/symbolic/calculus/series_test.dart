import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('PowerSeries algebra and properties', () {
    test('inspects valuation, poleOrder, leadingTerm, and constantTerm', () {
      final zero = PowerSeries('x', IntegerNumber.zero, const {}, 5);
      check(zero.valuation).equals(5);
      check(zero.poleOrder).equals(0);
      check(zero.leadingTerm).isNull();
      check(zero.constantTerm).equals(IntegerNumber.zero);
      check(zero.toExpr(includeOrder: false)).equals(IntegerNumber.zero);
      check(zero.toExpr()).equals(const OrderTerm('x', 5));

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
      check(laurent.coefficients.containsKey(7)).isFalse();
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
      check(diff.coefficients[0]).isNull();
      check(diff.coefficients[1]).equals(IntegerNumber.two);
      check(diff.coefficients[2]).equals(IntegerNumber.of(-3));

      final neg = -s1;
      check(neg.coefficients[0]).equals(IntegerNumber.negativeOne);
      check(neg.coefficients[1]).equals(IntegerNumber.of(-2));

      check(s1.scale(IntegerNumber.zero).coefficients).isEmpty();
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
        check(zero.pow(FractionNumber.half).coefficients).isEmpty();

        final shifted =
            (Pow(x, IntegerNumber.two) + Pow(x, IntegerNumber.of(3)))
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
          .equals(IntegerNumber.of(3) + const OrderTerm('x', 3));
      check(Constant.pi.series('x', order: 3))
          .equals(Constant.pi + const OrderTerm('x', 3));
      check(y.series('x', order: 3)).equals(y + const OrderTerm('x', 3));
      check(Sin(y).series('x', order: 3))
          .equals(Sin(y) + const OrderTerm('x', 3));
      check(x.series('x', point: IntegerNumber.one, order: 3).toString())
          .equals('1 + (x - 1) + O((x - 1)^3)');

      final laurent = Expr.parse('sin(x) / x^2').series('x', order: 3);
      check(laurent.toString()).equals('1 / x - 1/6 * x + O(x^3)');

      final leftPole = ((IntegerNumber.one / x) * Sin(x)).series('x', order: 3);
      check(leftPole.toString()).equals('1 - 1/6 * x ^ 2 + O(x^3)');

      final bothPoles =
          ((IntegerNumber.one / x) *
                  (IntegerNumber.one / (x + Pow(x, IntegerNumber.two))))
              .series('x', order: 2);
      check(bothPoles.removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(1.0 / (0.1 * 0.11), 1e-1);

      final tripleNoPole = (x * Sin(x) * Cos(x)).series('x', order: 5);
      check(tripleNoPole.removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(0.1 * 0.1 - 2.0 / 3.0 * 0.0001, 1e-12);

      final tripleWithPole =
          (x *
                  Sin(x) *
                  Pow(x + Pow(x, IntegerNumber.two), IntegerNumber.negativeOne))
              .series('x', order: 3);
      check(tripleWithPole.removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(0.1 - 0.01, 1e-12);
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
        Pow(
          Sin(x),
          IntegerNumber.of(-2),
        ).series('x', order: 1).removeOrder().evaluate({'x': 0.1}),
      ).isCloseTo(100.0 + 1.0 / 3.0, 1e-12);

      check(
        Pow(
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
        Sin(x)
            .series('x', point: IntegerNumber.one, order: 3)
            .removeOrder()
            .evaluate({'x': 1.05}),
      ).isCloseTo(Sin(x).evaluate({'x': 1.05}), 1e-4);

      check(Sinh(x).series('x', order: 4).toString())
          .equals('x + 1/6 * x ^ 3 + O(x^4)');
      check(Cosh(x).series('x', order: 4).toString())
          .equals('1 + 1/2 * x ^ 2 + O(x^4)');
      check(Tanh(x).series('x', order: 4).toString())
          .equals('x - 1/3 * x ^ 3 + O(x^4)');

      check(Asin(x).series('x', order: 4).toString())
          .equals('x + 1/6 * x ^ 3 + O(x^4)');
      check(Acos(x).series('x', order: 4).removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(1.5707963267948966 - 0.1 - 0.001 / 6.0, 1e-12);
      check(Atan(x).series('x', order: 4).toString())
          .equals('x - 1/3 * x ^ 3 + O(x^4)');

      check(Asinh(x).series('x', order: 4).toString())
          .equals('x - 1/6 * x ^ 3 + O(x^4)');
      check(Atanh(x).series('x', order: 4).toString())
          .equals('x + 1/3 * x ^ 3 + O(x^4)');
      check(
        Acosh(x)
            .series('x', point: IntegerNumber.two, order: 3)
            .removeOrder()
            .evaluate({'x': 2.05}),
      ).isCloseTo(Acosh(x).evaluate({'x': 2.05}), 1e-4);
    });
  });

  group('Special functions, Piecewise, and singularity errors', () {
    test('expands Abs, LambertW, Erf, Erfc, and Piecewise', () {
      check(Abs(x + IntegerNumber.two).series('x', order: 3).removeOrder())
          .equals(IntegerNumber.two + x);
      check(Abs(x - IntegerNumber.two).series('x', order: 3).removeOrder())
          .equals(IntegerNumber.two - x);

      check(LambertW(x).series('x', order: 4).toString())
          .equals('x - x ^ 2 + 3/2 * x ^ 3 + O(x^4)');

      check(Erf(x).series('x', order: 4).removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(Erf(x).evaluate({'x': 0.1}), 1e-5);
      check(Erfc(x).series('x', order: 4).removeOrder().evaluate({'x': 0.1}))
          .isCloseTo(Erfc(x).evaluate({'x': 0.1}), 1e-5);

      final pw = Piecewise([
        (relation: LessThan(x, IntegerNumber.zero), expr: -x),
      ], otherwise: Pow(x, IntegerNumber.two));
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
    });

    test('throws UnsupportedError on singularities and unsupported nodes', () {
      check(() => Pow(Constant.e, IntegerNumber.one / x).series('x'))
          .throws<UnsupportedError>();
      check(() => Ln(x).series('x')).throws<UnsupportedError>();
      check(() => Abs(x).series('x')).throws<UnsupportedError>();
      check(() => LambertW(x + IntegerNumber.one).series('x'))
          .throws<UnsupportedError>();
      check(() => LambertW(x, branch: -1).series('x'))
          .throws<UnsupportedError>();
      check(() => Acosh(x).series('x')).throws<UnsupportedError>();

      final pw = Piecewise([
        (relation: LessThan(x, IntegerNumber.zero), expr: -x),
      ], otherwise: x);
      check(() => pw.series('x', point: IntegerNumber.zero))
          .throws<UnsupportedError>();
      check(() => pw.series('x', point: y)).throws<UnsupportedError>();

      final pwNoOtherwise = Piecewise([
        (relation: LessThan(x, IntegerNumber.zero), expr: -x),
      ]);
      check(() => pwNoOtherwise.series('x', point: IntegerNumber.one))
          .throws<UnsupportedError>();

      check(() => Gamma(x).series('x')).throws<UnsupportedError>();
      check(() => Beta(x, IntegerNumber.two).series('x'))
          .throws<UnsupportedError>();
      check(() => LessThan(x, IntegerNumber.zero).series('x'))
          .throws<UnsupportedError>();
      check(() => Integral(Sin(x), 'x').series('x')).throws<UnsupportedError>();
      check(() => const OrderTerm('x', 3).series('x'))
          .throws<UnsupportedError>();
      check(() => Sin(x).series('x', point: '??? invalid'))
          .throws<ArgumentError>();
    });

    test('expands with includeOrder: false and int, BigInt, double, and symbolic points', () {
      final sinTaylor = Sin(x).series('x', order: 6, includeOrder: false);
      check(sinTaylor.toString()).equals('x - 1/6 * x ^ 3 + 1/120 * x ^ 5');

      final lnTaylor = Ln(x)
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

      final realCenter = Sin(x)
          .series('x', point: 3.141592653589793, order: 4, includeOrder: false);
      check(realCenter.evaluate({'x': 3.141592653589793 + 0.1}))
          .isCloseTo(-0.09983341664682815, 1e-5);

      final absPlusPi = Abs(x + Constant.pi)
          .series('x', point: 0, order: 3, includeOrder: false);
      check(absPlusPi).equals(Constant.pi + x);

      final absMinusPi = Abs(x - Constant.pi)
          .series('x', point: 0, order: 3, includeOrder: false);
      check(absMinusPi).equals(Constant.pi - x);
    });
  });

  group('Expr.toPolynomial and SymbolicPolynomialFactory', () {
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

      // Verify via SymbolicPolynomialFactory.fromExpr as well
      final polyFactory = SymbolicPolynomialFactory.fromExpr<double>(
        expr,
        'x',
        order: 2,
      );
      check(polyFactory.degree).equals(2);
      check(polyFactory[0]).isCloseTo(1.0, 1e-9);
      check(polyFactory[1]).isCloseTo(2.0, 1e-9);
      check(polyFactory[2]).isCloseTo(3.0, 1e-9);
    });

    test('Taylor expansion of exp(x) around 0.0', () {
      const x = Variable('x');
      final expr = Pow(Constant.e, x);
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
      final sinPoly = Sin(x).toPolynomial<double>('x', order: 5);
      // sin(x) = x - x^3/6 + x^5/120
      check(sinPoly[0]).isCloseTo(0.0, 1e-9);
      check(sinPoly[1]).isCloseTo(1.0, 1e-9);
      check(sinPoly[2]).isCloseTo(0.0, 1e-9);
      check(sinPoly[3]).isCloseTo(-1.0 / 6.0, 1e-9);
      check(sinPoly[4]).isCloseTo(0.0, 1e-9);
      check(sinPoly[5]).isCloseTo(1.0 / 120.0, 1e-9);

      final cosPoly = Cos(x).toPolynomial<double>('x', order: 4);
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
      final poly = Pow(Constant.e, x).toPolynomial<double>('x', order: -1);
      check(poly.degree).equals(-1);
    });

    test('handles removable singularities and symbolic Expr coefficients via toPowerSeries', () {
      const x = Variable('x');
      final sinc = Sin(x) / x;
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
    });
  });
}
