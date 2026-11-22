import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Fresnel integrals', () {
    test('fresnelS and fresnelC', () {
      check(fresnelS(0.0)).equals(0.0);
      check(fresnelC(0.0)).equals(0.0);

      check(fresnelS(0.5)).isCloseTo(0.0647324328599993, 1e-12);
      check(fresnelC(0.5)).isCloseTo(0.4923442258714464, 1e-12);

      check(fresnelS(1.0)).isCloseTo(0.43825914739035476, 1e-12);
      check(fresnelC(1.0)).isCloseTo(0.7798934003768228, 1e-12);

      check(fresnelS(2.0)).isCloseTo(0.34341567836369824, 1e-12);
      check(fresnelC(2.0)).isCloseTo(0.48825340607534073, 1e-12);

      check(fresnelS(-1.0)).isCloseTo(-0.43825914739035476, 1e-12);
      check(fresnelC(-1.0)).isCloseTo(-0.7798934003768228, 1e-12);

      check(fresnelS(double.infinity)).equals(0.5);
      check(fresnelC(double.infinity)).equals(0.5);
      check(fresnelS(double.nan)).isNaN;
      check(fresnelC(double.nan)).isNaN;
    });

    test('fresnelSComplex and fresnelCComplex', () {
      check(fresnelSComplex(Complex.nan).isNaN).isTrue;
      check(fresnelCComplex(Complex.nan).isNaN).isTrue;
      check(fresnelSComplex(Complex.zero)).equals(Complex.zero);
      check(fresnelCComplex(Complex.zero)).equals(Complex.zero);

      // Small |z| < 2.5 series branch
      check(fresnelSComplex(const Complex(1.0)).a.toDouble())
          .isCloseTo(fresnelS(1.0), 1e-12);
      check(fresnelCComplex(const Complex(1.0)).a.toDouble())
          .isCloseTo(fresnelC(1.0), 1e-12);

      // Large |z| >= 2.5 erfComplex branch
      check(fresnelSComplex(const Complex(3.0)).a.toDouble())
          .isCloseTo(fresnelS(3.0), 1e-10);
      check(fresnelCComplex(const Complex(3.0)).a.toDouble())
          .isCloseTo(fresnelC(3.0), 1e-10);
      const zLarge = Complex(3.0, 0.4);
      check(fresnelSComplex(zLarge).a.isFinite).isTrue;
      check(fresnelCComplex(zLarge).a.isFinite).isTrue;
    });
  });
}
