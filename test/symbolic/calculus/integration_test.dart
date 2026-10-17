import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  void verifyAntiderivative(
    Expr f, {
    List<double> points = const [0.4, 0.7, 1.3],
  }) {
    final antideriv = f.integrate('x');
    check(antideriv).isNotA<Integral>();
    final diff = antideriv.derivative('x');
    for (final pt in points) {
      check(diff.evaluate({'x': pt})).isCloseTo(f.evaluate({'x': pt}), 1e-8);
    }
  }

  group('Definite integration and bounds handling', () {
    test('validates bounds and handles equal, symbolic, and float bounds', () {
      check(() => x.integrate('x', from: 0)).throws<ArgumentError>();
      check(() => x.integrate('x', to: 1)).throws<ArgumentError>();
      check(x.integrate('x', from: 2, to: 2)).equals(IntegerNumber.zero);

      check(Expr.parse('x^2').integrate('x', from: 0, to: 3))
          .equals(IntegerNumber.of(9));
      check(x.integrate('x', from: 0.0, to: 2.0)).equals(IntegerNumber.two);
      check(x.integrate('x', from: 0.0, to: 0.5)).equals(RationalNumber(1, 8));
      check(x.integrate('x', from: 0.0, to: 0.1234567).evaluate())
          .isCloseTo(0.5 * 0.1234567 * 0.1234567, 1e-12);
      check(x.integrate('x', from: 0.0, to: double.nan).evaluate().isNaN)
          .isTrue();

      final paramDef = (y * x).integrate('x', from: 0, to: 2);
      check(paramDef).equals((IntegerNumber.two * y).simplify());

      final symConstDef = Pow(Constant.e, x).integrate('x', from: 0, to: 1);
      check(symConstDef)
          .equals((IntegerNumber.negativeOne + Constant.e).simplify());

      check(Sin(x).integrate('x', from: 0, to: Constant.pi))
          .equals(IntegerNumber.two);
      check(
        x.integrate('x', from: const Variable('a'), to: const Variable('b')),
      ).equals(
        (FractionNumber.half * Pow(const Variable('b'), IntegerNumber.two) -
                FractionNumber.half *
                    Pow(const Variable('a'), IntegerNumber.two))
            .simplify(),
      );
      check(x.integrate('x', from: BigInt.zero, to: BigInt.two))
          .equals(IntegerNumber.two);
      check(() => x.integrate('x', from: 0, to: 'invalid'))
          .throws<ArgumentError>();
    });

    test('evaluates improper infinite bounds and unevaluated fallbacks', () {
      final expDecay = Expr.parse('exp(-x)')
          .integrate('x', from: 0, to: double.infinity);
      check(expDecay).equals(IntegerNumber.one);

      final symInfDecay = Expr.parse('exp(-x)')
          .integrate('x', from: 0, to: Constant.infinity);
      check(symInfDecay).equals(IntegerNumber.one);

      final symNegInf = Expr.parse('exp(x)')
          .integrate('x', from: -Constant.infinity, to: 0);
      check(symNegInf).equals(IntegerNumber.one);

      final expGrowthLeft = Expr.parse('exp(x)')
          .integrate('x', from: double.negativeInfinity, to: 0);
      check(expGrowthLeft).equals(IntegerNumber.one);

      final revInfinite = Expr.parse('exp(-x)')
          .integrate('x', from: double.infinity, to: 0);
      check(revInfinite).equals(IntegerNumber.negativeOne);

      final revNegInfinite = Expr.parse('exp(x)')
          .integrate('x', from: 0, to: double.negativeInfinity);
      check(revNegInfinite).equals(IntegerNumber.negativeOne);

      final lorentz = Expr.parse('1 / (1 + x^2)')
          .integrate('x', from: double.negativeInfinity, to: double.infinity);
      check(lorentz).equals(Constant.pi);

      final fresnel = Expr.parse('sin(x^2)').integrate('x', from: 0, to: 1);
      check(fresnel).isA<Integral>();
      check(fresnel.evaluate()).isCloseTo(0.3102683017233811, 1e-12);

      final oscImproper = Cos(x).integrate('x', from: 0, to: double.infinity);
      check(oscImproper).isA<Integral>();
    });
  });

  group('Elementary and special function affine antiderivatives', () {
    test('integrates constants, linear terms, and affine unary functions', () {
      check(IntegerNumber.zero.integrate('x')).equals(IntegerNumber.zero);
      check(IntegerNumber.of(5).integrate('x')).equals(IntegerNumber.of(5) * x);
      check(x.integrate('x'))
          .equals((FractionNumber.half * Pow(x, IntegerNumber.two)).simplify());

      final lin = IntegerNumber.two * x + IntegerNumber.one;
      final smallLin = FractionNumber.half * x;
      final largeLin = IntegerNumber.two * x + IntegerNumber.two;

      for (final f in [
        Sin(lin),
        Cos(lin),
        Tan(smallLin),
        Asin(smallLin),
        Acos(smallLin),
        Atan(lin),
        Sinh(lin),
        Cosh(lin),
        Tanh(lin),
        Asinh(lin),
        Atanh(smallLin),
        Abs(lin),
        Ln(lin),
        LambertW(lin),
        Erf(lin),
        Erfc(lin),
      ]) {
        verifyAntiderivative(f, points: const [0.2, 0.5, 0.8]);
      }
      verifyAntiderivative(Acosh(largeLin), points: const [0.5, 1.0, 1.5]);
    });

    test('returns unevaluated Integral for non-linear unary arguments', () {
      final nonLin = Pow(x, IntegerNumber.of(3)) + x;
      for (final f in [
        Sin(nonLin),
        Cos(nonLin),
        Tan(nonLin),
        Asin(nonLin),
        Acos(nonLin),
        Atan(nonLin),
        Sinh(nonLin),
        Cosh(nonLin),
        Tanh(nonLin),
        Asinh(nonLin),
        Acosh(nonLin),
        Atanh(nonLin),
        Abs(nonLin),
        Ln(nonLin),
        LambertW(nonLin),
        Erf(nonLin),
        Erfc(nonLin),
        Gamma(x),
      ]) {
        check(f.integrate('x')).isA<Integral>();
      }
    });
  });

  group('Piecewise, power, exponential, and rational integration', () {
    test('integrates Piecewise expressions with continuity constants', () {
      final pw1 = Piecewise([
        (relation: LessThan(x, IntegerNumber.zero), expr: -x),
        (relation: Equal(x, IntegerNumber.zero), expr: IntegerNumber.zero),
        (relation: LessEqual(x, IntegerNumber.one), expr: x),
        (
          relation: GreaterThan(IntegerNumber.two, x),
          expr: IntegerNumber.two * x,
        ),
        (
          relation: GreaterEqual(IntegerNumber.of(3), x),
          expr: IntegerNumber.of(3),
        ),
        (relation: Equal(x, IntegerNumber.of(4)), expr: x),
      ], otherwise: IntegerNumber.of(5));
      final intPw1 = pw1.integrate('x');
      check(intPw1).isA<Piecewise>();

      final pw2 = Piecewise([
        (relation: LessThan(x, IntegerNumber.zero), expr: -x),
      ], otherwise: x);
      final intPw2 = pw2.integrate('x');
      check(intPw2.evaluate({'x': -2.0})).equals(-2.0);
      check(intPw2.evaluate({'x': 2.0})).equals(2.0);

      final pwNoOth = Piecewise([
        (relation: LessThan(x, IntegerNumber.zero), expr: x),
      ]);
      check(pwNoOth.integrate('x')).isA<Piecewise>();
    });

    test(
      'integrates affine powers, exponentials, and expanded polynomials',
      () {
        final lin = IntegerNumber.two * x + IntegerNumber.one;
        verifyAntiderivative(Pow(lin, IntegerNumber.negativeOne));
        verifyAntiderivative(Pow(lin, IntegerNumber.of(3)));
        verifyAntiderivative(Pow(lin, FractionNumber.half));
        verifyAntiderivative(
          Pow(Pow(x, IntegerNumber.two) + IntegerNumber.one, IntegerNumber.two),
        );
        verifyAntiderivative(Pow(Constant.e, lin));
        verifyAntiderivative(Pow(IntegerNumber.two, lin));
        verifyAntiderivative(Pow(const RealNumber(2.5), lin));

        check(Pow(IntegerNumber.of(-2), x).integrate('x')).isA<Integral>();
        check(Pow(x, x).integrate('x')).isA<Integral>();
      },
    );

    test(
      'integrates rational quotients, inverse trig forms, and long division',
      () {
        final lin = IntegerNumber.two * x + IntegerNumber.one;
        verifyAntiderivative(IntegerNumber.of(3) / lin);
        verifyAntiderivative(IntegerNumber.of(3) / Pow(lin, IntegerNumber.two));
        verifyAntiderivative(IntegerNumber.of(3) / Cosh(lin));
        verifyAntiderivative(
          IntegerNumber.of(3) /
              (IntegerNumber.two +
                  Pow(Constant.e, IntegerNumber.of(4) * x + IntegerNumber.one)),
        );
        verifyAntiderivative(
          IntegerNumber.of(3) /
              Add([
                Pow(Constant.e, IntegerNumber.of(4) * x + IntegerNumber.one),
                IntegerNumber.two,
              ]),
        );

        verifyAntiderivative(
          Cos(x) / (IntegerNumber.one + Pow(Sin(x), IntegerNumber.two)),
        );
        verifyAntiderivative(
          Cos(x) / Add([Pow(Sin(x), IntegerNumber.two), const RealNumber(1.0)]),
        );
        verifyAntiderivative(
          x / (IntegerNumber.one + Pow(x, IntegerNumber.of(4))),
        );
        verifyAntiderivative(
          x / (const RealNumber(1.0) + Pow(x, const RealNumber(4.0))),
        );
        verifyAntiderivative(
          IntegerNumber.one /
              (IntegerNumber.of(4) +
                  IntegerNumber.of(9) * Pow(x, IntegerNumber.two)),
        );
        verifyAntiderivative(
          IntegerNumber.one / (Constant.pi + Pow(x, IntegerNumber.two)),
        );
        verifyAntiderivative(
          IntegerNumber.one /
              (IntegerNumber.one +
                  IntegerNumber.of(4) *
                      Constant.pi *
                      Pow(x, IntegerNumber.two)),
        );
        verifyAntiderivative(
          IntegerNumber.one /
              Add([Pow(x, IntegerNumber.two), const RealNumber(4.0)]),
        );

        verifyAntiderivative(
          Pow(
            IntegerNumber.one - Pow(x, IntegerNumber.two),
            FractionNumber.negativeHalf,
          ),
          points: const [0.2, 0.5, 0.7],
        );
        verifyAntiderivative(
          Pow(
            IntegerNumber.one - Pow(x, IntegerNumber.two),
            const RealNumber(-0.5),
          ),
          points: const [0.2, 0.5, 0.7],
        );
        verifyAntiderivative(
          Pow(x, IntegerNumber.two) /
              Pow(
                IntegerNumber.one - Pow(x, IntegerNumber.of(6)),
                FractionNumber.half,
              ),
          points: const [0.2, 0.5, 0.7],
        );
        verifyAntiderivative(
          x /
              Pow(
                Add([-Pow(x, IntegerNumber.of(4)), const RealNumber(1.0)]),
                const RealNumber(0.5),
              ),
          points: const [0.2, 0.5, 0.7],
        );

        verifyAntiderivative(
          (IntegerNumber.two * x) /
              (Pow(x, IntegerNumber.two) + IntegerNumber.one),
        );
        verifyAntiderivative(
          (Pow(x, IntegerNumber.of(3)) + IntegerNumber.one) /
              (x + IntegerNumber.one),
        );
        verifyAntiderivative(
          (Pow(x, IntegerNumber.two) +
                  IntegerNumber.two * x +
                  IntegerNumber.of(3)) /
              (x + IntegerNumber.one),
        );
      },
    );
  });

  group('Chain-rule substitution and integration by parts', () {
    test('integrates products via chain-rule u-substitution', () {
      check((IntegerNumber.two * y * Sin(x)).integrate('x'))
          .equals((-IntegerNumber.two * y * Cos(x)).simplify());

      final x2 = Pow(x, IntegerNumber.two);
      final x3PlusX = Pow(x, IntegerNumber.of(3)) + x;
      for (final f in [
        x * Cos(x2),
        x * Sin(x2),
        x * Ln(x2),
        x * Tan(x2),
        x * Sinh(x2),
        x * Cosh(x2),
        x * Tanh(x2),
        (IntegerNumber.of(3) * x2 + IntegerNumber.one) * Abs(x3PlusX),
        Cos(x) * Pow(Sin(x), IntegerNumber.of(3)),
        x * Cos(x2) * Pow(Sin(x2), IntegerNumber.negativeOne),
        x * Pow(Constant.e, x2),
        x * Pow(IntegerNumber.two, x2),
        x * Pow(const RealNumber(2.5), x2),
      ]) {
        verifyAntiderivative(f, points: const [0.4, 0.7, 1.1]);
      }
    });

    test('integrates products via linear, cyclic, and higher-degree IBP', () {
      final lin = IntegerNumber.two * x + IntegerNumber.one;
      for (final f in [
        Pow(Constant.e, IntegerNumber.two * x) * Sin(IntegerNumber.of(3) * x),
        Pow(Constant.e, IntegerNumber.two * x) * Cos(IntegerNumber.of(3) * x),
        Sin(IntegerNumber.of(3) * x) * Pow(Constant.e, IntegerNumber.two * x),
        x * Ln(lin),
        x * Pow(Constant.e, lin),
        x * Cos(lin),
        x * Sin(lin),
        x * Sinh(lin),
        x * Cosh(lin),
        x * Pow(IntegerNumber.two, lin),
        x * Pow(const RealNumber(2.5), lin),
        Pow(x, IntegerNumber.two) * Pow(Constant.e, x),
        Pow(x, IntegerNumber.two) * Sin(x),
        Pow(x, IntegerNumber.two) * Cos(x),
        Pow(x, IntegerNumber.two) * Sinh(x),
        Pow(x, IntegerNumber.two) * Cosh(x),
        x * (x + IntegerNumber.one) * Pow(Constant.e, x),
        (Pow(x, IntegerNumber.two) + Sin(x)) * Cos(x),
        (Pow(x, IntegerNumber.two) + IntegerNumber.one) * Sin(x) * Cos(x),
        Pow(x + IntegerNumber.one, IntegerNumber.two) *
            Pow(x + IntegerNumber.two, IntegerNumber.two),
      ]) {
        verifyAntiderivative(f);
      }

      check((Sin(x) * Ln(x)).integrate('x')).isA<Integral>();
    });
  });

  group('Multiple and iterated integration (integrateMultiple)', () {
    test('evaluates iterated indefinite and rectangular definite integrals', () {
      final f = Expr.parse('x * y');
      check(
        f.integrateMultiple([
          (variable: 'x', from: null, to: null),
          (variable: 'y', from: null, to: null),
        ]),
      ).equals(Expr.parse('1/4 * x^2 * y^2').simplify());

      // \int_0^2 \int_0^3 (x^2 + y) dx dy = \int_0^2 (9 + 3*y) dy = 18 + 6 = 24
      final rect = Expr.parse('x^2 + y').integrateMultiple([
        (variable: 'x', from: 0, to: 3),
        (variable: 'y', from: 0, to: 2),
      ]);
      check(rect).equals(IntegerNumber.of(24));
    });

    test(
      'evaluates non-rectangular variable-bound double and triple integrals',
      () {
        // \int_0^1 \int_0^x (x * y) dy dx = \int_0^1 (1/2 * x^3) dx = 1/8
        final triangle = Expr.parse('x * y').integrateMultiple([
          (variable: 'y', from: 0, to: x),
          (variable: 'x', from: 0, to: 1),
        ]);
        check(triangle).equals(RationalNumber(1, 8));

        // Volume of unit simplex: \int_0^1 \int_0^{1-x} \int_0^{1-x-y} 1 dz dy dx = 1/6
        final simplexVolume = IntegerNumber.one.integrateMultiple([
          (variable: 'z', from: 0, to: IntegerNumber.one - x - y),
          (variable: 'y', from: 0, to: IntegerNumber.one - x),
          (variable: 'x', from: 0, to: 1),
        ]);
        check(simplexVolume).equals(RationalNumber(1, 6));
      },
    );

    test('handles mixed closed-form and unevaluated nested integrals', () {
      // Separable integral where inner has no elementary antiderivative:
      // \int_0^2 \int_0^1 sin(x^2) dx dy = 2 * \int_0^1 sin(x^2) dx
      final separable = Expr.parse('sin(x^2)').integrateMultiple([
        (variable: 'x', from: 0, to: 1),
        (variable: 'y', from: 0, to: 2),
      ]);
      check(separable).equals(
        (IntegerNumber.two *
                Expr.parse('sin(x^2)').integrate('x', from: 0, to: 1))
            .simplify(),
      );
      check(separable.evaluate()).isCloseTo(2 * 0.3102683017233811, 1e-12);

      // Non-separable double integral evaluated numerically via nested Gauss-Legendre
      final nested = Expr.parse('cos(x * y)').integrateMultiple([
        (variable: 'y', from: 0, to: 1),
        (variable: 'x', from: 0, to: 1),
      ]);
      check(nested).isA<Integral>();
      // \int_0^1 \int_0^1 cos(x*y) dy dx = \int_0^1 sin(x)/x dx = Si(1) \approx 0.946083070367
      check(nested.evaluate()).isCloseTo(0.946083070367183, 1e-12);
    });
  });
}
