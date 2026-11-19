import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

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
  });
}
