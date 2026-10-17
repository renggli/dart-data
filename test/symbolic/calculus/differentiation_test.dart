import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const t = Variable('t');

  group('Order validation and base cases', () {
    test('validates derivative order and handles order 0', () {
      check(() => x.derivative('x', order: -1)).throws<RangeError>();
      check(() => x.derivative('x', order: 1001)).throws<RangeError>();
      check((x + x).derivative('x', order: 0)).equals(IntegerNumber.two * x);
    });

    test('handles constants, independent variables, and higher orders', () {
      check(IntegerNumber.of(5).derivative('x')).equals(IntegerNumber.zero);
      check(Constant.pi.derivative('x')).equals(IntegerNumber.zero);
      check(y.derivative('x')).equals(IntegerNumber.zero);
      check(x.derivative('x', order: 3)).equals(IntegerNumber.zero);

      final sum = Add([
        x,
        IntegerNumber.of(5),
        Constant.pi,
        y,
        Sin(y),
        LessThan(x, IntegerNumber.zero),
        LessEqual(x, IntegerNumber.zero),
        GreaterThan(x, IntegerNumber.zero),
        GreaterEqual(x, IntegerNumber.zero),
        Equal(x, IntegerNumber.zero),
      ]);
      check(sum.derivative('x')).equals(IntegerNumber.one);
      check(LessThan(x, IntegerNumber.one).derivative('x'))
          .equals(IntegerNumber.zero);
    });
  });

  group('Arithmetic operators (Add, Mul, Pow, quotients)', () {
    test('differentiates products and quotients', () {
      check(Expr.parse('x^3 - 3*x + 1').derivative('x').toString())
          .equals('-3 + 3 * x ^ 2');
      check(Mul([x]).derivative('x')).equals(IntegerNumber.one);
      check((IntegerNumber.of(3) * y * x).derivative('x'))
          .equals(IntegerNumber.of(3) * y);
      check(
        Expr.parse('2 * x * sin(x) * cos(x)')
            .derivative('x')
            .evaluate({'x': 0.5}),
      ).isCloseTo(2 * 0.5 * math.cos(1.0) + math.sin(1.0), 1e-12);

      check(
        (Sin(x) / x).derivative('x').evaluate({'x': 1.2}),
      ).isCloseTo((1.2 * math.cos(1.2) - math.sin(1.2)) / (1.2 * 1.2), 1e-12);
      check(
        (Sin(x) / Pow(x, IntegerNumber.two)).derivative('x').evaluate({
          'x': 1.2,
        }),
      ).isCloseTo(
        (1.2 * math.cos(1.2) - 2 * math.sin(1.2)) / (1.2 * 1.2 * 1.2),
        1e-12,
      );
      check(
        ((x * Sin(x)) / (Cos(x) * Ln(x))).derivative('x').evaluate({'x': 2.0}),
      ).isCloseTo(
        ((math.sin(2.0) + 2.0 * math.cos(2.0)) *
                    (math.cos(2.0) * math.log(2.0)) -
                (2.0 * math.sin(2.0)) *
                    (-math.sin(2.0) * math.log(2.0) + math.cos(2.0) / 2.0)) /
            math.pow(math.cos(2.0) * math.log(2.0), 2),
        1e-11,
      );
    });

    test('differentiates exponential and generalized power forms', () {
      check(Expr.parse('exp(2*x)').derivative('x').toString())
          .equals('2 * exp(2 * x)');
      check(Pow(IntegerNumber.two, x).derivative('x').evaluate({'x': 3.0}))
          .isCloseTo(8.0 * math.log(2.0), 1e-12);
      check(Pow(x, x).derivative('x').evaluate({'x': 2.0}))
          .isCloseTo(4.0 * (math.log(2.0) + 1.0), 1e-12);
    });
  });

  group('Elementary trigonometric, hyperbolic, and logarithmic functions', () {
    test(
      'differentiates trigonometric and inverse trigonometric functions',
      () {
        check(Tan(x).derivative('x').evaluate({'x': 0.5}))
            .isCloseTo(1.0 / math.pow(math.cos(0.5), 2), 1e-12);
        check(Asin(x).derivative('x').evaluate({'x': 0.5}))
            .isCloseTo(1.0 / math.sqrt(1.0 - 0.25), 1e-12);
        check(Acos(x).derivative('x').evaluate({'x': 0.5}))
            .isCloseTo(-1.0 / math.sqrt(1.0 - 0.25), 1e-12);
        check(Atan(x).derivative('x').evaluate({'x': 1.0}))
            .isCloseTo(0.5, 1e-12);
      },
    );

    test('differentiates hyperbolic and inverse hyperbolic functions', () {
      check(Sinh(x).derivative('x').evaluate({'x': 0.0})).isCloseTo(1.0, 1e-12);
      check(Cosh(x).derivative('x').evaluate({'x': 0.0})).isCloseTo(0.0, 1e-12);
      check(Tanh(x).derivative('x').evaluate({'x': 0.0})).isCloseTo(1.0, 1e-12);
      check(Asinh(x).derivative('x').evaluate({'x': 0.0}))
          .isCloseTo(1.0, 1e-12);
      check(Acosh(x).derivative('x').evaluate({'x': 2.0}))
          .isCloseTo(1.0 / math.sqrt(3.0), 1e-12);
      check(Atanh(x).derivative('x').evaluate({'x': 0.5}))
          .isCloseTo(1.0 / 0.75, 1e-12);
    });

    test('differentiates logarithm and absolute value', () {
      check(Expr.parse('ln(x^2 + 1)').derivative('x').evaluate({'x': 2.0}))
          .isCloseTo(4.0 / 5.0, 1e-12);
      check(Abs(x).derivative('x').evaluate({'x': 3.0})).equals(1.0);
      check(Abs(x).derivative('x').evaluate({'x': -3.0})).equals(-1.0);
    });
  });

  group('Special functions, Piecewise, OrderTerm, and Integral', () {
    test('differentiates Erf, Erfc, LambertW, and rejects Gamma/Beta', () {
      check(Erf(x).derivative('x').evaluate({'x': 0.0}))
          .isCloseTo(2.0 / math.sqrt(math.pi), 1e-12);
      check(Erfc(x).derivative('x').evaluate({'x': 0.0}))
          .isCloseTo(-2.0 / math.sqrt(math.pi), 1e-12);
      check(LambertW(x).derivative('x').evaluate({'x': 1.0}))
          .isCloseTo(0.3618962566348892, 1e-12);
      check(() => Gamma(x).derivative('x')).throws<UnsupportedError>();
      check(() => Beta(x, IntegerNumber.two).derivative('x'))
          .throws<UnsupportedError>();
    });

    test('differentiates OrderTerm and Piecewise nodes', () {
      check(const OrderTerm('x', 4).derivative('x'))
          .equals(const OrderTerm('x', 3));
      check(const OrderTerm('y', 4, point: x).derivative('x'))
          .equals(const OrderTerm('y', 4, point: x));
      check(const OrderTerm('y', 4).derivative('x')).equals(IntegerNumber.zero);

      final pwWithOtherwise = Expr.parse('piecewise(x < 0, -x^2, x^2)')
          .derivative('x');
      check(pwWithOtherwise.evaluate({'x': -2.0})).equals(4.0);
      check(pwWithOtherwise.evaluate({'x': 2.0})).equals(4.0);

      final pwNoOtherwise = Piecewise([
        (LessThan(x, IntegerNumber.zero), -x),
        (GreaterEqual(x, IntegerNumber.zero), x),
      ]).derivative('x');
      check(pwNoOtherwise.evaluate({'x': -2.0})).equals(-1.0);
      check(pwNoOtherwise.evaluate({'x': 2.0})).equals(1.0);
    });

    test(
      'differentiates Integral nodes via Fundamental Theorem and Leibniz rule',
      () {
        final indefSame = Integral(Expr.parse('sin(x^2)'), 'x');
        check(indefSame.derivative('x'))
            .equals(Expr.parse('sin(x^2)').simplify());

        final indefParam = Integral(x * t, 't');
        check(indefParam.derivative('x')).equals(Integral(t, 't'));

        final upperOnly = Integral(
          Sin(t),
          't',
          lower: IntegerNumber.zero,
          upper: x,
        );
        check(upperOnly.derivative('x')).equals(Sin(x));

        final lowerOnly = Integral(
          Sin(t),
          't',
          lower: x,
          upper: IntegerNumber.one,
        );
        check(lowerOnly.derivative('x')).equals((-Sin(x)).simplify());

        final fullLeibniz = Integral(
          x * t,
          't',
          lower: x,
          upper: Pow(x, IntegerNumber.two),
        );
        final dFull = fullLeibniz.derivative('x');
        check(dFull.evaluate({'x': 2.0})).isCloseTo(
          2.0 * 4.0 * 4.0 - 2.0 * 2.0 * 1.0 + 0.5 * (16.0 - 4.0),
          1e-12,
        );
      },
    );
  });
}
