import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('M4 Reverification Task 2: Reciprocal Equations Equated to Zero', () {
    test('1 / x = 0 returns empty list without throwing', () {
      final eq = const RationalNumber(1) / x;
      check(eq.solve('x')).isEmpty();
    });

    test(
      'c / x = 0 for various constants returns empty list without throwing',
      () {
        final numerators = <Expr>[
          const RationalNumber(2),
          const RationalNumber(-5),
          const RationalNumber(1, 3),
          const RationalNumber(-4, 7),
          const RealNumber(1.5),
          const RealNumber(-2.7),
          i,
          const RationalNumber(2) * i,
          const RationalNumber(1) + i,
        ];

        for (final num in numerators) {
          final eq = num / x;
          check(eq.solve('x')).isEmpty();
        }
      },
    );

    test('reciprocal trigonometric equations equated to zero', () {
      // 1 / sin(x) = 0
      check((const RationalNumber(1) / const Sin(x)).solve('x')).isEmpty();
      // 1 / cos(x) = 0
      check((const RationalNumber(1) / const Cos(x)).solve('x')).isEmpty();
      // 1 / tan(x) = 0
      check((const RationalNumber(1) / const Tan(x)).solve('x')).isEmpty();
      // -3 / sin(x) = 0
      check((const RationalNumber(-3) / const Sin(x)).solve('x')).isEmpty();
      // (1 + i) / sin(x) = 0
      check(((const RationalNumber(1) + i) / const Sin(x)).solve('x'))
          .isEmpty();
    });

    test(
      'reciprocal polynomials and transcendental expressions equated to zero',
      () {
        // 1 / (x^2 + 1) = 0
        check(
          (const RationalNumber(1) /
                  (x.pow(const RationalNumber(2)) + const RationalNumber(1)))
              .solve('x'),
        ).isEmpty();
        // 5 / (x + 3) = 0
        check(
          (const RationalNumber(5) / (x + const RationalNumber(3))).solve('x'),
        ).isEmpty();
        // 1 / exp(x) = 0
        check((const RationalNumber(1) / const Exp(x)).solve('x')).isEmpty();
        // 2 / ln(x) = 0
        check((const RationalNumber(2) / const Ln(x)).solve('x')).isEmpty();
      },
    );
  });

  group('M4 Reverification Task 3: Dual Fundamental Roots in [0, 2pi)', () {
    test('sin(x) = 1/3 yields 2 fundamental roots in [0, 2pi)', () {
      final eq = const Sin(x) - const RationalNumber(1, 3);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      // Verify exact symbolic representations
      check(roots).contains(const Asin(RationalNumber(1, 3)));
      check(roots)
          .contains(ConstantNumber.pi - const Asin(RationalNumber(1, 3)));

      // Verify numerical values fall strictly in [0, 2*pi) and satisfy sin(r) = 1/3
      for (final root in roots) {
        final val = root.evaluate(const {});
        check(val).isGreaterOrEqual(0.0);
        check(val).isLessThan(2 * math.pi);
        check((math.sin(val) - 1.0 / 3.0).abs()).isLessThan(1e-12);
      }
    });

    test('cos(x) = 1/3 yields 2 fundamental roots in [0, 2pi)', () {
      final eq = const Cos(x) - const RationalNumber(1, 3);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      // Verify exact symbolic representations
      check(roots).contains(const Acos(RationalNumber(1, 3)));
      check(roots).contains(
        const Mul(RationalNumber(2), ConstantNumber.pi) -
            const Acos(RationalNumber(1, 3)),
      );

      // Verify numerical values fall strictly in [0, 2*pi) and satisfy cos(r) = 1/3
      for (final root in roots) {
        final val = root.evaluate(const {});
        check(val).isGreaterOrEqual(0.0);
        check(val).isLessThan(2 * math.pi);
        check((math.cos(val) - 1.0 / 3.0).abs()).isLessThan(1e-12);
      }
    });

    test('tan(x) = 1/3 yields 2 fundamental roots in [0, 2pi)', () {
      final eq = const Tan(x) - const RationalNumber(1, 3);
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      // Verify exact symbolic representations
      check(roots).contains(const Atan(RationalNumber(1, 3)));
      check(roots).contains(
        (ConstantNumber.pi + const Atan(RationalNumber(1, 3))).simplify(),
      );

      // Verify numerical values fall strictly in [0, 2*pi) and satisfy tan(r) = 1/3
      for (final root in roots) {
        final val = root.evaluate(const {});
        check(val).isGreaterOrEqual(0.0);
        check(val).isLessThan(2 * math.pi);
        check((math.tan(val) - 1.0 / 3.0).abs()).isLessThan(1e-12);
      }
    });

    test('general non-special constants across sin, cos, tan', () {
      final testCases = [
        const RationalNumber(1, 4),
        const RationalNumber(2, 5),
        const RationalNumber(3, 7),
        const RationalNumber(7, 10),
      ];

      for (final c in testCases) {
        // sin(x) = c
        final eqSin = const Sin(x) - c;
        final rootsSin = eqSin.solve('x');
        check(rootsSin.length).equals(2);
        for (final r in rootsSin) {
          final v = r.evaluate(const {});
          check(v).isGreaterOrEqual(0.0);
          check(v).isLessThan(2 * math.pi);
          check((math.sin(v) - c.toDouble()).abs()).isLessThan(1e-12);
        }

        // cos(x) = c
        final eqCos = const Cos(x) - c;
        final rootsCos = eqCos.solve('x');
        check(rootsCos.length).equals(2);
        for (final r in rootsCos) {
          final v = r.evaluate(const {});
          check(v).isGreaterOrEqual(0.0);
          check(v).isLessThan(2 * math.pi);
          check((math.cos(v) - c.toDouble()).abs()).isLessThan(1e-12);
        }

        // tan(x) = c
        final eqTan = const Tan(x) - c;
        final rootsTan = eqTan.solve('x');
        check(rootsTan.length).equals(2);
        for (final r in rootsTan) {
          final v = r.evaluate(const {});
          check(v).isGreaterOrEqual(0.0);
          check(v).isLessThan(2 * math.pi);
          check((math.tan(v) - c.toDouble()).abs()).isLessThan(1e-12);
        }
      }
    });
    test('general negative constants across sin, cos, tan', () {
      const c = RationalNumber(-1, 3);
      final rootsSin = (const Sin(x) - c).solve('x');
      final rootsCos = (const Cos(x) - c).solve('x');
      final rootsTan = (const Tan(x) - c).solve('x');

      check(rootsSin.length).equals(2);
      check(rootsCos.length).equals(2);
      check(rootsTan.length).equals(2);

      for (final r in rootsSin) {
        final v = r.evaluate(const {});
        check((math.sin(v) - (-1.0 / 3.0)).abs()).isLessThan(1e-12);
      }
      for (final r in rootsCos) {
        final v = r.evaluate(const {});
        check((math.cos(v) - (-1.0 / 3.0)).abs()).isLessThan(1e-12);
      }
      for (final r in rootsTan) {
        final v = r.evaluate(const {});
        check((math.tan(v) - (-1.0 / 3.0)).abs()).isLessThan(1e-12);
      }
    });
  });
}
