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
      for (final tuple in errorFunctionTuples) {
        expect(
          erf(tuple.$1),
          closeTo(tuple.$2, 1e-6),
          reason: 'erf(${tuple.$1})',
        );
      }
    });

    test('erfc', () {
      for (final tuple in errorFunctionTuples) {
        expect(
          erfc(tuple.$1),
          closeTo(1.0 - tuple.$2, 1e-6),
          reason: 'erfc(${tuple.$1})',
        );
      }
    });

    test('erfInv and erfcInv', () {
      expect(erfInv(0.0), 0.0);
      expect(erfInv(-1.0), double.negativeInfinity);
      expect(erfInv(1.0), double.infinity);
      expect(erfInv(2.0).isNaN, isTrue);
      expect(erfInv(-2.0).isNaN, isTrue);

      expect(erfInv(erf(0.5)), closeTo(0.5, 1e-6));
      expect(erfInv(erf(-0.75)), closeTo(-0.75, 1e-6));
      expect(erfcInv(erfc(0.5)), closeTo(0.5, 1e-6));
    });
  });
}
