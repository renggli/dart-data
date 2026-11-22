import 'package:checks/checks.dart';
import 'package:data/src/special/utils.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('utils', () {
    test('horner and hornerRatio evaluate polynomials and rational ratios', () {
      // 2 + 3*x + 4*x^2 at x = 5 => 2 + 15 + 100 = 117
      check(horner(5.0, const [2.0, 3.0, 4.0])).equals(117.0);
      check(horner(0.0, const [7.5, 2.0])).equals(7.5);
      check(hornerRatio(2.0, const [1.0, 2.0, 1.0], const [1.0, 1.0]))
          .isCloseTo(3.0, 1e-12);
    });

    test('lentzCFComplex evaluates golden ratio continued fraction', () {
      // 1 / (1 + 1 / (1 + 1 / ...)) = (sqrt(5) - 1) / 2
      final phiInv = lentzCFComplex(
        Complex.one,
        (_) => Complex.one,
        (_) => Complex.one,
      );
      check(phiInv.a).isCloseTo(0.6180339887498949, 1e-12);
      check(phiInv.b).isCloseTo(0.0, 1e-12);
    });
  });
}
