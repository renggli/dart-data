import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
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
        verifyAntiderivative(
          Expr.parse('1 / (x * sqrt(x^4 - 1))'),
          points: const [1.2, 1.6, 2.2],
        );
        verifyAntiderivative(
          Expr.parse('sqrt(tan(x))'),
          points: const [0.2, 0.6, 1.0],
        );
        verifyAntiderivative(
          Expr.parse('sqrt(1 + 1 / x)'),
          points: const [0.5, 1.0, 2.0],
        );
        verifyAntiderivative(
          Expr.parse('1 / (5 + 4 * sqrt(x) + x)'),
          points: const [0.5, 1.0, 2.0],
        );
        verifyAntiderivative(
          Expr.parse('x / (sqrt(x - 1) + sqrt(x + 1))'),
          points: const [1.5, 2.0, 3.0],
        );
        verifyAntiderivative(
          Expr.parse('sqrt(1 + sin(x))'),
          points: const [0.2, 0.6, 1.0],
        );
        verifyAntiderivative(
          Expr.parse('x^(13/2) * sqrt(1 + x^(5/2))'),
          points: const [0.5, 0.8, 1.2],
        );
      },
    );

    test(
      'factors monomials and perfect squares out of fractional-power radicands',
      () {
        check(Expr.parse('sqrt(x) * sqrt(a * x + b * x^3)').integrate('x'))
            .isNotA<Integral>();
        check(Expr.parse('(a * x^3 + b * x^6)^(5/3)').integrate('x'))
            .isNotA<Integral>();
        check(
          Expr.parse('(a^2 + 2 * a * b * x^2 + b^2 * x^4)^(3/4)')
              .integrate('x'),
        ).isNotA<Integral>();

        verifyAntiderivative(
          Expr.parse('sqrt(x) * sqrt(2 * x + 3 * x^3)'),
          points: const [0.5, 1.0, 1.5],
        );
        verifyAntiderivative(
          Expr.parse('(2 * x^3 + 3 * x^6)^(5/3)'),
          points: const [0.5, 0.8, 1.1],
        );
        verifyAntiderivative(
          Expr.parse('(4 + 12 * x^2 + 9 * x^4)^(3/4)'),
          points: const [0.3, 0.7, 1.2],
        );
      },
    );

    test(
      'integrates sqrt(A*x^2 + B*x) / x^k and P(x) / (x^k * sqrt(Q(x)))',
      () {
        verifyAntiderivative(
          Expr.parse('sqrt(x^2 + x) / x'),
          points: const [0.5, 1.0, 2.0],
        );
        verifyAntiderivative(
          Expr.parse('sqrt(x^2 + 1) / x'),
          points: const [0.5, 1.0, 2.0],
        );
        verifyAntiderivative(
          Expr.parse('(2 + 3 * x)^2 / (x^5 * sqrt(4 - 9 * x^2))'),
          points: const [0.2, 0.35, 0.5],
        );
        check(
          Expr.parse('(d + e * x)^2 / (x^5 * sqrt(d^2 - e^2 * x^2))')
              .integrate('x'),
        ).isNotA<Integral>();
      },
    );

    test(
      'integrates half-integer powers of (a +/- a*sin(u)) and (a +/- a*cos(u))',
      () {
        verifyAntiderivative(
          Expr.parse('(2 + 2 * sin(1 + 3 * x))^(3/2)'),
          points: const [0.1, 0.4, 0.7],
        );
        verifyAntiderivative(
          Expr.parse('(2 + 2 * sin(1 + 3 * x))^(-3/2)'),
          points: const [0.1, 0.4, 0.7],
        );
        verifyAntiderivative(
          Expr.parse('(2 - 2 * cos(1 + 3 * x))^(5/2)'),
          points: const [0.2, 0.5, 0.8],
        );
        for (final expr in const [
          '(a + a * sin(c + d * x))^(3/2)',
          '(a + a * sin(c + d * x))^(-3/2)',
          '(a - a * cos(c + d * x))^(5/2)',
        ]) {
          check(Expr.parse(expr).integrate('x')).isNotA<Integral>();
        }
      },
    );

    test('integrates higher-degree polynomial-weighted quadratic radicals', () {
      check(Expr.parse('x^2 * sqrt(a + b * x^2)').integrate('x'))
          .isNotA<Integral>();
      verifyAntiderivative(
        Expr.parse('x^2 * sqrt(3 + 2 * x^2)'),
        points: const [0.3, 0.7, 1.2],
      );
      verifyAntiderivative(
        Expr.parse('x^3 * (1 - x^2)^(3/2)'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('x^2 / (1 + x^2)^(3/2)'),
        points: const [0.3, 0.8, 1.5],
      );
    });

    test('rewrites products of linear square roots and trig radicals', () {
      verifyAntiderivative(
        Expr.parse('sqrt(x - 1) * sqrt(2 - x)'),
        points: const [1.2, 1.5, 1.8],
      );
      verifyAntiderivative(
        Expr.parse('sqrt(1 / sin(x) - sin(x))'),
        points: const [0.2, 0.6, 1.0, 2.0, 2.5],
      );
      verifyAntiderivative(
        Expr.parse('sin(x) * sqrt(1 + tan(x)^2)'),
        points: const [0.2, 0.6, 1.0, 2.0, 2.5],
      );
    });

    test('integrates scaled tangent half-integer powers', () {
      check(Expr.parse('(b * tan(c + d * x))^(5/2)').integrate('x'))
          .isNotA<Integral>();
      check(Expr.parse('(b * tan(c + d * x))^(-5/2)').integrate('x'))
          .isNotA<Integral>();

      verifyAntiderivative(
        Expr.parse('(3 * tan(1 + 2 * x))^(5/2)'),
        points: const [0.1, 0.2, 0.25],
      );
      verifyAntiderivative(
        Expr.parse('(3 * tan(1 + 2 * x))^(-5/2)'),
        points: const [0.1, 0.2, 0.25],
      );
    });

    test('extracts locally-constant scale from (a * f(x)^2)^(k/2)', () {
      check(Expr.parse('(a * sin(x)^2)^(3/2)').integrate('x'))
          .isNotA<Integral>();
      check(Expr.parse('(a * sin(x)^2)^(-3/2)').integrate('x'))
          .isNotA<Integral>();

      verifyAntiderivative(
        Expr.parse('(4 * sin(x)^2)^(3/2)'),
        points: const [0.3, 0.8, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('(4 * sin(x)^2)^(-3/2)'),
        points: const [0.3, 0.8, 2.0],
      );
    });

    test(
      'integrates fractional variable powers via rational-power substitution',
      () {
        verifyAntiderivative(
          Expr.parse('x^(13/2) * sqrt(1 + x^(5/2))'),
          points: const [0.2, 0.6, 1.2],
        );
        verifyAntiderivative(
          Expr.parse('1 / ((1 + sqrt(x)) * sqrt(x - x^2))'),
          points: const [0.1, 0.4, 0.8],
        );
        verifyAntiderivative(
          Expr.parse('1 / (x^(41/25) + x^(9/25))'),
          points: const [0.2, 0.7, 1.5],
        );
        verifyAntiderivative(
          Expr.parse('1 / sqrt(x^(3/2) - x^2)'),
          points: const [0.1, 0.4, 0.8],
        );
      },
    );

    test('integrates degree-9 polynomials over quadratic radicals', () {
      verifyAntiderivative(
        Expr.parse('((x^3 - 3 * x)^3 - 3 * x^3 + 9 * x) / sqrt(x^2 - 4)'),
        points: const [2.5, 3.0, 4.0],
      );
    });

    test(
      'omits Abs inside Ln for negative-discriminant quadratic radicals',
      () {
        final res = Expr.parse('1 / sqrt(x^2 - 1)').integrate('x');
        check(res.anyNode((n) => n is Abs)).isFalse;
        verifyAntiderivative(
          Expr.parse('1 / sqrt(x^2 - 1)'),
          points: const [1.5, 2.0, 3.0],
        );
        verifyAntiderivative(
          Expr.parse('1 / sqrt(2 * x^2 - 5 * x + 2)'),
          points: const [2.5, 3.0, 4.0],
        );
      },
    );

    test('preserves signs and branch cuts across radical & complex cases', () {
      final prodRad = Expr.parse('sqrt(a + b * x) * sqrt(c + d * x)')
          .integrate('x');
      final diffProd =
          (prodRad.derivative('x') -
                  Expr.parse('sqrt(a + b * x) * sqrt(c + d * x)'))
              .simplify();
      check(
        diffProd.evaluate({
          'a': 1.37,
          'b': 1.78,
          'c': 2.19,
          'd': 2.60,
          'x': 0.5,
        }),
      ).isCloseTo(0.0, 1e-9);

      final linDenom = Expr.parse(
        '(A + B * x) / ((d + e * x) * sqrt(b * x + c * x^2))',
      ).integrate('x');
      final diffLin =
          (linDenom.derivative('x') -
                  Expr.parse(
                    '(A + B * x) / ((d + e * x) * sqrt(b * x + c * x^2))',
                  ))
              .simplify();
      check(
        diffLin.evaluate({
          'A': 1.1,
          'B': 1.5,
          'b': 1.3,
          'c': 1.7,
          'd': 2.1,
          'e': 2.5,
          'x': 0.7,
        }),
      ).isCloseTo(0.0, 1e-9);

      verifyAntiderivative(
        Expr.parse('1 / (sqrt(4 * x^2) * (2 + 3 * x))'),
        points: const [0.3, 0.8, 1.5],
      );

      verifyAntiderivative(
        Expr.parse('sqrt(-2 * sin(1 + 2 * x)^2 + 2) * tan(1 + 2 * x)^3'),
        points: const [0.3, 0.7, 1.2, 2.0],
      );

      final oppRad = Expr.parse('1 / (sqrt(-3 * x - 2) * sqrt(3 * x + 2))')
          .integrate('x');
      check(oppRad).isNotA<Integral>();
      final diffOpp =
          (oppRad.derivative('x') -
                  Expr.parse('1 / (sqrt(-3 * x - 2) * sqrt(3 * x + 2))'))
              .simplify();
      check(diffOpp.evaluateComplex({'x': const Complex(0.37, 0.29)}).abs())
          .isCloseTo(0.0, 1e-9);

      final complexTrig = Expr.parse(
        '(i * a * tan(c + d * x) + a) * cot(c + d * x)^2',
      ).integrate('x');
      check(complexTrig.anyNode((n) => n is Abs)).isFalse;

      final nestedLn = Expr.parse('1 / (x * ln(-x))').integrate('x');
      check(nestedLn.anyNode((n) => n is Abs)).isFalse;
    });

    test(
      'integrates Chebyshev case 3 negative-power binomial differentials',
      () {
        verifyAntiderivative(
          Expr.parse('1 / (x^2 * sqrt(1 + x^2))'),
          points: const [0.4, 0.9, 1.7],
        );
        verifyAntiderivative(
          Expr.parse('1 / (x^4 * sqrt(1 + x^2))'),
          points: const [0.4, 0.9, 1.7],
        );
        verifyAntiderivative(
          Expr.parse('x^(-3) * (1 + x^2)^(-1/2)'),
          points: const [0.5, 1.1, 1.8],
        );
      },
    );

    test('integrates extended Chebyshev negative powers, equal-slope linear roots, and non-Sign complex branches', () {
      // Chebyshev case 1 with k = -7 (< -6 bound) and positive scalar env
      final chebExt = Expr.parse('(2 + 3 * x^2)^(9/2) / x^15').integrate('x');
      check(chebExt.anyNode((n) => n is Integral)).isFalse;
      check(chebExt.anyNode((n) => n is Sign)).isFalse;
      for (final px in const [0.4, 0.9, 1.5]) {
        final env = {'x': px};
        check(
          chebExt.derivative('x').evaluate(env) -
              Expr.parse('(2 + 3 * x^2)^(9/2) / x^15').evaluate(env),
        ).isCloseTo(0.0, 1e-8);
      }

      // Equal-slope linear radical product: 1 / (sqrt(b*x - 3) * sqrt(b*x + 1))
      final eqSlope = Expr.parse('1 / (sqrt(2 * x - 3) * sqrt(2 * x + 1))')
          .integrate('x');
      check(eqSlope.anyNode((n) => n is Integral)).isFalse;
      verifyAntiderivative(
        Expr.parse('1 / (sqrt(2 * x - 3) * sqrt(2 * x + 1))'),
        points: const [2.1, 3.0, 4.5],
      );

      // Negative quadratic perfect square: sqrt(-9*x^2 + 12*x - 4)
      final negSq = Expr.parse('sqrt(-9 * x^2 + 12 * x - 4)').integrate('x');
      check(negSq.anyNode((n) => n is Integral)).isFalse;
      final cEnv = {'x': const Complex(0.7, 0.4)};
      check(
        (negSq.derivative('x').evaluateComplex(cEnv) -
                Expr.parse('sqrt(-9 * x^2 + 12 * x - 4)').evaluateComplex(cEnv))
            .abs(),
      ).isCloseTo(0.0, 1e-11);

      // Quadratic without Sign(x) in Case 3: 1 / (x * sqrt(-x^4 + x^2 - 1))
      final biquad = Expr.parse('1 / (x * sqrt(-x^4 + x^2 - 1))')
          .integrate('x');
      check(biquad.anyNode((n) => n is Sign)).isFalse;
      if (!biquad.anyNode((n) => n is Integral)) {
        for (final pt in const [
          Complex(0.3, 0.2),
          Complex(-0.4, 0.3),
          Complex(1.3, 0.1),
        ]) {
          final env = {'x': pt};
          check(
            (biquad.derivative('x').evaluateComplex(env) -
                    Expr.parse('1 / (x * sqrt(-x^4 + x^2 - 1))')
                        .evaluateComplex(env))
                .abs(),
          ).isCloseTo(0.0, 1e-11);
        }
      }

      // Real-valued biquadratic Case 3 without Sign(x): 1 / (x * sqrt(1 + x^2 - x^4))
      verifyAntiderivative(
        Expr.parse('1 / (x * sqrt(1 + x^2 - x^4))'),
        points: const [-0.8, 0.3, 0.7],
      );

      // Quadratic radical with symbolic coefficient prefers holomorphic log
      final symQuad = Expr.parse('1 / sqrt(a * x^2 + b * x + c)')
          .integrate('x');
      check(symQuad.anyNode((n) => n is Integral)).isFalse;
      final envSym = {
        'a': const Complex(1.3, 0.2),
        'b': const Complex(-0.8, 0.3),
        'c': const Complex(2.1, -0.1),
        'x': const Complex(0.6, 0.5),
      };
      check(
        (symQuad.derivative('x').evaluateComplex(envSym) -
                Expr.parse('1 / sqrt(a * x^2 + b * x + c)')
                    .evaluateComplex(envSym))
            .abs(),
      ).isCloseTo(0.0, 1e-11);

      // Chebyshev Case 2 without Sign(x): 1 / (x^4 * (x^2 - 8)^(3/2))
      final cheb2 = Expr.parse('1 / (x^4 * (x^2 - 8)^(3/2))').integrate('x');
      check(cheb2.anyNode((n) => n is Integral)).isFalse;
      check(cheb2.anyNode((n) => n is Sign)).isFalse;
      verifyAntiderivative(
        Expr.parse('1 / (x^4 * (x^2 - 8)^(3/2))'),
        points: const [-4.5, 4.5],
      );

      // Scaled qT in Case 3: x^3 / ((x^4 - 1) * sqrt(2*x^8 + 1))
      final scaledQT = Expr.parse('x^3 / ((x^4 - 1) * sqrt(2 * x^8 + 1))')
          .integrate('x');
      check(scaledQT.anyNode((n) => n is Integral)).isFalse;
      verifyAntiderivative(
        Expr.parse('x^3 / ((x^4 - 1) * sqrt(2 * x^8 + 1))'),
        points: const [-1.4, -0.6, 0.6, 1.4],
      );

      // Symbolic negative-square discriminants yield real Asin antiderivatives
      final linPair = Expr.parse('1 / (sqrt(-b * x + 3) * sqrt(b * x + 2))')
          .integrate('x');
      check(linPair.anyNode((n) => n is Asin)).isTrue;
      for (final env in const [
        {'b': 1.7, 'x': 0.7},
        {'b': -1.7, 'x': 0.7},
      ]) {
        check(
          linPair.derivative('x').evaluate(env) -
              Expr.parse('1 / (sqrt(-b * x + 3) * sqrt(b * x + 2))')
                  .evaluate(env),
        ).isCloseTo(0.0, 1e-11);
      }

      final unitPair = Expr.parse(
        '(a * x + 1) / (sqrt(a * x) * sqrt(-a * x + 1))',
      ).integrate('x');
      check(unitPair.anyNode((n) => n is Asin)).isTrue;
      for (final env in const [
        {'a': 1.4, 'x': 0.35},
        {'a': -1.4, 'x': -0.35},
      ]) {
        check(
          unitPair.derivative('x').evaluate(env) -
              Expr.parse('(a * x + 1) / (sqrt(a * x) * sqrt(-a * x + 1))')
                  .evaluate(env),
        ).isCloseTo(0.0, 1e-11);
      }
      final complexUnitEnv = {
        'a': const Complex(0.63, 0.19),
        'x': const Complex(0.37, 0.29),
      };
      check(
        (unitPair.derivative('x').evaluateComplex(complexUnitEnv) -
                Expr.parse('(a * x + 1) / (sqrt(a * x) * sqrt(-a * x + 1))')
                    .evaluateComplex(complexUnitEnv))
            .abs(),
      ).isCloseTo(0.0, 1e-11);
    });
  });
}
