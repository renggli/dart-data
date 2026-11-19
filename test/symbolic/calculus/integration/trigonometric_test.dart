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
    });
  });
}
