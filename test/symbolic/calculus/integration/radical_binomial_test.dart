import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  void verifyNoIntegralAndDerivative(
    String source, {
    required Map<String, double> realEnv,
    Map<String, Complex>? complexEnv,
    double tolerance = 1e-7,
  }) {
    final integrand = Expr.parse(source);
    final antideriv = integrand.integrate('x');
    check(antideriv.anyNode((n) => n is Integral)).isFalse;
    final deriv = antideriv.derivative('x');
    check((deriv.evaluate(realEnv) - integrand.evaluate(realEnv)).abs())
        .isCloseTo(0.0, tolerance);
    if (complexEnv != null) {
      check(
        (deriv.evaluateComplex(complexEnv) -
                integrand.evaluateComplex(complexEnv))
            .abs(),
      ).isCloseTo(0.0, tolerance);
    }
  }

  group('Quadratic radicals with negative integer powers', () {
    test('integrates sqrt(b*x + c*x^2) / x^6', () {
      verifyNoIntegralAndDerivative(
        'sqrt(b * x + c * x^2) / x^6',
        realEnv: {'x': 1.3, 'b': 2.1, 'c': 0.9},
        complexEnv: {
          'x': const Complex(1.3, 0.35),
          'b': const Complex(2.1, 0.2),
          'c': const Complex(0.9, 0.15),
        },
      );
    });

    test('integrates (A + B*x) * sqrt(b*x + c*x^2) / x^5', () {
      verifyNoIntegralAndDerivative(
        '(A + B * x) * sqrt(b * x + c * x^2) / x^5',
        realEnv: {'x': 1.25, 'A': 1.4, 'B': -0.6, 'b': 1.9, 'c': 1.1},
        complexEnv: {
          'x': const Complex(1.25, 0.3),
          'A': const Complex(1.4, 0.1),
          'B': const Complex(-0.6, 0.2),
          'b': const Complex(1.9, 0.15),
          'c': const Complex(1.1, 0.25),
        },
      );
    });
  });

  group('Fractional-linear and special binomial products', () {
    test('integrates fractional-linear product (A + B*x) / ((d + e*x)^(7/2) * (b*x + c*x^2))', () {
      verifyNoIntegralAndDerivative(
        '(A + B * x) / ((d + e * x)^(7/2) * (b * x + c * x^2))',
        realEnv: {
          'x': 0.75,
          'A': 1.1,
          'B': 0.7,
          'b': 1.8,
          'c': 1.3,
          'd': 2.2,
          'e': 0.9,
        },
        tolerance: 1e-6,
      );
    });

    test(
      'handles proportional linear factors in fractional-linear substitution',
      () {
        verifyNoIntegralAndDerivative(
          'sqrt(a + b * x) / (2 * a + 2 * b * x)^(3/2)',
          realEnv: {'x': 0.8, 'a': 1.5, 'b': 1.1},
        );
      },
    );

    test('integrates two-factor Chebyshev ratio with Hypergeometric', () {
      final integrand = Expr.parse('(a + b * x)^(1/3) / (c + d * x)^(7/3)');
      final antideriv = integrand.integrate('x');
      check(antideriv.anyNode((n) => n is Integral)).isFalse;
      final env = {'x': 0.45, 'a': 1.9, 'b': 0.7, 'c': 2.3, 'd': 0.6};
      check(
        (antideriv.derivative('x').evaluate(env) - integrand.evaluate(env))
            .abs(),
      ).isCloseTo(0.0, 1e-7);
    });

    test('integrates three-factor symbolic binomial product via AppellF1', () {
      final integrand = Expr.parse('(b * x)^m * (c + d * x)^n * (e + f * x)^p');
      final antideriv = integrand.integrate('x');
      check(antideriv.anyNode((n) => n is Integral)).isFalse;
      check(antideriv.anyNode((n) => n is AppellF1)).isTrue;
    });

    test('integrates degenerate quadratic radical product without factor fallthrough', () {
      const source = 'sqrt(c * x^2) * (a + b * x) / x';
      final integrand = Expr.parse(source);
      final antideriv = integrand.integrate('x');
      check(antideriv.anyNode((n) => n is Integral)).isFalse;
      check(antideriv == Expr.parse('sqrt(c * x^2) * (a + b * x)')).isFalse;
      verifyNoIntegralAndDerivative(
        source,
        realEnv: {'x': 1.2, 'a': 1.7, 'b': 0.9, 'c': 2.3},
        complexEnv: {
          'x': const Complex(0.37, 0.29),
          'a': const Complex(1.7, 0.21),
          'b': const Complex(0.83, 0.17),
          'c': const Complex(2.3, 0.13),
        },
      );
    });

    test('integrates two-factor Chebyshev linear radicals elementarily', () {
      const s1 = 'sqrt(c + d * x) / (a + b * x)^(3/2)';
      final a1 = Expr.parse(s1).integrate('x');
      check(a1.anyNode((n) => n is Integral)).isFalse;
      check(a1.anyNode((n) => n is Hypergeometric)).isFalse;
      verifyNoIntegralAndDerivative(
        s1,
        realEnv: {'x': 0.7, 'a': 1.7, 'b': 0.83, 'c': 2.3, 'd': 1.9},
        complexEnv: {
          'x': const Complex(0.37, 0.29),
          'a': const Complex(1.7, 0.21),
          'b': const Complex(0.83, 0.17),
          'c': const Complex(2.3, 0.13),
          'd': const Complex(1.9, 0.23),
        },
      );

      final s2 = Expr.parse('(a - i * a * x)^(1/4) / (a + i * a * x)^(1/4)');
      final a2 = s2.integrate('x');
      check(a2.anyNode((n) => n is Integral)).isFalse;
      check(a2.anyNode((n) => n is Hypergeometric)).isFalse;
      final cEnv = {
        'x': const Complex(0.37, 0.29),
        'a': const Complex(1.7, 0.21),
      };
      check(
        (a2.derivative('x').evaluateComplex(cEnv) - s2.evaluateComplex(cEnv))
            .abs(),
      ).isCloseTo(0.0, 1e-8);
    });
  });
}
