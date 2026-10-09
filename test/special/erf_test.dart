import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/scaffolding.dart';

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
      for (final tuple in errorFunctionTuples) {
        check(
          because: 'erf(${tuple.$1})',
          erf(tuple.$1),
        ).isCloseTo(tuple.$2, 1e-6);
      }
    });

    test('erfc', () {
      for (final tuple in errorFunctionTuples) {
        check(
          because: 'erfc(${tuple.$1})',
          erfc(tuple.$1),
        ).isCloseTo(1.0 - tuple.$2, 1e-6);
      }
    });

    test('erfInv and erfcInv', () {
      check(erfInv(0.0)).equals(0.0);
      check(erfInv(-1.0)).equals(double.negativeInfinity);
      check(erfInv(1.0)).equals(double.infinity);
      check(erfInv(2.0)).isNaN();
      check(erfInv(-2.0)).isNaN();

      check(erfInv(erf(0.5))).isCloseTo(0.5, 1e-6);
      check(erfInv(erf(-0.75))).isCloseTo(-0.75, 1e-6);
      check(erfcInv(erfc(0.5))).isCloseTo(0.5, 1e-6);
    });
  });
}
