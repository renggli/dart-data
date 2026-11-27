import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

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

      final sum = Add.of([
        x,
        IntegerNumber.of(5),
        Constant.pi,
        y,
        Fn.sin(y),
        Relational.lessThan(x, IntegerNumber.zero),
        Relational.lessEqual(x, IntegerNumber.zero),
        Relational.greaterThan(x, IntegerNumber.zero),
        Relational.greaterEqual(x, IntegerNumber.zero),
        Relational.equal(x, IntegerNumber.zero),
      ]);
      check(sum.derivative('x')).equals(IntegerNumber.one);
      check(Relational.lessThan(x, IntegerNumber.one).derivative('x'))
          .equals(IntegerNumber.zero);
    });
  });

  group('Arithmetic operators (Add, Mul, Pow, quotients)', () {
    test('differentiates products and quotients', () {
      check(Expr.parse('x^3 - 3*x + 1').derivative('x').toString())
          .equals('-3 + 3 * x ^ 2');
      check(Mul.of([x]).derivative('x')).equals(IntegerNumber.one);
      check((IntegerNumber.of(3) * y * x).derivative('x'))
          .equals(IntegerNumber.of(3) * y);
      check(
        Expr.parse('2 * x * sin(x) * cos(x)')
            .derivative('x')
            .evaluate({'x': 0.5}),
      ).isCloseTo(2 * 0.5 * math.cos(1.0) + math.sin(1.0), 1e-12);

      check(
        (Fn.sin(x) / x).derivative('x').evaluate({'x': 1.2}),
      ).isCloseTo((1.2 * math.cos(1.2) - math.sin(1.2)) / (1.2 * 1.2), 1e-12);
      check(
        (Fn.sin(x) / Pow.of(x, IntegerNumber.two)).derivative('x').evaluate({
          'x': 1.2,
        }),
      ).isCloseTo(
        (1.2 * math.cos(1.2) - 2 * math.sin(1.2)) / (1.2 * 1.2 * 1.2),
        1e-12,
      );
      check(
        ((x * Fn.sin(x)) / (Fn.cos(x) * Fn.ln(x))).derivative('x').evaluate({
          'x': 2.0,
        }),
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
      check(Pow.of(IntegerNumber.two, x).derivative('x').evaluate({'x': 3.0}))
          .isCloseTo(8.0 * math.log(2.0), 1e-12);
      check(Pow.of(x, x).derivative('x').evaluate({'x': 2.0}))
          .isCloseTo(4.0 * (math.log(2.0) + 1.0), 1e-12);
    });
  });

  group('Elementary trigonometric, hyperbolic, and logarithmic functions', () {
    test(
      'differentiates trigonometric and inverse trigonometric functions',
      () {
        check(Fn.tan(x).derivative('x').evaluate({'x': 0.5}))
            .isCloseTo(1.0 / math.pow(math.cos(0.5), 2), 1e-12);
        check(Fn.asin(x).derivative('x').evaluate({'x': 0.5}))
            .isCloseTo(1.0 / math.sqrt(1.0 - 0.25), 1e-12);
        check(Fn.acos(x).derivative('x').evaluate({'x': 0.5}))
            .isCloseTo(-1.0 / math.sqrt(1.0 - 0.25), 1e-12);
        check(Fn.atan(x).derivative('x').evaluate({'x': 1.0}))
            .isCloseTo(0.5, 1e-12);
      },
    );

    test('differentiates hyperbolic and inverse hyperbolic functions', () {
      check(Fn.sinh(x).derivative('x').evaluate({'x': 0.0}))
          .isCloseTo(1.0, 1e-12);
      check(Fn.cosh(x).derivative('x').evaluate({'x': 0.0}))
          .isCloseTo(0.0, 1e-12);
      check(Fn.tanh(x).derivative('x').evaluate({'x': 0.0}))
          .isCloseTo(1.0, 1e-12);
      check(Fn.asinh(x).derivative('x').evaluate({'x': 0.0}))
          .isCloseTo(1.0, 1e-12);
      check(Fn.acosh(x).derivative('x').evaluate({'x': 2.0}))
          .isCloseTo(1.0 / math.sqrt(3.0), 1e-12);
      check(Fn.atanh(x).derivative('x').evaluate({'x': 0.5}))
          .isCloseTo(1.0 / 0.75, 1e-12);
    });

    test('differentiates logarithm and absolute value', () {
      check(Expr.parse('ln(x^2 + 1)').derivative('x').evaluate({'x': 2.0}))
          .isCloseTo(4.0 / 5.0, 1e-12);
      check(Fn.abs(x).derivative('x').evaluate({'x': 3.0})).equals(1.0);
      check(Fn.abs(x).derivative('x').evaluate({'x': -3.0})).equals(-1.0);
    });
  });

  group('Special functions, Piecewise, OrderTerm, and Integral', () {
    test('differentiates Erf, Erfc, LambertW, and returns unevaluated Derivative for Zeta and VariableFunction', () {
      check(Fn.erf(x).derivative('x').evaluate({'x': 0.0}))
          .isCloseTo(2.0 / math.sqrt(math.pi), 1e-12);
      check(Fn.erfc(x).derivative('x').evaluate({'x': 0.0}))
          .isCloseTo(-2.0 / math.sqrt(math.pi), 1e-12);
      check(Fn.lambertW(x).derivative('x').evaluate({'x': 1.0}))
          .isCloseTo(0.3618962566348892, 1e-12);
      check(Fn.zeta(x).derivative('x')).equals(Derivative(Fn.zeta(x), 'x'));
      check(Fn.zeta(x).derivative('x', order: 2))
          .equals(Derivative(Fn.zeta(x), 'x', order: 2));
      final fx = Expr.parse('f(x)');
      check(fx.derivative('x').toString()).equals('diff(f(x), x)');
      check(fx.derivative('x', order: 3).toString()).equals('diff(f(x), x, 3)');
      check(Expr.parse('diff(f(x, y), x)').toString())
          .equals('diff(f(x, y), x)');
      check(Expr.parse('diff(f(x), x)').toLatex()).equals(r'\frac{d}{dx} f(x)');
      check(Expr.parse('diff(f(x), x, 2)').toLatex())
          .equals(r'\frac{d^{2}}{dx^{2}} f(x)');
      check(Expr.parse('diff(f(x), x)').toMathMl(root: false)).equals(
        '<mrow><mfrac><mi>d</mi><mrow><mi>d</mi><mi>x</mi></mrow></mfrac><mrow><mi>f</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></mrow>',
      );
      check(Expr.parse(fx.derivative('x', order: 2).toString()))
          .equals(fx.derivative('x', order: 2));
      final fxy = Expr.parse('f(x, y)');
      check(Derivative(fxy, 'y').derivative('x'))
          .equals(Derivative(Derivative(fxy, 'y'), 'x'));
      // Derivative evaluated at a point: constant point -> 0, x-dependent point -> chain rule
      check(Derivative(fx, 'x', point: IntegerNumber.two).derivative('x'))
          .equals(IntegerNumber.zero);
      check(
        Derivative(
          fx,
          'x',
          point: Pow.of(x, IntegerNumber.two),
        ).derivative('x').toString(),
      ).equals('2 * x * diff(f(x), x, 2, x ^ 2)');
      check(
        Derivative(
          fxy,
          'x',
          point: IntegerNumber.one,
        ).derivative('y').toString(),
      ).equals('diff(diff(f(x, y), y), x, 1, 1)');
      check(Fn.mod(x * IntegerNumber.two, IntegerNumber.of(5)).derivative('x'))
          .equals(IntegerNumber.two);
      check(Fn.mod(x, x).derivative('x')).equals(Derivative(Fn.mod(x, x), 'x'));
      check(Integral(Fn.sin(Pow.of(x, IntegerNumber.two)), 'x').derivative('x'))
          .equals(Fn.sin(Pow.of(x, IntegerNumber.two)).simplify());
      check(Integral(Fn.sin(x * y), 'x').derivative('y'))
          .equals(Integral(x * Fn.cos(x * y), 'x').simplify());
      check(
        Sum(
          Fn.sin(x * t),
          't',
          IntegerNumber.one,
          const Variable('n'),
        ).derivative('x'),
      ).equals(
        Sum(t * Fn.cos(t * x), 't', IntegerNumber.one, const Variable('n')),
      );
      check(Sum(Fn.sin(t * t), 't', IntegerNumber.one, x).derivative('x'))
          .isA<Derivative>();
      check(
        Product(
          Fn.sin(x * t),
          't',
          IntegerNumber.one,
          const Variable('n'),
        ).derivative('x').toString(),
      ).equals(
        'sum(t * cos(t * x) / sin(t * x), t, 1, n) * product(sin(t * x), t, 1, n)',
      );
    });

    test('differentiates OrderTerm and Piecewise nodes', () {
      check(OrderTerm('x', 4).derivative('x')).equals(OrderTerm('x', 3));
      check(OrderTerm('y', 4, point: x).derivative('x'))
          .equals(OrderTerm('y', 4, point: x));
      check(OrderTerm('y', 4).derivative('x')).equals(IntegerNumber.zero);

      final pwWithOtherwise = Expr.parse('piecewise(x < 0, -x^2, x^2)')
          .derivative('x');
      check(pwWithOtherwise.evaluate({'x': -2.0})).equals(4.0);
      check(pwWithOtherwise.evaluate({'x': 2.0})).equals(4.0);

      final pwNoOtherwise = Piecewise([
        (relation: Relational.lessThan(x, IntegerNumber.zero), expr: -x),
        (relation: Relational.greaterEqual(x, IntegerNumber.zero), expr: x),
      ]).derivative('x');
      check(pwNoOtherwise.evaluate({'x': -2.0})).equals(-1.0);
      check(pwNoOtherwise.evaluate({'x': 2.0})).equals(1.0);
    });

    test(
      'differentiates Integral nodes via Fundamental Theorem and Leibniz rule',
      () {
        final constInt = Integral(
          Fn.sin(t),
          't',
          lower: IntegerNumber.zero,
          upper: IntegerNumber.one,
        );
        check(constInt.derivative('x')).equals(IntegerNumber.zero);

        final indefSame = Integral(Expr.parse('sin(x^2)'), 'x');
        check(indefSame.derivative('x'))
            .equals(Expr.parse('sin(x^2)').simplify());

        final indefParam = Integral(x * t, 't');
        check(indefParam.derivative('x')).equals(Integral(t, 't'));

        final upperOnly = Integral(
          Fn.sin(t),
          't',
          lower: IntegerNumber.zero,
          upper: x,
        );
        check(upperOnly.derivative('x')).equals(Fn.sin(x));

        final lowerOnly = Integral(
          Fn.sin(t),
          't',
          lower: x,
          upper: IntegerNumber.one,
        );
        check(lowerOnly.derivative('x')).equals((-Fn.sin(x)).simplify());

        final fullLeibniz = Integral(
          x * t,
          't',
          lower: x,
          upper: Pow.of(x, IntegerNumber.two),
        );
        final dFull = fullLeibniz.derivative('x');
        check(dFull.evaluate({'x': 2.0})).isCloseTo(
          2.0 * 4.0 * 4.0 - 2.0 * 2.0 * 1.0 + 0.5 * (16.0 - 4.0),
          1e-12,
        );
      },
    );
  });

  group('Special functions analytical differentiation', () {
    test('differentiates Gamma, Digamma, Polygamma, Beta, and Factorial', () {
      check(Fn.gamma(x).derivative('x')).equals(Fn.gamma(x) * Fn.digamma(x));
      check(Fn.digamma(x).derivative('x'))
          .equals(Fn.polygamma(IntegerNumber.one, x));
      check(Fn.polygamma(IntegerNumber.one, x).derivative('x'))
          .equals(Fn.polygamma(IntegerNumber.two, x));
      check(Fn.factorial(x).derivative('x'))
          .equals(Fn.factorial(x) * Fn.digamma(IntegerNumber.one + x));

      final dBetaX = Fn.beta(x, y).derivative('x');
      check(dBetaX).isA<Mul>();

      // Chain rule
      check(Fn.gamma(Pow.of(x, IntegerNumber.two)).derivative('x').toString())
          .equals('2 * x * gamma(x ^ 2) * digamma(x ^ 2)');
    });

    test('differentiates Bessel functions J, Y, I, K', () {
      check(Fn.besselJ(IntegerNumber.zero, x).derivative('x'))
          .equals(-Fn.besselJ(IntegerNumber.one, x));
      check(Fn.besselJ(IntegerNumber.one, x).derivative('x')).isA<Mul>();

      check(Fn.besselY(IntegerNumber.zero, x).derivative('x'))
          .equals(-Fn.besselY(IntegerNumber.one, x));
      check(Fn.besselY(IntegerNumber.one, x).derivative('x')).isA<Mul>();

      check(Fn.besselI(IntegerNumber.zero, x).derivative('x'))
          .equals(Fn.besselI(IntegerNumber.one, x));
      check(Fn.besselI(IntegerNumber.one, x).derivative('x')).isA<Mul>();

      check(Fn.besselK(IntegerNumber.zero, x).derivative('x'))
          .equals(-Fn.besselK(IntegerNumber.one, x));
      check(Fn.besselK(IntegerNumber.one, x).derivative('x')).isA<Mul>();
    });

    test('differentiates complete elliptic integrals K and E', () {
      final dK = Fn.ellipticK(x).derivative('x');
      check(dK).isA<Mul>();
      final dE = Fn.ellipticE(x).derivative('x');
      check(dE).isA<Mul>();

      // Numerical verification of elliptic derivative against finite differences
      const x0 = 0.5;
      const h = 1e-6;
      final kNum =
          (Fn.ellipticK(x).evaluate({'x': x0 + h}) -
              Fn.ellipticK(x).evaluate({'x': x0 - h})) /
          (2 * h);
      check(dK.evaluate({'x': x0})).isCloseTo(kNum, 1e-6);

      final eNum =
          (Fn.ellipticE(x).evaluate({'x': x0 + h}) -
              Fn.ellipticE(x).evaluate({'x': x0 - h})) /
          (2 * h);
      check(dE.evaluate({'x': x0})).isCloseTo(eNum, 1e-6);
    });
  });

  group('Special integral and polylogarithm AST functions', () {
    test(
      'differentiates Erfi, FresnelS, FresnelC, ExpIntegral, LogIntegral',
      () {
        check(
          (Expr.parse('erfi(2 * x)').derivative('x') -
                  Expr.parse('4 * exp(4 * x^2) / sqrt(pi)'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('fresnelS(x)').derivative('x') -
                  Expr.parse('sin(pi * x^2 / 2)'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('fresnelC(x)').derivative('x') -
                  Expr.parse('cos(pi * x^2 / 2)'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('Ei(2 * x)').derivative('x') -
                  Expr.parse('exp(2 * x) / x'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('li(x^2)').derivative('x') -
                  Expr.parse('2 * x / ln(x^2)'))
              .simplify(),
        ).equals(IntegerNumber.zero);
      },
    );

    test(
      'differentiates SinIntegral, CosIntegral, SinhIntegral, CoshIntegral',
      () {
        check(
          (Expr.parse('Si(3 * x)').derivative('x') -
                  Expr.parse('sin(3 * x) / x'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('Ci(x^2)').derivative('x') -
                  Expr.parse('2 * cos(x^2) / x'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('Shi(x)').derivative('x') - Expr.parse('sinh(x) / x'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('Chi(x)').derivative('x') - Expr.parse('cosh(x) / x'))
              .simplify(),
        ).equals(IntegerNumber.zero);
      },
    );

    test(
      'differentiates UpperGamma, LowerGamma, Polylog, EllipticF, EllipticE',
      () {
        check(
          (Expr.parse('upperGamma(3, x^2)').derivative('x') -
                  Expr.parse('-2 * x^5 * exp(-x^2)'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('lowerGamma(3, x^2)').derivative('x') -
                  Expr.parse('2 * x^5 * exp(-x^2)'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('polylog(1, x)').derivative('x') -
                  Expr.parse('1 / (1 - x)'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('polylog(3, x^2)').derivative('x') -
                  Expr.parse('2 * polylog(2, x^2) / x'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('ellipticF(x, k)').derivative('x') -
                  Expr.parse('1 / sqrt(1 - k^2 * sin(x)^2)'))
              .simplify(),
        ).equals(IntegerNumber.zero);
        check(
          (Expr.parse('ellipticE(x, k)').derivative('x') -
                  Expr.parse('sqrt(1 - k^2 * sin(x)^2)'))
              .simplify(),
        ).equals(IntegerNumber.zero);

        // Parameter-dependent differentiation falls back to Derivative
        check(Fn.upperGamma(x, IntegerNumber.two).derivative('x'))
            .isA<Derivative>();
        check(Fn.lowerGamma(x, IntegerNumber.two).derivative('x'))
            .isA<Derivative>();
        check(Fn.polylog(x, FractionNumber.half).derivative('x'))
            .isA<Derivative>();

        // Modulus differentiation of incomplete elliptic integrals
        const k = Variable('k');
        final piOver4 = Constant.pi / IntegerNumber.of(4);
        final piOver3 = Constant.pi / IntegerNumber.of(3);
        check(Fn.ellipticE(piOver4, k).derivative('k')).equals(
          ((Fn.ellipticE(piOver4, k) - Fn.ellipticF(piOver4, k)) / k)
              .simplify(),
        );

        final dFdk = Fn.ellipticF(piOver3, k).derivative('k');
        const h = 1e-6;
        final fd =
            (Fn.ellipticF(piOver3, k).evaluate({'k': 0.5 + h}) -
                Fn.ellipticF(piOver3, k).evaluate({'k': 0.5 - h})) /
            (2.0 * h);
        check(dFdk.evaluate({'k': 0.5})).isCloseTo(fd, 1e-6);
      },
    );

    test('differentiates symbolic Product via logarithmic differentiation', () {
      const t = Variable('t');
      const n = Variable('n');
      final prod = Product(Fn.cos(x * t), 't', IntegerNumber.one, n);
      check(prod.derivative('x')).equals(
        (prod *
                Sum(
                  (-t * Fn.sin(x * t)) / Fn.cos(x * t),
                  't',
                  IntegerNumber.one,
                  n,
                ))
            .simplify(),
      );
      // Bound variable match or dependent bounds remain unevaluated Derivative
      check(Product(Fn.cos(x * t), 't', IntegerNumber.one, x).derivative('x'))
          .isA<Derivative>();
    });

    test(
      'differentiates EllipticPi and Atan2 with finite-difference checks',
      () {
        const h = 1e-6;

        // EllipticPi wrt amplitude
        final piPhi = Expr.parse('ellipticPi(n, x, k)');
        check(
          (piPhi.derivative('x') -
                  Expr.parse(
                    '1 / ((1 - n * sin(x)^2) * sqrt(1 - k^2 * sin(x)^2))',
                  ))
              .simplify(),
        ).equals(IntegerNumber.zero);

        // EllipticPi wrt modulus k
        final piK = Expr.parse('ellipticPi(0.3, 0.8, x)');
        final dPidK = piK.derivative('x');
        final fdK =
            (piK.evaluate({'x': 0.5 + h}) - piK.evaluate({'x': 0.5 - h})) /
            (2.0 * h);
        check(dPidK.evaluate({'x': 0.5})).isCloseTo(fdK, 1e-6);

        // EllipticPi wrt characteristic n
        final piN = Expr.parse('ellipticPi(x, 0.8, 0.5)');
        final dPidN = piN.derivative('x');
        final fdN =
            (piN.evaluate({'x': 0.3 + h}) - piN.evaluate({'x': 0.3 - h})) /
            (2.0 * h);
        check(dPidN.evaluate({'x': 0.3})).isCloseTo(fdN, 1e-6);

        // Atan2 wrt y and x
        final a2 = Expr.parse('atan2(x^2, 2*x + 1)');
        final da2 = a2.derivative('x');
        final fdA2 =
            (a2.evaluate({'x': 1.2 + h}) - a2.evaluate({'x': 1.2 - h})) /
            (2.0 * h);
        check(da2.evaluate({'x': 1.2})).isCloseTo(fdA2, 1e-6);
      },
    );

    test('differentiates binomial coefficients', () {
      final dPoly = Expr.parse('binomial(x, 3)').derivative('x').expand();
      check(dPoly).equals(Expr.parse('(3 * x^2 - 6 * x + 2) / 6').expand());

      final general = Expr.parse('binomial(x, 25)').derivative('x');
      check(general.anyNode((n) => n is Call && n.id == FunctionId.polygamma))
          .isTrue;
      check(general.evaluate({'x': 27.0})).isCloseTo(
        (Expr.parse('binomial(x, 25)').evaluate({'x': 27.0 + 1e-6}) -
                Expr.parse('binomial(x, 25)').evaluate({'x': 27.0 - 1e-6})) /
            2e-6,
        1e-4,
      );
    });

    test('preserves branch cuts for Acosh and fractional trig powers', () {
      final dAcosh = Expr.parse('-acosh(-b * x / 2) / b').derivative('x');
      final expAcosh = Expr.parse('1 / (sqrt(-b * x - 2) * sqrt(-b * x + 2))');
      final zEnv = {
        'b': const Complex(0.43, 0.17),
        'x': const Complex(0.72, 0.17),
      };
      check(
        (dAcosh.evaluateComplex(zEnv) - expAcosh.evaluateComplex(zEnv)).abs(),
      ).isCloseTo(0.0, 1e-12);

      final dTrig = Expr.parse(
        '2 * (c * sin(a + b * x))^(3/2) / (3 * b * c * d * (d * cos(a + b * x))^(3/2))',
      ).derivative('x');
      final expTrig = Expr.parse(
        'sqrt(c * sin(a + b * x)) / (d * cos(a + b * x))^(5/2)',
      );
      final rEnv = {'a': 1.54, 'b': 1.83, 'c': 2.12, 'd': 2.41, 'x': 2.70};
      check(dTrig.evaluate(rEnv)).isCloseTo(expTrig.evaluate(rEnv), 1e-12);
      final cEnv = {
        'a': const Complex(0.63, 0.19),
        'b': const Complex(0.94, 0.12),
        'c': const Complex(1.25, 0.05),
        'd': const Complex(1.56, -0.02),
        'x': const Complex(0.37, 0.29),
      };
      check(
        (dTrig.evaluateComplex(cEnv) - expTrig.evaluateComplex(cEnv)).abs(),
        because: 'dTrig=$dTrig',
      ).isCloseTo(0.0, 1e-9);
    });

    test(
      'differentiates ln(abs(u)) holomorphically on non-complex domains',
      () {
        final f1 = Expr.parse('ln(abs(a * x + b))');
        final d1 = f1.derivative('x').simplify();
        check(d1.anyNode((n) => n is Call && n.id == FunctionId.abs)).isFalse;
        final cEnv = {
          'a': const Complex(1.4, 0.3),
          'b': const Complex(-0.7, 0.5),
          'x': const Complex(0.8, 0.4),
        };
        final expected1 = Expr.parse('a / (a * x + b)').evaluateComplex(cEnv);
        check((d1.evaluateComplex(cEnv) - expected1).abs())
            .isCloseTo(0.0, 1e-12);

        final f2 = Expr.parse('ln(abs(x - 1) * abs(x + 2))');
        final d2 = f2.derivative('x').simplify();
        check(d2.anyNode((n) => n is Call && n.id == FunctionId.abs)).isFalse;
        final expected2 = Expr.parse('1 / (x - 1) + 1 / (x + 2)')
            .evaluateComplex(cEnv);
        check((d2.evaluateComplex(cEnv) - expected2).abs())
            .isCloseTo(0.0, 1e-12);
      },
    );
  });
}
