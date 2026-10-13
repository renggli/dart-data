import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('Pattern 1: f(x) * exp(f(x)) = c', () {
    test('c > 0 produces single real branch W_0', () {
      // x * exp(x) = 2
      const eq = Sub(Mul(x, Exp(x)), RationalNumber(2));
      final roots = eq.solve('x');
      check(roots.length).equals(1);
      final root = roots.first;
      check(root).equals(const LambertW(RationalNumber(2), branch: 0));

      // Verify numerical satisfaction
      final xVal = root.evaluate(const {});
      final fVal = xVal * math.exp(xVal);
      check(fVal).isCloseTo(2.0, 1e-12);
    });

    test('-1/e < c < 0 produces two real branches W_0 and W_-1', () {
      // x * exp(x) = -0.2
      const eq = Sub(Mul(x, Exp(x)), RealNumber(-0.2));
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      for (final root in roots) {
        final xVal = root.evaluate(const {});
        final fVal = xVal * math.exp(xVal);
        check(fVal).isCloseTo(-0.2, 1e-10);
      }
    });

    test('c = -1/e produces unique real root -1', () {
      // x * exp(x) = -1/e
      const invE = Div(RationalNumber.negativeOne, ConstantNumber.e);
      const eq = Sub(Mul(x, Exp(x)), invE);
      final roots = eq.solve('x');
      check(roots.length).equals(1);
      check(roots.first.evaluate(const {})).isCloseTo(-1.0, 1e-10);
    });

    test('c < -1/e produces empty real solution set', () {
      // x * exp(x) = -0.5 (since -0.5 < -1/e approx -0.368)
      const eq = Sub(Mul(x, Exp(x)), RealNumber(-0.5));
      final roots = eq.solve('x');
      check(roots).isEmpty();
    });

    test('scaled coefficient and exponent: x * exp(2x) = 3', () {
      // 2x * exp(2x) = 6 -> 2x = W_0(6) -> x = W_0(6) / 2
      const eq = Sub(Mul(x, Exp(Mul(RationalNumber(2), x))), RationalNumber(3));
      final roots = eq.solve('x');
      check(roots.length).equals(1);

      final xVal = roots.first.evaluate(const {});
      final fVal = xVal * math.exp(2.0 * xVal);
      check(fVal).isCloseTo(3.0, 1e-10);
    });
  });

  group('Pattern 2: f(x) + ln(f(x)) = c', () {
    test('x + ln(x) = 2', () {
      const eq = Sub(Add(x, Ln(x)), RationalNumber(2));
      final roots = eq.solve('x');
      check(roots.length).equals(1);

      final xVal = roots.first.evaluate(const {});
      final fVal = xVal + math.log(xVal);
      check(fVal).isCloseTo(2.0, 1e-10);
    });
  });

  group('Pattern 3: x^x = c', () {
    test('x^x = 3', () {
      const eq = Sub(Pow(x, x), RationalNumber(3));
      final roots = eq.solve('x');
      check(roots.isNotEmpty).isTrue();

      final xVal = roots.first.evaluate(const {});
      final fVal = math.pow(xVal, xVal).toDouble();
      check(fVal).isCloseTo(3.0, 1e-10);
    });

    test('x^x = 0.5 produces empty real solution set (ln(0.5) < -1/e)', () {
      const eq = Sub(Pow(x, x), RealNumber(0.5));
      final roots = eq.solve('x');
      check(roots).isEmpty();
    });
  });

  group('Pattern 4: x * ln(x) = c', () {
    test('x * ln(x) = 2', () {
      const eq = Sub(Mul(x, Ln(x)), RationalNumber(2));
      final roots = eq.solve('x');
      check(roots.length).equals(1);

      final xVal = roots.first.evaluate(const {});
      final fVal = xVal * math.log(xVal);
      check(fVal).isCloseTo(2.0, 1e-10);
    });

    test('x * ln(x) = -0.5 produces empty real solution set (-0.5 < -1/e)', () {
      const eq = Sub(Mul(x, Ln(x)), RealNumber(-0.5));
      final roots = eq.solve('x');
      check(roots).isEmpty();
    });

    test('x * ln(x) = -0.2 produces two real branch solutions', () {
      const eq = Sub(Mul(x, Ln(x)), RealNumber(-0.2));
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      for (final root in roots) {
        final xVal = root.evaluate(const {});
        final fVal = xVal * math.log(xVal);
        check(fVal).isCloseTo(-0.2, 1e-10);
      }
    });
  });

  group('Pattern 5: a^x = bx + c', () {
    test('2^x = 2x yields solutions x = 1 and x = 2', () {
      const eq = Sub(Pow(RationalNumber(2), x), Mul(RationalNumber(2), x));
      final roots = eq.solve('x');
      check(roots.length).equals(2);

      final numericRoots = roots.map((r) => r.evaluate(const {})).toList()
        ..sort();
      check(numericRoots[0]).isCloseTo(1.0, 1e-10);
      check(numericRoots[1]).isCloseTo(2.0, 1e-10);
    });

    test('e^x = x + 1 yields unique tangent solution x = 0', () {
      const eq = Sub(Sub(Exp(x), x), RationalNumber.one);
      final roots = eq.solve('x');
      check(roots.length).equals(1);
      check(roots.first.evaluate(const {})).isCloseTo(0.0, 1e-10);
    });

    test('2^x = x - 5 produces empty real solution set', () {
      // 2^x - x + 5 = 0 has no real roots
      const eq = Add(Sub(Pow(RationalNumber(2), x), x), RationalNumber(5));
      final roots = eq.solve('x');
      check(roots).isEmpty();
    });
  });

  group('Direct Lambert W and inverse hyperbolics inversion', () {
    test('W_0(x) = 1 -> x = e', () {
      const eq = Sub(LambertW(x), RationalNumber.one);
      final roots = eq.solve('x');
      check(roots.length).equals(1);
      check(roots.first.evaluate(const {})).isCloseTo(math.e, 1e-12);
    });

    test('asinh(x) = 1 -> x = sinh(1)', () {
      const eq = Sub(Asinh(x), RationalNumber.one);
      final roots = eq.solve('x');
      check(roots.length).equals(1);
      const sinh1 = (math.e - 1.0 / math.e) / 2.0;
      check(roots.first.evaluate(const {})).isCloseTo(sinh1, 1e-12);
    });
  });
}
