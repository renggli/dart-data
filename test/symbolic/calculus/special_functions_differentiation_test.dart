import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('LambertW analytical derivative', () {
    test('derivative of W(x)', () {
      final dw = const LambertW(x).derivative('x').simplify();
      check(dw.dependsOn('x')).isTrue();
      // At x = 0, W(0) = 0, derivative is 1 / (e^0 * (1 + 0)) = 1.0
      check(dw.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-12);
    });

    test('derivative of W(2x)', () {
      final dw = const LambertW(Mul(RationalNumber(2), x))
          .derivative('x')
          .simplify();
      // At x = 0, derivative is 2 / (e^0 * 1) = 2.0
      check(dw.evaluate({'x': 0.0})).isCloseTo(2.0, 1e-12);
    });
  });

  group('Erf & Erfc analytical derivative', () {
    test('derivative of erf(x)', () {
      final der = const Erf(x).derivative('x').simplify();
      // At x = 0: 2 / sqrt(pi) * exp(0) = 2 / sqrt(pi) approx 1.128379167
      check(der.evaluate({'x': 0.0})).isCloseTo(1.1283791670955126, 1e-10);
    });

    test('derivative of erfc(x)', () {
      final der = const Erfc(x).derivative('x').simplify();
      // At x = 0: -2 / sqrt(pi)
      check(der.evaluate({'x': 0.0})).isCloseTo(-1.1283791670955126, 1e-10);
    });
  });

  group('Inverse hyperbolic analytical derivatives', () {
    test('derivative of asinh(x) is 1 / sqrt(x^2 + 1)', () {
      final der = const Asinh(x).derivative('x').simplify();
      check(der.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-12);
      check(der.evaluate({'x': 1.0}))
          .isCloseTo(1.0 / 1.4142135623730951, 1e-10);
    });

    test('derivative of acosh(x) is 1 / sqrt(x^2 - 1)', () {
      final der = const Acosh(x).derivative('x').simplify();
      check(der.evaluate({'x': 2.0}))
          .isCloseTo(1.0 / 1.7320508075688772, 1e-10);
    });

    test('derivative of atanh(x) is 1 / (1 - x^2)', () {
      final der = const Atanh(x).derivative('x').simplify();
      check(der.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-12);
      check(der.evaluate({'x': 0.5})).isCloseTo(1.0 / 0.75, 1e-10);
    });
  });

  group('Gamma & Beta derivatives', () {
    test('Gamma independent of variable evaluates to 0', () {
      final der = const Gamma(Variable('a')).derivative('x');
      check(der).equals(RationalNumber.zero);
    });

    test('Gamma dependent on variable throws UnsupportedError', () {
      check(() => const Gamma(x).derivative('x')).throws<UnsupportedError>();
    });

    test('Beta dependent on variable throws UnsupportedError', () {
      check(() => const Beta(x, RationalNumber.one).derivative('x'))
          .throws<UnsupportedError>();
    });
  });
}
