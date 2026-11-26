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
  });
}
