import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Symbolic integration', () {
    test('indefinite integrals verified by differentiation', () {
      const integrands = [
        '3 * x^2 + 2 * x + 1',
        'sin(2 * x)',
        'x * exp(x)',
        '1 / (1 + x^2)',
        'x / (1 + x^2)',
        'ln(x)',
        'exp(x) * sin(x)',
        'erf(x)',
      ];
      for (final src in integrands) {
        final f = Expr.parse(src);
        final antideriv = f.integrate('x');
        final diff = antideriv.derivative('x');
        for (final pt in [0.5, 1.2, 2.0]) {
          check(diff.evaluate({'x': pt}))
              .isCloseTo(f.evaluate({'x': pt}), 1e-9);
        }
      }
    });

    test('definite integrals including improper bounds', () {
      final polyArea = Expr.parse('x^2').integrate('x', from: 0, to: 3);
      check(polyArea).equals(IntegerNumber.of(9));

      final expDecay = Expr.parse('exp(-x)')
          .integrate('x', from: 0, to: double.infinity);
      check(expDecay).equals(IntegerNumber.one);

      final lorentz = Expr.parse('1 / (1 + x^2)')
          .integrate('x', from: double.negativeInfinity, to: double.infinity);
      check(lorentz).equals(Constant.pi);
    });
  });
}
