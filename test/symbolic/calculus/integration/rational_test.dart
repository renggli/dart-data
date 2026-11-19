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

  group('Repeated quadratic and cyclotomic rational integration', () {
    test('integrates repeated irreducible quadratic denominators', () {
      verifyAntiderivative(
        Expr.parse('1 / (x^2 + 1)^2'),
        points: const [0.2, 0.7, 1.3],
      );
      verifyAntiderivative(
        Expr.parse('x^2 / (x^2 + 1)^2'),
        points: const [0.2, 0.7, 1.3],
      );
      verifyAntiderivative(
        Expr.parse('1 / (x^2 + 2 * x + 5)^2'),
        points: const [0.2, 0.7, 1.3],
      );
    });

    test(
      'integrates cyclotomic cubic/quartic denominators and guards high degree',
      () {
        verifyAntiderivative(
          Expr.parse('x / (x^3 + 1)'),
          points: const [0.2, 0.7, 1.3],
        );
        verifyAntiderivative(
          Expr.parse('1 / (x^4 + 1)'),
          points: const [0.2, 0.7, 1.3],
        );

        verifyAntiderivative(
          Expr.parse('1 / (x^4 + 2 * x^2 + 1)'),
          points: const [0.2, 0.7, 1.3],
        );
        verifyAntiderivative(
          Expr.parse('1 / (x + 1 / x)^2'),
          points: const [0.4, 0.7, 1.3],
        );
        verifyAntiderivative(
          Expr.parse('x^9 / (x^20 - 48 * x^10 + 575)'),
          points: const [0.4, 0.7, 0.9],
        );
        verifyAntiderivative(
          Expr.parse('(2 * x^2022 + 1) / (x^2023 + x)'),
          points: const [1.0, 1.01, 1.02],
        );

        final highDeg = Expr.parse('1 / (x^2023 + x + 1)');
        check(highDeg.integrate('x').toString()).contains('integrate(');
      },
    );
  });
}
