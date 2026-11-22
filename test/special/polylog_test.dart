import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('polylogarithm', () {
    test('polylog at special and general points', () {
      check(polylog(2, 0.0)).equals(0.0);
      check(polylog(2, 1.0)).isCloseTo(math.pi * math.pi / 6.0, 1e-12);
      check(polylog(2, -1.0)).isCloseTo(-math.pi * math.pi / 12.0, 1e-12);
      check(polylog(2, 0.5)).isCloseTo(
        math.pi * math.pi / 12.0 - 0.5 * math.pow(math.ln2, 2),
        1e-12,
      );
      check(polylog(2, -2.0)).isCloseTo(-1.436746366883681, 1e-12);
      check(polylog(2, -0.9)).isCloseTo(-0.7521631792172616, 1e-12);
      check(polylog(3, 1.0)).isCloseTo(zeta(3.0), 1e-12);
      check(polylog(1, 0.5)).isCloseTo(math.ln2, 1e-12);
      check(polylog(0, 0.5)).isCloseTo(1.0, 1e-12);
      check(polylog(-1, 0.5)).isCloseTo(2.0, 1e-12);
      check(polylog(2, 1.5)).isNaN;
      check(polylog(2, 0.8)).isCloseTo(1.0747946000082484, 1e-7);
    });

    test('polylogComplex special orders, log expansion, and fallbacks', () {
      const z = Complex(0.3, 0.4);
      final liNeg1 = polylogComplex(const Complex(-1), z);
      final expectedNeg1 = z / ((Complex.one - z) * (Complex.one - z));
      check(liNeg1.a.toDouble()).isCloseTo(expectedNeg1.a.toDouble(), 1e-12);
      check(liNeg1.b.toDouble()).isCloseTo(expectedNeg1.b.toDouble(), 1e-12);

      check(polylogComplex(const Complex(2), Complex.one).a.toDouble())
          .isCloseTo(math.pi * math.pi / 6.0, 1e-12);
      check(polylogComplex(const Complex(0.5), Complex.one).a.toDouble())
          .equals(double.infinity);

      // Near z = 1 (log expansion)
      final nearOne = polylogComplex(
        const Complex(3),
        const Complex(0.85, 0.1),
      );
      check(nearOne.a.toDouble()).isCloseTo(0.9740526927552886, 1e-8);
      check(nearOne.b.toDouble()).isCloseTo(0.13829433431735538, 1e-8);

      // 0.95 < |z| <= 1.05 away from 1
      final nearUnitCircle = polylogComplex(
        const Complex(2),
        const Complex(-0.98),
      );
      check(nearUnitCircle.a.toDouble()).isCloseTo(-0.8085652775847695, 1e-9);

      // General complex order fallback with |z| < 1
      final complexOrder = polylogComplex(
        const Complex(2, 1),
        const Complex(0.96),
      );
      check(complexOrder.a.isFinite).isTrue;
      check(complexOrder.b.isFinite).isTrue;

      // NaN propagation even when z == 0
      check(polylogComplex(Complex.nan, Complex.zero).isNaN).isTrue;
      check(polylogComplex(const Complex(2), Complex.nan).isNaN).isTrue;
    });
  });
}
