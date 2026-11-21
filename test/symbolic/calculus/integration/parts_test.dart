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
      verifyAntiderivative(
        Expr.parse('x * ln(1 + 1 / x)'),
        points: const [0.5, 1.0, 2.0],
      );
      check(
        Expr.parse('ln(x^2 + 1)').integrate('x'),
      ).equals(Expr.parse('x * ln(x^2 + 1) - 2 * x + 2 * atan(x)').simplify());
      verifyAntiderivative(
        Expr.parse('ln((x + 1) / (1 - x))'),
        points: const [-0.5, 0.2, 0.5],
      );
      verifyAntiderivative(
        Expr.parse('ln(x + 1) / x^2'),
        points: const [0.5, 1.0, 2.0],
      );
      verifyAntiderivative(
        Expr.parse('sin(x) * ln(sin(x))'),
        points: const [0.3, 0.7, 1.1],
      );
      verifyAntiderivative(
        Expr.parse('ln(cos(x)) / cos(x)^2'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('x * sec(4 * x)^2'),
        points: const [0.1, 0.2, 0.3],
      );
      verifyAntiderivative(
        Expr.parse('x * cosh(x) / sinh(x)^2'),
        points: const [0.4, 0.8, 1.2],
      );
      verifyAntiderivative(
        Expr.parse('cos(x) * cosh(x) + sin(x) * sinh(x)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('exp(x) * (cos(x)^2 + cos(x) * sin(x) - sin(x)^2)'),
        points: const [0.2, 0.6, 1.0],
      );
    });

    test('integrates powered inverse trig and inverse hyperbolic products', () {
      check(
        Expr.parse('(a + b * asinh(c * x))^2 * (d + e * x^2)').integrate('x'),
      ).isNotA<Integral>();
      check(
        Expr.parse('(a + b * asin(c * x)) * (d + e * x^2)^2 / x^2')
            .integrate('x'),
      ).isNotA<Integral>();

      verifyAntiderivative(
        Expr.parse('(1 + 2 * asinh(3 * x))^2 * (1 + 2 * x^2)'),
        points: const [0.2, 0.5, 0.8],
      );
      verifyAntiderivative(
        Expr.parse('(1 + 2 * asin(x / 2)) * (1 + 2 * x^2)^2 / x^2'),
        points: const [0.3, 0.6, 0.9],
      );
    });

    test(
      'integrates higher-degree polynomials times exp(a*x) * sin/cos(b*x)',
      () {
        verifyAntiderivative(
          Expr.parse('x^4 * e^(-x) * sin(x)'),
          points: const [0.2, 0.7, 1.3],
        );
        verifyAntiderivative(
          Expr.parse('x^3 * e^(2 * x) * cos(3 * x)'),
          points: const [0.1, 0.4, 0.8],
        );
      },
    );
  });
}
