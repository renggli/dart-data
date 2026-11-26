import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  void verifyNoIntegralAndDerivative(
    String source, {
    required Map<String, Object> realEnv,
    Map<String, Object>? complexEnv,
    double tolerance = 1e-8,
  }) {
    final integrand = Expr.parse(source);
    final antideriv = integrand.integrate('x');
    check(antideriv.anyNode((n) => n is Integral)).isFalse;
    final deriv = antideriv.derivative('x');
    final realMap = realEnv.map((k, v) => MapEntry(k, (v as num).toDouble()));
    check((deriv.evaluate(realMap) - integrand.evaluate(realMap)).abs())
        .isCloseTo(0.0, tolerance);
    if (complexEnv != null) {
      final cMap = complexEnv.map(
        (k, v) =>
            MapEntry(k, v is Complex ? v : Complex((v as num).toDouble())),
      );
      check(
        (deriv.evaluateComplex(cMap) - integrand.evaluateComplex(cMap)).abs(),
      ).isCloseTo(0.0, tolerance);
    }
  }

  group('High-degree linear and multi-factor denominators', () {
    test('integrates high-power linear denominator ratio', () {
      verifyNoIntegralAndDerivative(
        'x^12 / (a + b * x)^10',
        realEnv: {'x': 0.7, 'a': 1.9, 'b': 1.3},
        complexEnv: {
          'x': const Complex(0.7, 0.3),
          'a': const Complex(1.9, 0.2),
          'b': const Complex(1.3, 0.4),
        },
        tolerance: 1e-7,
      );
    });

    test('integrates repeated two-factor linear denominator', () {
      verifyNoIntegralAndDerivative(
        'x^5 / ((a + b * x)^3 * (c + d * x)^3)',
        realEnv: {'x': 0.45, 'a': 1.7, 'b': 0.9, 'c': 2.3, 'd': -0.8},
        complexEnv: {
          'x': const Complex(0.45, 0.25),
          'a': const Complex(1.7, 0.15),
          'b': const Complex(0.9, 0.2),
          'c': const Complex(2.3, 0.1),
          'd': const Complex(-0.8, 0.3),
        },
        tolerance: 1e-7,
      );
    });
  });

  group('Factored binomial powers denominators', () {
    test('integrates even-power residue-class binomial denominator', () {
      verifyNoIntegralAndDerivative(
        '(A + B * x^2) / (x^7 * (a + b * x^2)^3)',
        realEnv: {'x': 1.15, 'A': 1.3, 'B': -0.7, 'a': 2.1, 'b': 0.9},
        complexEnv: {
          'x': const Complex(1.15, 0.35),
          'A': const Complex(1.3, 0.2),
          'B': const Complex(-0.7, 0.1),
          'a': const Complex(2.1, 0.25),
          'b': const Complex(0.9, 0.15),
        },
        tolerance: 1e-7,
      );
    });

    test('integrates cubic-power residue-class binomial denominator', () {
      verifyNoIntegralAndDerivative(
        '(A + B * x^3) / (x^7 * (a + b * x^3)^2)',
        realEnv: {'x': 1.1, 'A': 1.5, 'B': 0.8, 'a': 1.9, 'b': 1.2},
        complexEnv: {
          'x': const Complex(1.1, 0.3),
          'A': const Complex(1.5, 0.1),
          'B': const Complex(0.8, 0.2),
          'a': const Complex(1.9, 0.15),
          'b': const Complex(1.2, 0.25),
        },
        tolerance: 1e-7,
      );
    });
  });
}
