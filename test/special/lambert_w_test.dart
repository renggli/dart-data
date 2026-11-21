import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('Lambert W function', () {
    test('Lambert W0 known values', () {
      check(lambertW(0.0)).equals(0.0);
      check(lambertW(math.e)).isCloseTo(1.0, 1e-7);
      check(lambertW(-1.0 / math.e)).isCloseTo(-1.0, 1e-6);
      check(lambertW(-0.5)).isNaN; // < -1/e
      check(lambertW(double.infinity)).equals(double.infinity);
      check(lambertW(1e307).isFinite).isTrue;

      final wLarge = lambertW(1e300);
      check(wLarge + math.log(wLarge)).isCloseTo(math.log(1e300), 1e-12);

      final wVal = lambertW(2.0);
      check(wVal * math.exp(wVal)).isCloseTo(2.0, 1e-9);
    });

    test('Lambert W1 known values', () {
      check(lambertW(0.0, branch: -1)).isNaN;
      check(lambertW(1.0, branch: -1)).isNaN;
      check(lambertW(-1.0 / math.e, branch: -1)).isCloseTo(-1.0, 1e-5);
      final wVal = lambertW(-0.1, branch: -1);
      check(wVal * math.exp(wVal)).isCloseTo(-0.1, 1e-7);
      // Small negative z where exp(w) underflows: W1(-1e-200) ~ ln(1e-200) ~ -460.5
      final wSmall = lambertW(-1e-200, branch: -1);
      check(wSmall).isLessThan(-450.0);
      check(wSmall).isGreaterThan(-500.0);
      check(wSmall + math.log(-wSmall)).isCloseTo(math.log(1e-200), 1e-12);

      final wTiny = lambertW(-1e-320, branch: -1);
      check(wTiny + math.log(-wTiny)).isCloseTo(math.log(1e-320), 1e-12);
    });

    test('Lambert W branch near branch point (-1/e < z < -0.3)', () {
      const zNear = -0.35;
      final w0 = lambertW(zNear);
      check(w0).isGreaterThan(-1.0);
      check(w0 * math.exp(w0)).isCloseTo(zNear, 1e-9);

      final w1 = lambertW(zNear, branch: -1);
      check(w1).isLessThan(-1.0);
      check(w1 * math.exp(w1)).isCloseTo(zNear, 1e-9);

      const invE = 1.0 / math.e;
      check(lambertW(-invE + 2e-15)).isCloseTo(-1.0, 1e-6);
      check(() => lambertW(0.0, branch: 1)).throws<ArgumentError>();
    });
  });
}
