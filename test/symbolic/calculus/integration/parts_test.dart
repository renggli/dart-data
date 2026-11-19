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
    });
  });
}
