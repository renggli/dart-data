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

  group('Chain-rule substitution and integration by parts', () {
    test('integrates products via chain-rule u-substitution', () {
      check((IntegerNumber.two * y * Fn.sin(x)).integrate('x'))
          .equals((-IntegerNumber.two * y * Fn.cos(x)).simplify());

      final x2 = Pow.of(x, IntegerNumber.two);
      final x3PlusX = Pow.of(x, IntegerNumber.of(3)) + x;
      for (final f in [
        x * Fn.cos(x2),
        x * Fn.sin(x2),
        x * Fn.ln(x2),
        x * Fn.tan(x2),
        x * Fn.sinh(x2),
        x * Fn.cosh(x2),
        x * Fn.tanh(x2),
        (IntegerNumber.of(3) * x2 + IntegerNumber.one) * Fn.abs(x3PlusX),
        Fn.cos(x) * Pow.of(Fn.sin(x), IntegerNumber.of(3)),
        x * Fn.cos(x2) * Pow.of(Fn.sin(x2), IntegerNumber.negativeOne),
        x * Pow.of(Constant.e, x2),
        x * Pow.of(IntegerNumber.two, x2),
        x * Pow.of(const RealNumber(2.5), x2),
      ]) {
        verifyAntiderivative(f, points: const [0.4, 0.7, 1.1]);
      }

      // Chain rule power u-substitution with power -1 (such as 1/(x * ln(x))):
      final xLnX = Expr.parse('1/(x * ln(x))').integrate('x');
      check(xLnX).equals(Fn.ln(Fn.abs(Fn.ln(x))));
    });

    test('integrates products via linear, cyclic, and higher-degree IBP', () {
      final lin = IntegerNumber.two * x + IntegerNumber.one;
      for (final f in [
        Pow.of(Constant.e, IntegerNumber.two * x) *
            Fn.sin(IntegerNumber.of(3) * x),
        Pow.of(Constant.e, IntegerNumber.two * x) *
            Fn.cos(IntegerNumber.of(3) * x),
        Fn.sin(IntegerNumber.of(3) * x) *
            Pow.of(Constant.e, IntegerNumber.two * x),
        x * Fn.ln(lin),
        x * Pow.of(Constant.e, lin),
        x * Fn.cos(lin),
        x * Fn.sin(lin),
        x * Fn.sinh(lin),
        x * Fn.cosh(lin),
        x * Pow.of(IntegerNumber.two, lin),
        x * Pow.of(const RealNumber(2.5), lin),
        Pow.of(x, IntegerNumber.two) * Pow.of(Constant.e, x),
        Pow.of(x, IntegerNumber.two) * Fn.sin(x),
        Pow.of(x, IntegerNumber.two) * Fn.cos(x),
        Pow.of(x, IntegerNumber.two) * Fn.sinh(x),
        Pow.of(x, IntegerNumber.two) * Fn.cosh(x),
        x * (x + IntegerNumber.one) * Pow.of(Constant.e, x),
        (Pow.of(x, IntegerNumber.two) + Fn.sin(x)) * Fn.cos(x),
        (Pow.of(x, IntegerNumber.two) + IntegerNumber.one) *
            Fn.sin(x) *
            Fn.cos(x),
        Pow.of(x + IntegerNumber.one, IntegerNumber.two) *
            Pow.of(x + IntegerNumber.two, IntegerNumber.two),
      ]) {
        verifyAntiderivative(f);
      }

      check((Fn.sin(x) * Fn.ln(x)).integrate('x'))
          .equals(Expr.parse('-cos(x) * ln(x) + Ci(x)').simplify());
    });
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

  group('Extended trig, hyperbolic, radical, and parametric integration', () {
    void verifyWithParams(
      String source,
      Map<String, double> params, {
      List<double> points = const [0.3, 0.6, 0.9],
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

    test(
      'integrates linear * log powers, exp * log, and symbolic binomials',
      () {
        verifyAntiderivative(
          Expr.parse('x * ln(x)^2'),
          points: const [0.5, 1.2, 2.0],
        );
        verifyAntiderivative(
          Expr.parse('exp(x) * ln(x + 1)'),
          points: const [0.2, 0.7, 1.3],
        );
        verifyWithParams('x * (a + b * x)^p', {'a': 2.0, 'b': 1.5, 'p': 2.3});
        verifyWithParams('x^2 * (a + b * x)^p', {
          'a': 2.0,
          'b': 1.5,
          'p': -0.7,
        });
      },
    );

    test('integrates mixed trig-exp-log and Ei/polylog reductions', () {
      verifyAntiderivative(
        Expr.parse('sin(ln(x))'),
        points: const [0.5, 1.2, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('cos(ln(2 * x))'),
        points: const [0.5, 1.2, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('x^2 * sin(ln(x))'),
        points: const [0.5, 1.2, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('exp(atan(x)) / (x^2 + 1)^(3/2)'),
        points: const [0.2, 0.6, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('x * exp(atan(x)) / (x^2 + 1)^(3/2)'),
        points: const [0.2, 0.6, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('ln(x) / (x + 1)'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('exp(x) / (x + 1)'),
        points: const [0.2, 0.6, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('exp(x) / (x + 1)^2'),
        points: const [0.2, 0.6, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('exp(1 / x)'),
        points: const [0.4, 0.8, 1.5],
      );
      verifyAntiderivative(
        Expr.parse('x * exp(x^2) / (x^2 + 1)'),
        points: const [0.2, 0.6, 1.1],
      );
    });

    test('integrates rational trig and hyperbolic functions', () {
      verifyAntiderivative(
        Expr.parse('sin(x) / (sin(x) + cos(x) + 1)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('(2 * sin(x) + 3 * cos(x)) / (sin(x) + 2 * cos(x))'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('sin(x)^2 / (sin(x)^2 + 1)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyWithParams('1 / (a^2 * sin(x)^2 + b^2 * cos(x)^2)', {
        'a': 2.0,
        'b': 3.0,
      });
      verifyAntiderivative(
        Expr.parse('(cos(x) + 1)^(-2)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyWithParams('1 / (a + b * tanh(x))', {'a': 3.0, 'b': 1.5});
      verifyWithParams('1 / (a^2 + b^2 * cosh(x)^2)', {'a': 2.0, 'b': 1.5});
      verifyAntiderivative(
        Expr.parse('(cosh(x) + 1)^(-2)'),
        points: const [0.2, 0.6, 1.0],
      );
    });

    test('integrates algebraic radicals, biquadratics, and parametric partial fractions', () {
      verifyAntiderivative(
        Expr.parse('x^2 / sqrt(x^2 + 1)'),
        points: const [0.2, 0.7, 1.3],
      );
      verifyAntiderivative(
        Expr.parse('sqrt(3 - x^2) / x'),
        points: const [0.3, 0.7, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('sqrt(x^2 + 1) / x^2'),
        points: const [0.3, 0.7, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('1 / (x^2 * sqrt(x^2 + 1))'),
        points: const [0.3, 0.7, 1.1],
      );
      verifyWithParams('sqrt((a + x) / (a - x))', {'a': 2.5});
      verifyAntiderivative(
        Expr.parse('1 / (x^4 + x^2 + 1)'),
        points: const [0.2, 0.6, 1.1],
      );
      verifyWithParams('x / ((x - a) * (x - b) * (x - c))', {
        'a': 2.1,
        'b': 3.3,
        'c': 4.7,
      });
      verifyAntiderivative(
        Expr.parse('sin(ln(x))^2'),
        points: const [0.5, 1.5, 2.5],
      );
      check(
        Expr.parse('x * (1 - x)^99').integrate('x'),
      ).equals(Expr.parse('(1 - x)^101 / 101 - (1 - x)^100 / 100').simplify());
    });

    test(
      'integrates general exponential rational forms via u = B^(alpha * x)',
      () {
        verifyWithParams('f^(a + b * x) / (c + d * f^(e + 2 * b * x))', {
          'a': 0.5,
          'b': 1.2,
          'c': 2.0,
          'd': 3.0,
          'e': 0.3,
          'f': 2.5,
        });
        verifyAntiderivative(
          Expr.parse('2^(3 * x + 1) / (1 + 2^(6 * x))'),
          points: const [0.1, 0.4, 0.8],
        );
      },
    );

    test('normalizes u-substitution quotients and cancels negated denominator factors', () {
      verifyAntiderivative(
        Expr.parse('(cos(x) + x * sin(x)) / (x * (x + cos(x)))'),
        points: const [0.3, 0.7, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('(x - 1) / (x + x^2 * ln(x))'),
        points: const [0.4, 1.5, 2.5],
      );
      verifyAntiderivative(
        Expr.parse('(x * e^x - e^x) / (x * (x + e^x))'),
        points: const [0.3, 0.7, 1.2],
      );
      check(
        Expr.parse(
          '(2018 * x^2017 + 2017 * x^2016) / (x^4036 + 2 * x^4035 + x^4034 + 1)',
        ).integrate('x'),
      ).isA<Expr>();
      check(Expr.parse('x^2017 / (x^2018 + 1)').integrate('x'))
          .isNotA<Integral>();
    });

    test('integrates power/log rewrites, linear-log denominators, and Fresnel quadratics', () {
      verifyAntiderivative(
        Expr.parse('x^(1 / ln(x))'),
        points: const [1.5, 2.5, 4.0],
      );
      verifyAntiderivative(
        Expr.parse('x^(-ln(x))'),
        points: const [1.5, 2.5, 4.0],
      );
      verifyAntiderivative(
        Expr.parse('sqrt(x * sqrt(x^(3/2)))'),
        points: const [0.5, 1.5, 3.0],
      );
      verifyAntiderivative(
        Expr.parse('ln(2 * x) / (x * ln(x))'),
        points: const [1.5, 2.5, 4.0],
      );
      verifyAntiderivative(
        Expr.parse('1 / (1 - ln(1 - x))'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('e^(-9 / (4 * x^2)) / x^2'),
        points: const [0.5, 1.2, 2.5],
      );
      verifyAntiderivative(
        Expr.parse('cos(2 * x^2)^2'),
        points: const [0.3, 0.7, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('sin(3 * x^2)'),
        points: const [0.3, 0.7, 1.1],
      );
    });

    test('integrates split exponentials, base-power towers, shifted Gaussians, and multi-term u\'/u^m', () {
      verifyAntiderivative(
        Expr.parse('exp(exp(x) + exp(-x) + x) - exp(exp(x) + exp(-x) - x)'),
        points: const [0.1, 0.3, 0.5],
      );
      verifyAntiderivative(
        Expr.parse('exp(exp(2 * x) + 6 * x)'),
        points: const [0.1, 0.3, 0.5],
      );
      verifyAntiderivative(
        Expr.parse('3 * x^2 * (x^3 + 1)^2 * exp(-x^6 - 2 * x^3)'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('4^x * 3^(2^x)'),
        points: const [0.1, 0.4, 0.7],
      );
      verifyAntiderivative(
        Expr.parse(
          '(1 / (x - 1)^2 + 3 / (x - 3)^4 + 5 / (x - 5)^6) / '
          '(1 + 1 / (x - 1) + 1 / (x - 3)^3 + 1 / (x - 5)^5)^2',
        ),
        points: const [0.2, 2.0, 4.0],
      );
    });

    test('keeps piecewise floor expressions and bound summation indices unevaluated', () {
      check(Fn.floor(Expr.parse('x')).integrate('x')).isA<Integral>();
      check(
        (Expr.parse('x') - Fn.floor(Expr.parse('x')))
            .pow(2)
            .integrate('x')
            .anyNode((n) => n is Integral),
      ).isTrue;
      check(
        Sum(
          Expr.parse('cos(2^n * x) / 2^n'),
          'n',
          IntegerNumber.zero,
          Constant.infinity,
        ).pow(2).integrate('x'),
      ).isA<Integral>();
    });

    test('integrates coupled multi-base and rational-ratio exponentials', () {
      for (final (source, env) in const [
        (
          'f^(a + 3 * b * x) / (c + d * f^(2 * b * x + e))',
          {
            'x': 0.45,
            'a': 0.5,
            'b': 0.7,
            'c': 2.1,
            'd': 1.3,
            'e': 0.3,
            'f': 2.2,
          },
        ),
        (
          '(a + b * (F^(e * (c + d * x)))^n)^2 * (G^(h * (f + g * x)))^(d * e * n * ln(F) / (g * h * ln(G)))',
          {
            'x': 0.3,
            'a': 1.4,
            'b': 0.7,
            'c': 0.2,
            'd': 0.5,
            'e': 0.6,
            'f': 0.4,
            'g': 0.8,
            'h': 0.9,
            'n': 1.5,
            'F': 2.3,
            'G': 3.1,
          },
        ),
        ('x * exp(x) / (1 - exp(2 * x))', {'x': -0.7}),
        ('x^2 * exp(x) / (1 - exp(2 * x))', {'x': -0.7}),
        (
          'f^x * x / (a + b * f^(2 * x))',
          {'x': -0.8, 'f': 2.3, 'a': 2.5, 'b': 0.6},
        ),
      ]) {
        final integrand = Expr.parse(source);
        final antideriv = integrand.integrate('x');
        check(antideriv.anyNode((n) => n is Integral)).isFalse;
        check(
          (antideriv.derivative('x').evaluate(env) - integrand.evaluate(env))
              .abs(),
        ).isCloseTo(0.0, 1e-7);
      }

      final cIntegrand = Expr.parse('f^x * x / (a + b * f^(2 * x))');
      final cAnti = cIntegrand.integrate('x');
      final cEnv = {
        'x': const Complex(-0.6, 0.25),
        'f': const Complex(2.3, 0.2),
        'a': const Complex(2.5, 0.3),
        'b': const Complex(0.6, 0.15),
      };
      check(
        (cAnti.derivative('x').evaluateComplex(cEnv) -
                cIntegrand.evaluateComplex(cEnv))
            .abs(),
      ).isCloseTo(0.0, 1e-8);
    });
  });
}
