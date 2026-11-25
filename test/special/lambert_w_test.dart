import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('lambertW', () {
    test('evaluates principal branch W_0 across standard and large inputs', () {
      check(lambertW(0.0)).equals(0.0);
      check(lambertW(math.e)).isCloseTo(1.0, 1e-14);
      check(lambertW(-1.0 / math.e)).equals(-1.0);

      final wVal = lambertW(2.0);
      check(wVal * math.exp(wVal)).isCloseTo(2.0, 1e-14);

      for (final x in [1e300, 1e307]) {
        final wLarge = lambertW(x);
        check(wLarge + math.log(wLarge)).isCloseTo(math.log(x), 1e-12);
      }
    });

    test('evaluates secondary branch W_{-1} including subnormal inputs', () {
      check(lambertW(0.0, branch: -1)).equals(double.negativeInfinity);
      check(lambertW(-1.0 / math.e, branch: -1)).equals(-1.0);

      final wVal = lambertW(-0.1, branch: -1);
      check(wVal * math.exp(wVal)).isCloseTo(-0.1, 1e-14);

      for (final x in [-1e-200, -1e-320]) {
        final wSmall = lambertW(x, branch: -1);
        check(wSmall + math.log(-wSmall)).isCloseTo(math.log(-x), 1e-12);
      }
    });

    test('maintains continuity near branch point and validates domains', () {
      const zNear = -0.35;
      final w0 = lambertW(zNear);
      check(w0).isGreaterThan(-1.0);
      check(w0 * math.exp(w0)).isCloseTo(zNear, 1e-14);

      final w1 = lambertW(zNear, branch: -1);
      check(w1).isLessThan(-1.0);
      check(w1 * math.exp(w1)).isCloseTo(zNear, 1e-14);

      const invE = 1.0 / math.e;
      final wClose = lambertW(-invE + 1e-15);
      check(wClose * math.exp(wClose)).isCloseTo(-invE + 1e-15, 1e-15);

      check(lambertW(-0.5)).isNaN;
      check(lambertW(-invE - 1e-14)).isNaN;
      check(lambertW(1.0, branch: -1)).isNaN;
      check(lambertW(double.infinity)).equals(double.infinity);
      check(() => lambertW(0.0, branch: 1)).throws<ArgumentError>();
    });
  });

  group('lambertWComplex', () {
    test('matches real values and satisfies W*exp(W) == z across branches', () {
      check(lambertWComplex(const Complex(2.0)).a)
          .isCloseTo(lambertW(2.0), 1e-14);
      check(lambertWComplex(const Complex(-0.1), branch: -1).a)
          .isCloseTo(lambertW(-0.1, branch: -1), 1e-14);

      for (final z in const [
        Complex(-1.5, 0.4),
        Complex(0.5, 1.2),
        Complex(10.0, -3.0),
        Complex(-0.35, 0.05),
      ]) {
        final w0 = lambertWComplex(z);
        check((w0 * w0.exp() - z).abs()).isLessThan(1e-12);
      }

      for (final z in const [Complex(-0.2, 0.3), Complex(-0.35, 0.05)]) {
        final w1 = lambertWComplex(z, branch: -1);
        check((w1 * w1.exp() - z).abs()).isLessThan(1e-12);
      }
    });

    test('avoids overflow/underflow for huge and tiny arguments', () {
      const zHuge = Complex(1e150, 1e140);
      final wHuge = lambertWComplex(zHuge);
      check((wHuge + wHuge.log() - zHuge.log()).abs()).isLessThan(1e-12);

      const zTiny = Complex(1e-150, 1e-150);
      final wTiny = lambertWComplex(zTiny, branch: -1);
      check(
        (wTiny +
                wTiny.log() -
                (zTiny.log() - const Complex(0.0, 2.0 * math.pi)))
            .abs(),
      ).isLessThan(1e-12);
    });

    test('handles zero, infinities, NaN, and invalid branches', () {
      check(lambertWComplex(Complex.zero)).equals(Complex.zero);
      check(lambertWComplex(Complex.zero, branch: -1))
          .equals(const Complex(double.negativeInfinity));
      check(lambertWComplex(const Complex(double.infinity)))
          .equals(const Complex(double.infinity));
      check(lambertWComplex(const Complex(double.infinity), branch: -1).isNaN)
          .isTrue;
      check(lambertWComplex(Complex.nan).isNaN).isTrue;
      check(lambertWComplex(const Complex(double.infinity, 1.0)).isNaN).isTrue;
      check(() => lambertWComplex(Complex.one, branch: 2))
          .throws<ArgumentError>();
    });
  });
}
