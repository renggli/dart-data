import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('error function', () {
    const errorFunctionTuples = <(double, double)>[
      (double.negativeInfinity, -1.0),
      (-10.0, -1.0),
      (-3.0, -0.99997791),
      (-2.0, -0.99532226),
      (-1.0, -0.84270079),
      (-0.1, -0.11246291),
      (-0.5, -0.52049987),
      (0.0, 0.00000000),
      (0.1, 0.11246291),
      (0.5, 0.52049987),
      (1.0, 0.84270079),
      (2.0, 0.99532226),
      (3.0, 0.99997791),
      (10.0, 1.0),
      (double.infinity, 1.0),
    ];

    test('erf', () {
      for (final (x, expected) in errorFunctionTuples) {
        check(because: 'erf($x)', erf(x)).isCloseTo(expected, 1e-6);
      }
    });

    test('erfc', () {
      for (final (x, expected) in errorFunctionTuples) {
        check(because: 'erfc($x)', erfc(x)).isCloseTo(1.0 - expected, 1e-6);
      }
    });

    test('erfInv and erfcInv', () {
      check(erfInv(0.0)).equals(0.0);
      check(erfInv(-1.0)).equals(double.negativeInfinity);
      check(erfInv(1.0)).equals(double.infinity);
      check(erfInv(2.0)).isNaN();
      check(erfInv(-2.0)).isNaN();

      check(erfInv(erf(0.5))).isCloseTo(0.5, 1e-12);
      check(erfInv(erf(-0.75))).isCloseTo(-0.75, 1e-12);
      check(erfcInv(erfc(0.5))).isCloseTo(0.5, 1e-12);

      // Deep tail tests without cancellation or premature overflow
      check(erfcInv(0.0)).equals(double.infinity);
      check(erfcInv(2.0)).equals(double.negativeInfinity);
      check(erfcInv(1.0)).equals(0.0);
      check(erfcInv(-0.1)).isNaN();
      check(erfcInv(2.1)).isNaN();

      // For erfc(5.0) ≈ 1.5374597944280348e-12
      final y5 = erfc(5.0);
      check(erfcInv(y5)).isCloseTo(5.0, 1e-10);

      // Deep tail: erfc(8.0) ≈ 1.1224421110037894e-29
      final y8 = erfc(8.0);
      check(erfcInv(y8)).isCloseTo(8.0, 1e-8);

      // Small probabilities e.g. 1e-20 do not return infinity
      check(erfcInv(1e-20).isFinite).isTrue();
      check(erfcInv(1e-20)).isGreaterThan(6.0);
    });

    test('erf and erfc near-machine precision (Cody)', () {
      // Reference: erf(1.0) = 0.84270079294971486934
      check(erf(1.0)).isCloseTo(0.8427007929497149, 1e-15);
      // Reference: erfc(1.0) = 0.15729920705028513066
      check(erfc(1.0)).isCloseTo(0.15729920705028513, 1e-15);
      // Deep tail: erfc(10.0) = 2.0884875837625446e-45
      check(erfc(10.0)).isCloseTo(2.0884875837625446e-45, 1e-55);
      check(erfc(-10.0)).equals(2.0);
    });
  });
}
