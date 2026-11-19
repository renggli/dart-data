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
      check(xLnX).equals(Ln(Abs(Ln(x))));
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
    });
  });
}
