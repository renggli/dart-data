import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Complex evaluation of arithmetic and elementary functions', () {
    test('evaluates arithmetic, powers, and elementary functions in C', () {
      const x = Variable('x');
      check(() => x.evaluateComplex({})).throws<ArgumentError>();

      check(Constant.pi.evaluateComplex()).equals(const Complex(math.pi));
      check(
        (x + ComplexNumber.i * 2).evaluateComplex({'x': const Complex(3, 1)}),
      ).equals(const Complex(3, 3));

      check(
        Pow(x, IntegerNumber.zero).evaluateComplex({'x': const Complex(2, 3)}),
      ).equals(Complex.one);
      check(Pow(IntegerNumber.zero, IntegerNumber.two).evaluateComplex())
          .equals(Complex.zero);
      check(
        Pow(IntegerNumber.zero, IntegerNumber.negativeOne).evaluateComplex().a,
      ).equals(double.infinity);
      check(Pow(IntegerNumber.zero, ComplexNumber.i).evaluateComplex().isNaN)
          .isTrue();
      check(
        Pow(x, IntegerNumber.one).evaluateComplex({'x': const Complex(2, 3)}),
      ).equals(const Complex(2, 3));
      check(
        Pow(x, IntegerNumber.two).evaluateComplex({'x': const Complex(1, 1)}),
      ).equals(const Complex(0, 2));
      check(
        Pow(
          x,
          IntegerNumber.negativeOne,
        ).evaluateComplex({'x': const Complex(0, 1)}),
      ).equals(const Complex(0, -1));
      check(
        Pow(x, IntegerNumber.of(3)).evaluateComplex({'x': const Complex(0, 1)}),
      ).equals(const Complex(0, -1));
      check(
        Pow(
          x,
          IntegerNumber.of(-3),
        ).evaluateComplex({'x': const Complex(0, 1)}),
      ).equals(const Complex(0, 1));
      check(Pow(x, ComplexNumber.i).evaluateComplex({'x': Complex.one}))
          .equals(Complex.one);

      const z = Complex(0.4, 0.3);
      check(Sin(x).evaluateComplex({'x': z})).equals(z.sin());
      check(Cos(x).evaluateComplex({'x': z})).equals(z.cos());
      check(Tan(x).evaluateComplex({'x': z})).equals(z.tan());
      check(Asin(x).evaluateComplex({'x': z})).equals(z.asin());
      check(Acos(x).evaluateComplex({'x': z})).equals(z.acos());
      check(Atan(x).evaluateComplex({'x': z})).equals(z.atan());
      check(Sinh(x).evaluateComplex({'x': z})).equals(z.sinh());
      check(Cosh(x).evaluateComplex({'x': z})).equals(z.cosh());
      check(Tanh(x).evaluateComplex({'x': z})).equals(z.tanh());
      check(Ln(x).evaluateComplex({'x': z})).equals(z.log());
      check(Abs(x).evaluateComplex({'x': const Complex(3, 4)}))
          .equals(const Complex(5));

      final asinhZ = Asinh(x).evaluateComplex({'x': z});
      check(Sinh(x).evaluateComplex({'x': asinhZ}).a).isCloseTo(z.a, 1e-12);
      check(Sinh(x).evaluateComplex({'x': asinhZ}).b).isCloseTo(z.b, 1e-12);

      const z2 = Complex(1.5, 0.5);
      final acoshZ = Acosh(x).evaluateComplex({'x': z2});
      check(Cosh(x).evaluateComplex({'x': acoshZ}).a).isCloseTo(z2.a, 1e-12);
      check(Cosh(x).evaluateComplex({'x': acoshZ}).b).isCloseTo(z2.b, 1e-12);

      final atanhZ = Atanh(x).evaluateComplex({'x': z});
      check(Tanh(x).evaluateComplex({'x': atanhZ}).a).isCloseTo(z.a, 1e-12);
      check(Tanh(x).evaluateComplex({'x': atanhZ}).b).isCloseTo(z.b, 1e-12);
    });
  });

  group('Complex evaluation of special functions, Piecewise, and Integral', () {
    test(
      'evaluates special functions, Piecewise, Integral, and OrderTerm in C',
      () {
        const x = Variable('x');
        const y = Variable('y');
        const realZ = Complex(0.5);
        const nonRealZ = Complex(0.5, 1.0);

        check(Erf(x).evaluateComplex({'x': realZ}).a)
            .isCloseTo(Erf(x).evaluate({'x': 0.5}), 1e-14);
        check(() => Erf(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(Erfc(x).evaluateComplex({'x': realZ}).a)
            .isCloseTo(Erfc(x).evaluate({'x': 0.5}), 1e-14);
        check(() => Erfc(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(Gamma(x).evaluateComplex({'x': const Complex(4.0)}).a)
            .isCloseTo(6.0, 1e-12);
        check(() => Gamma(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(
          Beta(x, y).evaluateComplex({
            'x': const Complex(2.0),
            'y': const Complex(3.0),
          }).a,
        ).isCloseTo(1.0 / 12.0, 1e-12);
        check(() => Beta(x, y).evaluateComplex({'x': nonRealZ, 'y': realZ}))
            .throws<UnsupportedError>();

        check(() => LambertW(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(
          LessThan(
            x,
            IntegerNumber.zero,
          ).evaluateComplex({'x': const Complex(-1)}),
        ).equals(Complex.one);
        check(
          LessEqual(x, IntegerNumber.zero).evaluateComplex({'x': Complex.zero}),
        ).equals(Complex.one);
        check(
          GreaterThan(
            x,
            IntegerNumber.zero,
          ).evaluateComplex({'x': Complex.one}),
        ).equals(Complex.one);
        check(
          GreaterEqual(
            x,
            IntegerNumber.zero,
          ).evaluateComplex({'x': Complex.zero}),
        ).equals(Complex.one);
        check(Equal(x, IntegerNumber.zero).evaluateComplex({'x': Complex.zero}))
            .equals(Complex.one);

        final pw = Piecewise([
          (relation: LessThan(x, IntegerNumber.zero), expr: -x),
        ], otherwise: x);
        check(pw.evaluateComplex({'x': const Complex(-2)}))
            .equals(const Complex(2));
        check(pw.evaluateComplex({'x': const Complex(3)}))
            .equals(const Complex(3));

        final pwNoOtherwise = Piecewise([
          (relation: LessThan(x, IntegerNumber.zero), expr: -x),
        ]);
        check(pwNoOtherwise.evaluateComplex({'x': const Complex(3)}).isNaN)
            .isTrue();

        check(Factorial(x).evaluateComplex({'x': const Complex(5.0)}).a)
            .isCloseTo(120.0, 1e-12);
        check(() => Factorial(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(
          Binomial(x, y).evaluateComplex({
            'x': const Complex(5.0),
            'y': const Complex(2.0),
          }).a,
        ).isCloseTo(10.0, 1e-12);
        check(() => Binomial(x, y).evaluateComplex({'x': nonRealZ, 'y': realZ}))
            .throws<UnsupportedError>();

        check(Floor(x).evaluateComplex({'x': const Complex(3.7)}))
            .equals(const Complex(3.0));
        check(() => Floor(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(Ceil(x).evaluateComplex({'x': const Complex(3.2)}))
            .equals(const Complex(4.0));
        check(() => Ceil(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(Round(x).evaluateComplex({'x': const Complex(3.6)}))
            .equals(const Complex(4.0));
        check(() => Round(x).evaluateComplex({'x': nonRealZ}))
            .throws<UnsupportedError>();

        check(Sign(x).evaluateComplex({'x': Complex.zero}))
            .equals(Complex.zero);
        check(Sign(x).evaluateComplex({'x': const Complex(-3.0)}))
            .equals(const Complex(-1.0));
        check(Sign(x).evaluateComplex({'x': const Complex(3.0, 4.0)}))
            .equals(const Complex(0.6, 0.8));

        check(
          Mod(x, y).evaluateComplex({
            'x': const Complex(17.0),
            'y': const Complex(5.0),
          }),
        ).equals(const Complex(2.0));
        check(() => Mod(x, y).evaluateComplex({'x': nonRealZ, 'y': realZ}))
            .throws<UnsupportedError>();

        check(
          NotEqual(x, IntegerNumber.zero).evaluateComplex({'x': Complex.one}),
        ).equals(Complex.one);

        final defInt = Integral(
          x,
          'x',
          lower: IntegerNumber.zero,
          upper: IntegerNumber.two,
        );
        check(defInt.evaluateComplex().a).isCloseTo(2.0, 1e-12);
        check(Integral(x, 'x').evaluateComplex().isNaN).isTrue();
        check(Derivative(x, 'x').evaluateComplex().isNaN).isTrue();
        check(Limit(x, 'x', IntegerNumber.zero).evaluateComplex().isNaN)
            .isTrue();
        check(const OrderTerm('x', 3).evaluateComplex()).equals(Complex.zero);
      },
    );
  });
}
