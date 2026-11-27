import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

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
      check(
        x.integrate('x'),
      ).equals((FractionNumber.half * Pow.of(x, IntegerNumber.two)).simplify());

      final lin = IntegerNumber.two * x + IntegerNumber.one;
      final smallLin = FractionNumber.half * x;
      final largeLin = IntegerNumber.two * x + IntegerNumber.two;

      for (final f in [
        Fn.sin(lin),
        Fn.cos(lin),
        Fn.tan(smallLin),
        Fn.asin(smallLin),
        Fn.acos(smallLin),
        Fn.atan(lin),
        Fn.sinh(lin),
        Fn.cosh(lin),
        Fn.tanh(lin),
        Fn.asinh(lin),
        Fn.atanh(smallLin),
        Fn.abs(lin),
        Fn.ln(lin),
        Fn.lambertW(lin),
        Fn.erf(lin),
        Fn.erfc(lin),
      ]) {
        verifyAntiderivative(f, points: const [0.2, 0.5, 0.8]);
      }
      verifyAntiderivative(Fn.acosh(largeLin), points: const [0.5, 1.0, 1.5]);
    });

    test('returns unevaluated Integral for non-linear unary arguments', () {
      final nonLin = Pow.of(x, IntegerNumber.of(3)) + x;
      for (final f in [
        Fn.sin(nonLin),
        Fn.cos(nonLin),
        Fn.tan(nonLin),
        Fn.asin(nonLin),
        Fn.acos(nonLin),
        Fn.atan(nonLin),
        Fn.sinh(nonLin),
        Fn.cosh(nonLin),
        Fn.tanh(nonLin),
        Fn.asinh(nonLin),
        Fn.acosh(nonLin),
        Fn.atanh(nonLin),
        Fn.abs(nonLin),
        Fn.ln(Fn.sin(x * x)),
        Fn.lambertW(nonLin),
        Fn.erf(nonLin),
        Fn.erfc(nonLin),
        Fn.gamma(x),
      ]) {
        check(f.integrate('x')).isA<Integral>();
      }
    });
  });

  group('Piecewise, power, exponential, and rational integration', () {
    test('integrates Piecewise expressions with continuity constants', () {
      final pw1 = Piecewise([
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
        (
          relation: Relational.equal(x, IntegerNumber.zero),
          expr: IntegerNumber.zero,
        ),
        (relation: Relational.lessEqual(x, IntegerNumber.one), expr: x),
        (
          relation: Relational.greaterThan(IntegerNumber.two, x),
          expr: IntegerNumber.two * x,
        ),
        (
          relation: Relational.greaterEqual(IntegerNumber.of(3), x),
          expr: IntegerNumber.of(3),
        ),
        (relation: Relational.equal(x, IntegerNumber.of(4)), expr: x),
      ], otherwise: IntegerNumber.of(5));
      final intPw1 = pw1.integrate('x');
      check(intPw1).isA<Piecewise>();

      final pw2 = Piecewise([
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
      ], otherwise: x);
      final intPw2 = pw2.integrate('x');
      check(intPw2.evaluate({'x': -2.0})).equals(-2.0);
      check(intPw2.evaluate({'x': 2.0})).equals(2.0);

      final pwNoOth = Piecewise([
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: x),
      ]);
      check(pwNoOth.integrate('x')).isA<Piecewise>();
    });

    test(
      'integrates affine powers, exponentials, and expanded polynomials',
      () {
        final lin = IntegerNumber.two * x + IntegerNumber.one;
        verifyAntiderivative(Pow.of(lin, IntegerNumber.negativeOne));
        verifyAntiderivative(Pow.of(lin, IntegerNumber.of(3)));
        verifyAntiderivative(Pow.of(lin, FractionNumber.half));
        verifyAntiderivative(
          Pow.of(
            Pow.of(x, IntegerNumber.two) + IntegerNumber.one,
            IntegerNumber.two,
          ),
        );
        verifyAntiderivative(Pow.of(Constant.e, lin));
        verifyAntiderivative(Pow.of(IntegerNumber.two, lin));
        verifyAntiderivative(Pow.of(const RealNumber(2.5), lin));
        verifyAntiderivative(Pow.of(Fn.tanh(lin), IntegerNumber.two));
        verifyAntiderivative(Pow.of(Fn.sinh(lin), IntegerNumber.of(3)));
        verifyAntiderivative(Pow.of(Fn.cosh(lin), IntegerNumber.of(3)));
        verifyAntiderivative(Pow.of(Fn.sinh(lin), IntegerNumber.of(4)));
        verifyAntiderivative(Pow.of(Fn.cosh(lin), IntegerNumber.of(4)));

        // Negative float powers:
        check(Expr.parse('x^(-1.0)').integrate('x')).equals(Fn.ln(Fn.abs(x)));
        check(Expr.parse('1/x').integrate('x'))
            .equals(Expr.parse('ln(abs(x))'));
        check(
          Expr.parse('1/x').integrate(
            'x',
            assumptions: Assumptions.none.copyWith(
              domains: {'x': VariableDomain.positive},
            ),
          ),
        ).equals(Expr.parse('ln(x)'));
        check(Expr.parse('tan(x)').integrate('x'))
            .equals(Expr.parse('-ln(abs(cos(x)))').simplify());

        check(Pow.of(IntegerNumber.of(-2), x).integrate('x')).isA<Integral>();
        check(Pow.of(x, x).integrate('x')).isA<Integral>();
      },
    );

    test(
      'integrates rational quotients, inverse trig forms, and long division',
      () {
        final lin = IntegerNumber.two * x + IntegerNumber.one;
        verifyAntiderivative(IntegerNumber.of(3) / lin);
        verifyAntiderivative(
          IntegerNumber.of(3) / Pow.of(lin, IntegerNumber.two),
        );
        verifyAntiderivative(IntegerNumber.of(3) / Fn.cosh(lin));
        verifyAntiderivative(
          IntegerNumber.of(3) /
              (IntegerNumber.two +
                  Pow.of(
                    Constant.e,
                    IntegerNumber.of(4) * x + IntegerNumber.one,
                  )),
        );
        verifyAntiderivative(
          IntegerNumber.of(3) /
              Add.of([
                Pow.of(Constant.e, IntegerNumber.of(4) * x + IntegerNumber.one),
                IntegerNumber.two,
              ]),
        );

        verifyAntiderivative(
          Fn.cos(x) /
              (IntegerNumber.one + Pow.of(Fn.sin(x), IntegerNumber.two)),
        );
        verifyAntiderivative(
          Fn.cos(x) /
              Add.of([
                Pow.of(Fn.sin(x), IntegerNumber.two),
                const RealNumber(1.0),
              ]),
        );
        verifyAntiderivative(
          x / (IntegerNumber.one + Pow.of(x, IntegerNumber.of(4))),
        );
        verifyAntiderivative(
          x / (const RealNumber(1.0) + Pow.of(x, const RealNumber(4.0))),
        );
        verifyAntiderivative(
          IntegerNumber.one /
              (IntegerNumber.of(4) +
                  IntegerNumber.of(9) * Pow.of(x, IntegerNumber.two)),
        );
        verifyAntiderivative(
          IntegerNumber.one / (Constant.pi + Pow.of(x, IntegerNumber.two)),
        );
        verifyAntiderivative(
          IntegerNumber.one /
              (IntegerNumber.one +
                  IntegerNumber.of(4) *
                      Constant.pi *
                      Pow.of(x, IntegerNumber.two)),
        );
        verifyAntiderivative(
          IntegerNumber.one /
              Add.of([Pow.of(x, IntegerNumber.two), const RealNumber(4.0)]),
        );

        verifyAntiderivative(
          Pow.of(
            IntegerNumber.one - Pow.of(x, IntegerNumber.two),
            FractionNumber.negativeHalf,
          ),
          points: const [0.2, 0.5, 0.7],
        );
        verifyAntiderivative(
          Pow.of(
            IntegerNumber.one - Pow.of(x, IntegerNumber.two),
            const RealNumber(-0.5),
          ),
          points: const [0.2, 0.5, 0.7],
        );
        verifyAntiderivative(
          Pow.of(x, IntegerNumber.two) /
              Pow.of(
                IntegerNumber.one - Pow.of(x, IntegerNumber.of(6)),
                FractionNumber.half,
              ),
          points: const [0.2, 0.5, 0.7],
        );
        verifyAntiderivative(
          x /
              Pow.of(
                Add.of([
                  -Pow.of(x, IntegerNumber.of(4)),
                  const RealNumber(1.0),
                ]),
                const RealNumber(0.5),
              ),
          points: const [0.2, 0.5, 0.7],
        );

        verifyAntiderivative(
          (IntegerNumber.two * x) /
              (Pow.of(x, IntegerNumber.two) + IntegerNumber.one),
        );
        verifyAntiderivative(
          (Pow.of(x, IntegerNumber.of(3)) + IntegerNumber.one) /
              (x + IntegerNumber.one),
        );
        verifyAntiderivative(
          (Pow.of(x, IntegerNumber.two) +
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
      check(nested).equals(Fn.si(IntegerNumber.one));
      // \int_0^1 \int_0^1 cos(x*y) dy dx = \int_0^1 sin(x)/x dx = Si(1) \approx 0.946083070367
      check(nested.evaluate()).isCloseTo(0.946083070367183, 1e-12);

      // Double integral reducing to FresnelC
      final nestedFresnel = Expr.parse('cos(x * y^2)').integrateMultiple([
        (variable: 'y', from: 0, to: 1),
        (variable: 'x', from: 0, to: 1),
      ]);
      check(nestedFresnel).isNotA<Integral>();
      check(nestedFresnel.evaluate()).isCloseTo(0.9675774909926477, 1e-9);

      // Genuinely unevaluated double integral evaluated numerically via nested Gauss-Legendre
      final nestedNum = Expr.parse('cos(x * y^3)').integrateMultiple([
        (variable: 'y', from: 0, to: 1),
        (variable: 'x', from: 0, to: 1),
      ]);
      check(nestedNum).isA<Integral>();
      check(nestedNum.evaluate()).isCloseTo(0.9768211684833681, 1e-9);
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
        Expr.parse('fresnelS(2 * x)'),
        points: const [0.3, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('fresnelC(2 * x)'),
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

    test(
      'integrates special-function reductions and additive cancellations',
      () {
        verifyAntiderivative(
          Expr.parse('1 / ln(x) - 1 / ln(x)^2'),
          points: const [1.5, 2.0, 3.0],
        );
        verifyAntiderivative(
          Expr.parse('1 / ln(x) + ln(ln(x))'),
          points: const [1.5, 2.0, 3.0],
        );
        verifyAntiderivative(
          Expr.parse('cos(x) * ln(x) + sin(x) / x'),
          points: const [0.4, 0.8, 1.5],
        );
        verifyAntiderivative(
          Expr.parse('(cos(x) * ln(x) - sin(x) / x) / ln(x)^2'),
          points: const [1.5, 2.0, 3.0],
        );
        verifyAntiderivative(
          Expr.parse('(cos(x) + sin(x)) / x^2 + (sin(x) - cos(x)) / x'),
          points: const [0.4, 0.8, 1.5],
        );
        verifyAntiderivative(
          Expr.parse('(x^7 - 1) / ln(x)'),
          points: const [1.5, 2.0, 3.0],
        );
        verifyAntiderivative(
          Expr.parse('x * exp(exp(x^2))'),
          points: const [0.3, 0.6, 0.9],
        );
        verifyAntiderivative(
          Expr.parse('exp(exp(x)) - exp(exp(x) - x)'),
          points: const [0.3, 0.6, 0.9],
        );
        verifyAntiderivative(
          Expr.parse('x^5 * exp(-x^4)'),
          points: const [0.3, 0.7, 1.1],
        );
        verifyAntiderivative(
          Expr.parse('2^ln(x)'),
          points: const [1.5, 2.0, 3.0],
        );
        verifyAntiderivative(
          Expr.parse('(1 + ln(x)) * ln(ln(x))'),
          points: const [1.5, 2.0, 3.0],
        );
      },
    );

    test('omits Abs in logarithmic antiderivative for complex arguments', () {
      final sqrtNegA = Expr.parse('1 / (a + x * sqrt(-a))').integrate('x');
      check(sqrtNegA).isNotA<Integral>();
      check(sqrtNegA.anyNode((n) => n is Call && n.id == FunctionId.abs))
          .isFalse;

      final withI = Expr.parse('1 / (x + i)').integrate('x');
      check(withI).equals(Expr.parse('ln(i + x)').simplify());
    });

    test(
      'integrates unevaluated Derivative, Binomial(x, k), and ln(b^g(x))',
      () {
        final derivExpr = Derivative(Expr.parse('exp(1 + x - x^2)'), 'x');
        check(derivExpr.integrate('x')).equals(Expr.parse('exp(1 + x - x^2)'));

        final deriv2 = Derivative(Expr.parse('sin(x^2)'), 'x', order: 2);
        check(deriv2.integrate('x'))
            .equals(Expr.parse('2 * x * cos(x^2)').simplify());

        final binomRecip =
            (IntegerNumber.one / Fn.binomial(x, IntegerNumber.of(5))).integrate(
              'x',
            );
        check(binomRecip).isNotA<Integral>();
        check(
          binomRecip.anyNode((n) => n is Call && n.id == FunctionId.binomial),
        ).isFalse;

        verifyAntiderivative(
          Fn.ln(Pow.of(Constant.e, Fn.cos(x))),
          points: const [0.3, 0.8, 1.4],
        );
        verifyAntiderivative(
          Fn.ln(Pow.of(IntegerNumber.two, Fn.cos(x))),
          points: const [0.3, 0.8, 1.4],
        );

        // Symbolic-exponent polynomial products x^m * P(x)
        final xmPoly = Expr.parse('x^m * (a + b*x + c*x^2)').integrate('x');
        check(xmPoly).isNotA<Integral>();
        check(
          (xmPoly.derivative('x') - Expr.parse('x^m * (a + b*x + c*x^2)'))
              .expand()
              .simplify(),
        ).equals(IntegerNumber.zero);
      },
    );

    test('terminates within budget on large or unsolvable integrands', () {
      final sw = Stopwatch()..start();
      final unsolvable = Expr.parse('(c + d * x) / (a + b * sin(e + f * x))^2')
          .integrate('x');
      sw.stop();
      check(unsolvable).isA<Integral>();
      check(sw.elapsedMilliseconds).isLessThan(1000);

      final solvableTrig = Expr.parse(
        'cos(c + d * x)^2 / (a + b * sin(c + d * x))',
      ).integrate('x');
      check(solvableTrig).isNotA<Integral>();
    });

    test('integrates Chebyshev binomials via Hypergeometric and x^s * exp(a*x) via ExpIntegralE', () {
      final binomHyper = Expr.parse('x * (2 + 3 * x^3)^(1/2)').integrate('x');
      check(
        binomHyper.anyNode(
          (n) => n is Call && n.id == FunctionId.hypergeometric,
        ),
      ).isTrue;
      verifyAntiderivative(
        binomHyper.derivative('x'),
        points: const [0.1, 0.3],
      );
      final diffHyper =
          (binomHyper.derivative('x') - Expr.parse('x * (2 + 3 * x^3)^(1/2)'))
              .simplify();
      check(diffHyper.evaluate({'x': 0.25})).isCloseTo(0.0, 1e-8);

      final expE = Expr.parse('x^(-1/3) * exp(-2 * x + 1)').integrate('x');
      check(expE.anyNode((n) => n is Call && n.id == FunctionId.expIntegralE))
          .isTrue;
      final diffExpE =
          (expE.derivative('x') - Expr.parse('x^(-1/3) * exp(-2 * x + 1)'))
              .simplify();
      check(diffExpE.evaluate({'x': 0.5})).isCloseTo(0.0, 1e-8);

      final shiftedCi = Expr.parse('cos(2 * x + 1) / (3 * x + 4)')
          .integrate('x');
      check(shiftedCi.anyNode((n) => n is Call && n.id == FunctionId.ci))
          .isTrue;
      final diffCi =
          (shiftedCi.derivative('x') -
                  Expr.parse('cos(2 * x + 1) / (3 * x + 4)'))
              .simplify();
      check(diffCi.evaluate({'x': 0.7})).isCloseTo(0.0, 1e-9);
    });

    test(
      'terminates rapidly within budget on complex unsolvable integrands',
      () {
        final sw1 = Stopwatch()..start();
        final fracLin = Expr.parse(
          '(x^2 - c*x^2*((a*x + b)/(c*x + d))^(3/2)) / (a - b*sqrt((a*x + b)/(c*x + d)))',
        ).integrate('x');
        sw1.stop();
        check(fracLin).isNotNull();
        check(sw1.elapsedMilliseconds).isLessThan(500);

        final sw2 = Stopwatch()..start();
        final multiParam = Expr.parse(
          '(a + b*x)^2 * (c + d*x)^3 / ((e + f*x) * (g + h*x) * sin(p + q*x))',
        ).integrate('x');
        sw2.stop();
        check(multiParam).isA<Integral>();
        check(sw2.elapsedMilliseconds).isLessThan(500);
      },
    );

    test(
      'integrates log-exponential quotients without non-holomorphic abs',
      () {
        final integrand = Expr.parse('1 / (1 + exp(2 * x))');
        final antideriv = integrand.integrate('x');
        check(antideriv.anyNode((n) => n is Integral)).isFalse;
        final cEnv = {'x': const Complex(0.37, 0.29)};
        check(
          (antideriv.derivative('x').evaluateComplex(cEnv) -
                  integrand.evaluateComplex(cEnv))
              .abs(),
        ).isCloseTo(0.0, 1e-12);

        final tanhExpr = Expr.parse('tanh(2 * x + 1)');
        final tanhAnti = tanhExpr.integrate('x');
        check(tanhAnti.anyNode((n) => n is Integral)).isFalse;
        check(
          (tanhAnti.derivative('x').evaluateComplex(cEnv) -
                  tanhExpr.evaluateComplex(cEnv))
              .abs(),
        ).isCloseTo(0.0, 1e-12);
      },
    );

    test('integrates rational-derivative quotients and higher-degree Chebyshev binomials', () {
      final quarticRad = Expr.parse('(4*x^3 - 1) / sqrt(2*x^4 - 2*x - 1)')
          .integrate('x');
      check(quarticRad).equals(Expr.parse('sqrt(2*x^4 - 2*x - 1)').simplify());

      final cheb4 = Expr.parse('(a*x^4 - b)^(3/4)').integrate('x');
      check(cheb4.anyNode((n) => n is Integral)).isFalse;
      final cEnv = {
        'x': const Complex(1.7, 0.4),
        'a': const Complex(2.0, 0.3),
        'b': const Complex(1.0, 0.2),
      };
      check(
        (cheb4.derivative('x').evaluateComplex(cEnv) -
                Expr.parse('(a*x^4 - b)^(3/4)').evaluateComplex(cEnv))
            .abs(),
      ).isCloseTo(0.0, 1e-10);

      final nestedExp = Expr.parse(
        '(2*x + 2) * ln(2) * exp(x) * exp(x * ln(2) * exp(x))^2',
      );
      final nestedAnti = nestedExp.integrate('x');
      check(nestedAnti.anyNode((n) => n is Integral)).isFalse;
      check(
        (nestedAnti.derivative('x').evaluate({'x': 0.45}) -
                nestedExp.evaluate({'x': 0.45}))
            .abs(),
      ).isCloseTo(0.0, 1e-10);

      final hypProd = Expr.parse('sinh(a + b*x)^6 * cosh(a + b*x)^2');
      final hypAnti = hypProd.integrate('x');
      check(hypAnti.anyNode((n) => n is Integral)).isFalse;
      final hypEnv = {'x': 0.41, 'a': 0.3, 'b': 0.7};
      check(
        (hypAnti.derivative('x').evaluate(hypEnv) - hypProd.evaluate(hypEnv))
            .abs(),
      ).isCloseTo(0.0, 1e-9);

      final highRat = Expr.parse('1 / ((a + b*x) * (c + d*x)^8)');
      final highRatAnti = highRat.integrate('x');
      check(highRatAnti.anyNode((n) => n is Integral)).isFalse;
      final ratEnv = {'x': 0.37, 'a': 3.1, 'b': 0.7, 'c': 1.1, 'd': 2.5};
      check((highRatAnti.derivative('x') - highRat).together())
          .equals(IntegerNumber.zero);
      check(
        (highRatAnti.derivative('x').evaluate(ratEnv) -
                highRat.evaluate(ratEnv))
            .abs(),
      ).isCloseTo(0.0, 1e-9);
    });

    test('integrates monomial power products with fractional exponents', () {
      for (final (source, env) in const [
        (
          '(b * x)^p * (c * x)^m',
          {'x': 1.4, 'b': 1.7, 'c': 2.3, 'p': 0.4, 'm': 0.7},
        ),
        ('sqrt(b * x^2)', {'x': 1.6, 'b': 2.5}),
        ('sqrt(b * x^2) / x^2', {'x': 1.6, 'b': 2.5}),
        (
          '(c * x)^m / (b * x^n)^(3/2)',
          {'x': 1.4, 'b': 1.7, 'c': 2.3, 'm': 1.2, 'n': 1.5},
        ),
      ]) {
        final integrand = Expr.parse(source);
        final antideriv = integrand.integrate('x');
        check(antideriv.anyNode((n) => n is Integral)).isFalse;
        check(
          (antideriv.derivative('x').evaluate(env) - integrand.evaluate(env))
              .abs(),
        ).isCloseTo(0.0, 1e-8);
      }
    });

    test('integrates exp of inverse hyperbolic and inverse tangent powers', () {
      for (final (source, env) in const [
        ('exp(atanh(a * x) / 2)', {'x': 0.4, 'a': 0.7}),
        ('x^2 * exp(atanh(a * x) / 2)', {'x': 0.4, 'a': 0.7}),
        ('exp(atanh(a * x) / 2) / x', {'x': 0.4, 'a': 0.7}),
        ('x^3 * exp(atanh(1 / (a * x)))', {'x': 1.8, 'a': 1.5}),
        ('exp(atanh(1 / (a * x))) / x', {'x': 1.8, 'a': 1.5}),
      ]) {
        final integrand = Expr.parse(source);
        final antideriv = integrand.integrate('x');
        check(antideriv.anyNode((n) => n is Integral)).isFalse;
        check(
          (antideriv.derivative('x').evaluate(env) - integrand.evaluate(env))
              .abs(),
        ).isCloseTo(0.0, 1e-8);
      }

      for (final source in const [
        'x^4 * exp(i * atan(a * x))',
        'x^2 * exp(i * atan(a * x) / 2)',
        'exp(-3 * i * atan(a + b * x))',
      ]) {
        final integrand = Expr.parse(source);
        final antideriv = integrand.integrate('x');
        check(antideriv.anyNode((n) => n is Integral)).isFalse;
        final cEnv = {
          'x': const Complex(0.35, 0.2),
          'a': const Complex(0.8, 0.1),
          'b': const Complex(0.7, 0.15),
        };
        check(
          (antideriv.derivative('x').evaluateComplex(cEnv) -
                  integrand.evaluateComplex(cEnv))
              .abs(),
        ).isCloseTo(0.0, 1e-8);
      }
    });

    test(
      'integrates reciprocal inverse hyperbolics, log-exp, and polylog forms',
      () {
        for (final (source, env) in const [
          ('atanh(1 / (a * x))', {'x': 1.8, 'a': 1.5}),
          ('asinh(1 / (c * x))', {'x': 1.2, 'c': 1.4}),
          ('acosh(1 / (a * x))', {'x': 0.4, 'a': 1.2}),
          ('polylog(2, a * exp(b * x))', {'x': 0.4, 'a': 0.3, 'b': 0.5}),
          ('x * polylog(2, a * exp(b * x))', {'x': 0.4, 'a': 0.3, 'b': 0.5}),
          ('polylog(2, c * x^2) / x', {'x': 0.5, 'c': 0.4}),
          ('ln(a + b * exp(c * x))', {'x': 0.5, 'a': 3.2, 'b': 0.4, 'c': 0.6}),
        ]) {
          final integrand = Expr.parse(source);
          final antideriv = integrand.integrate('x');
          check(antideriv.anyNode((n) => n is Integral)).isFalse;
          check(
            (antideriv.derivative('x').evaluate(env) - integrand.evaluate(env))
                .abs(),
          ).isCloseTo(0.0, 1e-8);
        }
      },
    );
  });
}
