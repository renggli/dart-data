import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('LambertW integration', () {
    test('continuous pole-free anti-derivative int W(x) dx', () {
      const f = LambertW(x);
      final anti = f.integrate('x').simplify();
      check(anti.dependsOn('x')).isTrue();

      // Verify F(0) = 0*(W(0)-1) + e^W(0) = 0 + 1 = 1.0
      check(anti.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-12);

      // Verify d/dx [F(x)] = W(x) numerically
      final dAnti = anti.derivative('x').simplify();
      for (final val in [0.2, 0.5, 1.0, 2.0]) {
        check(dAnti.evaluate({'x': val}))
            .isCloseTo(f.evaluate({'x': val}), 1e-8);
      }
    });

    test('anti-derivative of affine argument W(2x + 1)', () {
      const f = LambertW(Add(Mul(RationalNumber(2), x), RationalNumber.one));
      final anti = f.integrate('x').simplify();
      final dAnti = anti.derivative('x').simplify();
      for (final val in [0.0, 0.5, 1.0]) {
        check(dAnti.evaluate({'x': val}))
            .isCloseTo(f.evaluate({'x': val}), 1e-8);
      }
    });
  });

  group('Erf & Erfc integration', () {
    test('anti-derivative of erf(x)', () {
      const f = Erf(x);
      final anti = f.integrate('x').simplify();
      final dAnti = anti.derivative('x').simplify();
      for (final val in [-1.0, -0.5, 0.0, 0.5, 1.0]) {
        check(dAnti.evaluate({'x': val}))
            .isCloseTo(f.evaluate({'x': val}), 1e-8);
      }
    });

    test('anti-derivative of erfc(x)', () {
      const f = Erfc(x);
      final anti = f.integrate('x').simplify();
      final dAnti = anti.derivative('x').simplify();
      for (final val in [-1.0, 0.0, 1.0]) {
        check(dAnti.evaluate({'x': val}))
            .isCloseTo(f.evaluate({'x': val}), 1e-8);
      }
    });
  });

  group('Inverse hyperbolic integration', () {
    test('anti-derivative of asinh(x)', () {
      const f = Asinh(x);
      final anti = f.integrate('x').simplify();
      final dAnti = anti.derivative('x').simplify();
      for (final val in [-0.5, 0.0, 0.5, 1.0]) {
        check(dAnti.evaluate({'x': val}))
            .isCloseTo(f.evaluate({'x': val}), 1e-8);
      }
    });

    test('anti-derivative of acosh(x)', () {
      const f = Acosh(x);
      final anti = f.integrate('x').simplify();
      final dAnti = anti.derivative('x').simplify();
      for (final val in [1.5, 2.0, 3.0]) {
        check(dAnti.evaluate({'x': val}))
            .isCloseTo(f.evaluate({'x': val}), 1e-8);
      }
    });

    test('anti-derivative of atanh(x)', () {
      const f = Atanh(x);
      final anti = f.integrate('x').simplify();
      final dAnti = anti.derivative('x').simplify();
      for (final val in [-0.5, 0.0, 0.5]) {
        check(dAnti.evaluate({'x': val}))
            .isCloseTo(f.evaluate({'x': val}), 1e-8);
      }
    });
  });

  group('Gamma & Beta integration contract', () {
    test('Gamma throws UnsupportedError', () {
      check(() => const Gamma(x).integrate('x')).throws<UnsupportedError>();
    });

    test('Beta throws UnsupportedError', () {
      check(() => const Beta(x, Variable('y')).integrate('x'))
          .throws<UnsupportedError>();
    });
  });
}
