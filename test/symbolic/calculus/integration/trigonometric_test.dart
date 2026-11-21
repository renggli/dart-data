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

    test('integrates multi-factor trigonometric products', () {
      verifyAntiderivative(
        Expr.parse('sin(x) * sin(2 * x) * sin(3 * x)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('cos(x) * cos(3 * x) * cos(5 * x)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('sin(4 * x) / sin(x)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('sin(23 * x) / sin(x)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('cos(x) / (1 - cos(2 * x))'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('tanh(x) / exp(x)'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('sin(x)^2 / cos(x)^2'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('sin(x)^2 * cos(x)^3'),
        points: const [0.2, 0.6, 1.0],
      );
      verifyAntiderivative(
        Expr.parse('1 / (sin(x)^2 * cos(x)^2)'),
        points: const [0.2, 0.6, 1.0],
      );
    });

    test('integrates polynomials times higher trig powers', () {
      for (final expr in const [
        'x * sin(x)^3',
        'x * cos(x)^3',
        'x * sin(x)^4',
        'x * cos(x)^4',
        'x * sin(x)^5',
        'x * cos(x)^5',
        'x * sin(x)^6',
        'x * cos(x)^6',
      ]) {
        verifyAntiderivative(Expr.parse(expr), points: const [0.3, 0.8]);
      }
    });

    test('integrates powered trig binomials times trig powers', () {
      verifyAntiderivative(
        Expr.parse('1 / cos(1 + 3 * x)^7'),
        points: const [0.1, 0.3],
      );
      verifyAntiderivative(
        Expr.parse('sin(1 + 3 * x)^2 / cos(1 + 3 * x)^7'),
        points: const [0.1, 0.3],
      );
      verifyAntiderivative(
        Expr.parse('(2 + 2 * sin(1 + 3 * x))^2 * cos(1 + 3 * x)^6'),
        points: const [0.1, 0.4],
      );
      verifyAntiderivative(
        Expr.parse('(2 + 2 * sin(1 + 3 * x))^2 / cos(1 + 3 * x)^7'),
        points: const [0.1, 0.3],
      );
      check(
        Expr.parse('(a + a * sin(c + d * x))^2 * cos(c + d * x)^6')
            .integrate('x'),
      ).isNotA<Integral>();
      check(
        Expr.parse('(a + a * sin(c + d * x))^2 / cos(c + d * x)^7')
            .integrate('x'),
      ).isNotA<Integral>();
    });
  });
}
