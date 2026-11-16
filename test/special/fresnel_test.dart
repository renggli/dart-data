import 'package:checks/checks.dart';
import 'package:data/special.dart';
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
      check(fresnelS(double.nan)).isNaN();
      check(fresnelC(double.nan)).isNaN();
    });
  });
}
