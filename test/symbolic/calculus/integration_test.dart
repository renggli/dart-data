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
        verifyAntiderivative(Pow(Tanh(lin), IntegerNumber.two));
        verifyAntiderivative(Pow(Sinh(lin), IntegerNumber.of(3)));
        verifyAntiderivative(Pow(Cosh(lin), IntegerNumber.of(3)));
        verifyAntiderivative(Pow(Sinh(lin), IntegerNumber.of(4)));
        verifyAntiderivative(Pow(Cosh(lin), IntegerNumber.of(4)));

        // Negative float powers:
        check(Expr.parse('x^(-1.0)').integrate('x')).equals(Ln(x));

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
        verifyAntiderivative(
          Expr.parse('1 / (x^2 - 1)'),
          points: const [1.5, 2.0, 2.5],
        );
        verifyAntiderivative(
          Expr.parse('(2*x + 3) / (x^2 + 2*x + 1)'),
          points: const [0.5, 1.0, 1.5],
        );
        verifyAntiderivative(
          Expr.parse('1 / (x^2 + 2*x + 1)'),
          points: const [0.5, 1.0, 1.5],
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

      // Chain rule power u-substitution with power -1 (such as 1/(x * ln(x))):
      final xLnX = Expr.parse('1/(x * ln(x))').integrate('x');
      check(xLnX).equals(Ln(Ln(x)));
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

      // Non-separable double integral reducing to Si(1)
      final nested = Expr.parse('cos(x * y)').integrateMultiple([
        (variable: 'y', from: 0, to: 1),
        (variable: 'x', from: 0, to: 1),
      ]);
      check(nested).equals(SinIntegralSi(IntegerNumber.one));
      // \int_0^1 \int_0^1 cos(x*y) dy dx = \int_0^1 sin(x)/x dx = Si(1) \approx 0.946083070367
      check(nested.evaluate()).isCloseTo(0.946083070367183, 1e-12);

      // Genuinely unevaluated double integral evaluated numerically via nested Gauss-Legendre
      final nestedNum = Expr.parse('cos(x * y^2)').integrateMultiple([
        (variable: 'y', from: 0, to: 1),
        (variable: 'x', from: 0, to: 1),
      ]);
      check(nestedNum).isA<Integral>();
      check(nestedNum.evaluate()).isCloseTo(0.9675774909926477, 1e-9);
    });
  });

  group('Elementary integrals', () {
    test('standard trigonometric powers: sin^2, cos^2, tan^2', () {
      verifyAntiderivative(Expr.parse('sin(x)^2'));
      verifyAntiderivative(Expr.parse('cos(x)^2'));
      verifyAntiderivative(Expr.parse('tan(x)^2'), points: [0.1, 0.3, 0.5]);
    });

    test('trigonometric products: sin(ax) * cos(bx)', () {
      verifyAntiderivative(Expr.parse('sin(2*x) * cos(3*x)'));
      verifyAntiderivative(Expr.parse('sin(3*x) * sin(5*x)'));
      verifyAntiderivative(Expr.parse('cos(2*x) * cos(4*x)'));
    });

    test('secant and cosecant: 1 / cos(x), 1 / sin(x)', () {
      verifyAntiderivative(Expr.parse('1 / cos(x)'), points: [0.1, 0.3, 0.5]);
      verifyAntiderivative(Expr.parse('1 / sin(x)'), points: [0.5, 0.8, 1.2]);
    });

    test('quadratic denominators and completing the square', () {
      // Delta > 0: 1 / (x^2 + x + 1)
      verifyAntiderivative(Expr.parse('1 / (x^2 + x + 1)'));
      // Delta = 0: 1 / (x^2 + 2*x + 1)
      verifyAntiderivative(Expr.parse('1 / (x^2 + 2*x + 1)'));
      // Delta < 0: 1 / (x^2 + x - 2)
      verifyAntiderivative(
        Expr.parse('1 / (x^2 + x - 2)'),
        points: [0.1, 0.3, 0.5],
      );
    });

    test('inverse sine with general constant: 1 / sqrt(a - x^2)', () {
      verifyAntiderivative(
        Expr.parse('1 / sqrt(4 - x^2)'),
        points: [0.2, 0.5, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('1 / sqrt(9 - x^2)'),
        points: [0.5, 1.0, 2.0],
      );
    });

    test('chain-rule forms: ln(x)/x and sinh(x)*cosh(x)', () {
      verifyAntiderivative(Expr.parse('ln(x) / x'), points: [0.5, 1.0, 2.0]);
      verifyAntiderivative(Expr.parse('sinh(x) * cosh(x)'));
    });

    test('Gaussian antiderivatives, higher trig powers, sec^2/csc^2, and radical quadratics', () {
      verifyAntiderivative(Expr.parse('exp(-x^2)'));
      verifyAntiderivative(Expr.parse('exp(-3 * x^2 + 2 * x - 1)'));
      verifyAntiderivative(Expr.parse('x^2 * exp(-x^2)'));
      verifyAntiderivative(Expr.parse('x^4 * exp(-x^2)'));
      verifyAntiderivative(Expr.parse('sin(x)^3'));
      verifyAntiderivative(Expr.parse('cos(x)^3'));
      verifyAntiderivative(Expr.parse('sin(x)^4'));
      verifyAntiderivative(Expr.parse('cos(x)^4'));
      verifyAntiderivative(
        Expr.parse('1 / cos(2 * x)^2'),
        points: const [0.1, 0.2, 0.3],
      );
      verifyAntiderivative(
        Expr.parse('1 / sin(2 * x)^2'),
        points: const [0.2, 0.4, 0.6],
      );
      verifyAntiderivative(
        Expr.parse('sqrt(4 - x^2)'),
        points: const [0.2, 0.5, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('sqrt(4 + x^2)'),
        points: const [0.2, 0.5, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('sqrt(x^2 - 4)'),
        points: const [2.5, 3.0, 4.0],
      );
      verifyAntiderivative(
        Expr.parse('1 / sqrt(4 + x^2)'),
        points: const [0.2, 0.5, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('1 / sqrt(x^2 - 4)'),
        points: const [2.5, 3.0, 4.0],
      );
      verifyAntiderivative(
        Expr.parse('x^2 * ln(x)'),
        points: const [0.5, 1.0, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('x^3 * ln(2 * x + 1)'),
        points: const [0.5, 1.0, 2.0],
      );

      // Hyperbolic squared integrals (sech^2, csch^2)
      check(Expr.parse('sech(2 * x + 1)^2').integrate('x'))
          .equals(Expr.parse('tanh(2 * x + 1) / 2').simplify());
      check(Expr.parse('csch(3 * x - 1)^2').integrate('x'))
          .equals(Expr.parse('-coth(3 * x - 1) / 3').simplify());
    });
  });

  group('Parametric and completed-square quadratic radicals', () {
    void verifyParametric(
      String source, {
      Map<String, double> params = const {'a': 2.3, 'b': 1.7, 'c': 3.1},
      List<double> points = const [0.3, 0.7, 1.1],
    }) {
      final f = Expr.parse(source);
      final antideriv = f.integrate('x');
      check(antideriv).isNotA<Integral>();
      final diff = antideriv.derivative('x');
      for (final pt in points) {
        final env = {...params, 'x': pt};
        check(diff.evaluate(env)).isCloseTo(f.evaluate(env), 1e-8);
      }
    }

    test('integrates parametric quadratic denominators and radicals', () {
      verifyParametric('1 / (a^2 + x^2)');
      verifyParametric('1 / (a + b * x^2)');
      verifyParametric('1 / (a * x^2 + b * x + c)');
      verifyParametric('1 / sqrt(a^2 - x^2)');
      verifyParametric('(a^2 - x^2)^(5/2)');
    });

    test(
      'integrates completed-square and higher-half-power quadratic radicals',
      () {
        verifyAntiderivative(
          Expr.parse('1 / sqrt(-x^2 - 2 * x + 1)'),
          points: const [-0.5, 0.0, 0.2],
        );
        verifyAntiderivative(
          Expr.parse('(x^2 + 1)^(-3/2)'),
          points: const [0.2, 0.7, 1.5],
        );
        verifyAntiderivative(
          Expr.parse('(4 * x^2 - 25)^(-3/2)'),
          points: const [3.0, 4.0, 5.0],
        );
        verifyAntiderivative(
          Expr.parse('(2 * x + 3) / sqrt(x^2 + 4 * x + 5)'),
          points: const [0.2, 0.7, 1.5],
        );
      },
    );
  });

  group('Affine radical and binomial substitutions', () {
    test('integrates affine radical products and quotients', () {
      verifyAntiderivative(
        Expr.parse('x * sqrt(3 * x + 1)'),
        points: const [0.3, 1.0, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('x^2 * sqrt(x + 1)'),
        points: const [0.3, 1.0, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('x / sqrt(2 - 3 * x)'),
        points: const [-1.0, -0.5, 0.2],
      );
      verifyAntiderivative(
        Expr.parse('x * (x - 1)^(1/3)'),
        points: const [1.5, 2.0, 3.0],
      );
      verifyAntiderivative(
        Expr.parse('(3 * x - 5)^2 / (2 * x - 1)^(7/2)'),
        points: const [1.0, 1.5, 2.5],
      );
    });

    test(
      'integrates Chebyshev binomials and transcendental affine radicals',
      () {
        verifyAntiderivative(
          Expr.parse('x^5 / sqrt(x^2 + 5)'),
          points: const [0.4, 1.0, 2.0],
        );
        verifyAntiderivative(
          Expr.parse('exp(sqrt(x))'),
          points: const [0.4, 1.0, 2.0],
        );
        verifyAntiderivative(
          Expr.parse('sin((x - 1)^(1/4))'),
          points: const [1.5, 2.0, 3.0],
        );
      },
    );
  });

  group('General u-substitution', () {
    test(
      'integrates composite trig, log, exp, and symbolic power integrands',
      () {
        verifyAntiderivative(
          Expr.parse('sin(x) / sqrt(cos(x)^3)'),
          points: const [0.2, 0.5, 1.0],
        );
        verifyAntiderivative(
          Expr.parse('sqrt(3 * cos(x)^2 + 1) * sin(2 * x)'),
          points: const [0.2, 0.5, 1.0],
        );
        verifyAntiderivative(
          Expr.parse('ln(x) / (x * sqrt(ln(x) + 1))'),
          points: const [1.2, 2.0, 3.0],
        );
        verifyAntiderivative(
          Expr.parse('exp(x) / (exp(2 * x) + 1)'),
          points: const [0.2, 0.5, 1.0],
        );

        final expHyper = Expr.parse('1 / (2 * exp(m * x) - 5 * exp(-m * x))');
        final expHyperInt = expHyper.integrate('x');
        check(expHyperInt).isNotA<Integral>();
        final expHyperDiff = expHyperInt.derivative('x');
        for (final pt in const [0.3, 0.7, 1.2]) {
          final env = {'m': 1.5, 'x': pt};
          check(expHyperDiff.evaluate(env))
              .isCloseTo(expHyper.evaluate(env), 1e-8);
        }

        final symPow = Expr.parse('x^(n - 1) * sin(x^n)');
        final symPowInt = symPow.integrate('x');
        check(symPowInt).isNotA<Integral>();
        final symPowDiff = symPowInt.derivative('x');
        for (final pt in const [0.4, 0.9, 1.5]) {
          final env = {'n': 2.5, 'x': pt};
          check(symPowDiff.evaluate(env)).isCloseTo(symPow.evaluate(env), 1e-8);
        }
      },
    );
  });

  group('Trigonometric powers, quotients, and Weierstrass substitution', () {
    test('integrates tan, cot, csch, and sech powers', () {
      verifyAntiderivative(
        Expr.parse('tan(x)^4'),
        points: const [0.2, 0.5, 0.9],
      );
      verifyAntiderivative(
        Expr.parse('cot(x)^2'),
        points: const [0.3, 0.7, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('cot(x)^4'),
        points: const [0.3, 0.7, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('csch(x)'),
        points: const [0.4, 0.9, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('cosh(x)^(-5)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('sin(x)^3 * cos(x)^2'),
        points: const [0.2, 0.6, 1.0],
      );
    });

    test(
      'integrates linear trig denominators via Weierstrass substitution',
      () {
        verifyAntiderivative(
          Expr.parse('1 / (sin(x) + cos(x))'),
          points: const [0.2, 0.6, 1.0],
        );
        verifyAntiderivative(
          Expr.parse('1 / (4 * sin(x) + 3 * cos(x) + 3)'),
          points: const [0.2, 0.6, 1.0],
        );
        verifyAntiderivative(
          Expr.parse('3 / (5 - 4 * cos(x))'),
          points: const [0.2, 0.6, 1.0],
        );

        final paramTrig = Expr.parse('1 / (a + b * cos(x))');
        final paramTrigInt = paramTrig.integrate('x');
        check(paramTrigInt).isNotA<Integral>();
        final paramTrigDiff = paramTrigInt.derivative('x');
        for (final pt in const [0.2, 0.6, 1.0]) {
          final env = {'a': 3.0, 'b': 1.5, 'x': pt};
          check(paramTrigDiff.evaluate(env))
              .isCloseTo(paramTrig.evaluate(env), 1e-8);
        }
      },
    );
  });

  group('LIATE integration by parts (log powers, inverse trig, and poly * trig powers)', () {
    test('integrates powers of logarithms and symbolic power * ln', () {
      verifyAntiderivative(
        Expr.parse('ln(x)^2'),
        points: const [0.5, 1.2, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('x^2 * ln(x)^2'),
        points: const [0.5, 1.2, 2.0],
      );

      final symLn = Expr.parse('x^n * ln(a * x)');
      final symLnInt = symLn.integrate('x');
      check(symLnInt).isNotA<Integral>();
      final symLnDiff = symLnInt.derivative('x');
      for (final pt in const [0.5, 1.2, 2.0]) {
        final env = {'a': 2.0, 'n': 2.5, 'x': pt};
        check(symLnDiff.evaluate(env)).isCloseTo(symLn.evaluate(env), 1e-8);
      }
    });

    test('integrates inverse trig functions, squares, and products', () {
      verifyAntiderivative(
        Expr.parse('acot(x)'),
        points: const [0.4, 0.9, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('asec(x)'),
        points: const [1.5, 2.0, 3.0],
      );
      verifyAntiderivative(
        Expr.parse('x * atan(x)'),
        points: const [0.3, 0.7, 1.2],
      );
      verifyAntiderivative(
        Expr.parse('x^2 * acos(x)'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('asin(x)^2'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('asin(x) / x^2'),
        points: const [0.2, 0.5, 0.8],
      );
    });

    test('integrates polynomials times trig powers and products', () {
      verifyAntiderivative(
        Expr.parse('x * sin(x)^2'),
        points: const [0.2, 0.7, 1.3],
      );
      verifyAntiderivative(
        Expr.parse('x * sin(x) * cos(x)'),
        points: const [0.2, 0.7, 1.3],
      );
    });
  });

  group('Repeated quadratic and cyclotomic rational integration', () {
    test('integrates repeated irreducible quadratic denominators', () {
      verifyAntiderivative(
        Expr.parse('1 / (x^2 + 1)^2'),
        points: const [0.2, 0.7, 1.3],
      );
      verifyAntiderivative(
        Expr.parse('x^2 / (x^2 + 1)^2'),
        points: const [0.2, 0.7, 1.3],
      );
      verifyAntiderivative(
        Expr.parse('1 / (x^2 + 2 * x + 5)^2'),
        points: const [0.2, 0.7, 1.3],
      );
    });

    test(
      'integrates cyclotomic cubic/quartic denominators and guards high degree',
      () {
        verifyAntiderivative(
          Expr.parse('x / (x^3 + 1)'),
          points: const [0.2, 0.7, 1.3],
        );
        verifyAntiderivative(
          Expr.parse('1 / (x^4 + 1)'),
          points: const [0.2, 0.7, 1.3],
        );

        final highDeg = Expr.parse('(2 * x^2022 + 1) / (x^2023 + x)');
        check(highDeg.integrate('x').toString()).contains('integrate(');
      },
    );
  });

  group('Special integral function antiderivatives', () {
    test('integrates exp(x^2), sin(x)/x, cos(x)/x, exp(x)/x, 1/ln(x), and special functions', () {
      verifyAntiderivative(
        Expr.parse('exp(x^2)'),
        points: const [0.2, 0.5, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('sin(2 * x) / x'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('cos(2 * x) / x'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('exp(2 * x) / x'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('1 / ln(2 * x + 1)'),
        points: const [0.5, 1.0, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('Ei(2 * x)'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('Si(2 * x)'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('fresnels(2 * x)'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('fresnelc(2 * x)'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('exp(2 * x^2 + 4 * x + 1)'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('sinh(2 * x) / x'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('cosh(2 * x) / x'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('erfi(2 * x)'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('li(2 * x)'),
        points: const [1.2, 2.0, 3.0],
      );
      verifyAntiderivative(
        Expr.parse('Ci(2 * x)'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('Shi(2 * x)'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('Chi(2 * x)'),
        points: const [0.3, 0.8, 1.5],
      );
    });
  });
}
