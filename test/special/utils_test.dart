import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/special/utils.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('horner', () {
    test('evaluates polynomials and constant terms', () {
      check(horner(5.0, const [2.0, 3.0, 4.0])).equals(117.0);
      check(horner(-2.0, const [1.0, -3.0, 2.0])).equals(15.0);
      check(horner(0.0, const [7.5, 2.0])).equals(7.5);
      check(horner(3.0, const [4.25])).equals(4.25);
    });
  });

  group('hornerRatio', () {
    test('evaluates rational polynomials', () {
      check(hornerRatio(2.0, const [1.0, 2.0, 1.0], const [1.0, 1.0]))
          .isCloseTo(3.0, 1e-14);
      check(hornerRatio(-1.5, const [2.0, -1.0, 4.0], const [3.0, 2.0, 1.0]))
          .isCloseTo(12.5 / 2.25, 1e-14);
    });
  });

  group('log1p', () {
    test('preserves precision near zero', () {
      check(log1p(0.0)).equals(0.0);
      check(log1p(1e-15)).isCloseTo(1e-15 - 0.5e-30, 1e-29);
      check(log1p(-1e-15)).isCloseTo(-1e-15 - 0.5e-30, 1e-29);
      check(log1p(1.0)).isCloseTo(math.ln2, 1e-15);
    });

    test('handles boundaries and infinities', () {
      check(log1p(-1.0)).equals(double.negativeInfinity);
      check(log1p(-1.5)).isNaN;
      check(log1p(double.infinity)).equals(double.infinity);
      check(log1p(double.nan)).isNaN;
    });
  });

  group('lentzCF', () {
    test('evaluates real continued fractions', () {
      final phiInv = lentzCF(1.0, (_) => 1.0, (_) => 1.0);
      check(phiInv).isCloseTo(0.6180339887498949, 1e-14);

      // 1 / (1 + 1/(2 + 1/(2 + ...))) = 1 / sqrt(2)
      final invSqrt2 = lentzCF(1.0, (_) => 1.0, (_) => 2.0);
      check(invSqrt2).isCloseTo(1.0 / math.sqrt2, 1e-14);
    });
  });

  group('lentzCFComplex', () {
    test('evaluates complex continued fractions', () {
      final phiInv = lentzCFComplex(
        Complex.one,
        (_) => Complex.one,
        (_) => Complex.one,
      );
      check(phiInv.a).isCloseTo(0.6180339887498949, 1e-14);
      check(phiInv.b).isCloseTo(0.0, 1e-14);

      const c = Complex(2.0, 1.0);
      final cf = lentzCFComplex(c, (_) => Complex.one, (_) => c);
      check((cf * cf + cf * c - Complex.one).abs()).isLessThan(1e-13);
    });
  });

  group('logSinPiComplex', () {
    test('matches direct computation for moderate imaginary parts', () {
      for (final z in const [Complex(0.3, 2.0), Complex(-0.7, -1.5)]) {
        final actual = logSinPiComplex(z);
        final direct = (const Complex(math.pi) * z).sin().log();
        check((actual - direct).abs()).isLessThan(1e-13);
      }
    });

    test('avoids overflow for large imaginary parts', () {
      final largePos = logSinPiComplex(const Complex(0.3, 300.0));
      check(largePos.a).isCloseTo(300.0 * math.pi - math.ln2, 1e-11);
      check(largePos.b).isCloseTo(0.2 * math.pi, 1e-12);

      final largeNeg = logSinPiComplex(const Complex(0.3, -300.0));
      check(largeNeg.a).isCloseTo(300.0 * math.pi - math.ln2, 1e-11);
      check(largeNeg.b).isCloseTo(-0.2 * math.pi, 1e-12);
    });
  });

  group('cotPiComplex', () {
    test('matches cos/sin for moderate imaginary parts', () {
      const z = Complex(0.3, 1.5);
      final px = const Complex(math.pi) * z;
      check((cotPiComplex(z) - px.cos() / px.sin()).abs()).isLessThan(1e-13);
    });

    test('avoids overflow for large imaginary parts', () {
      check(cotPiComplex(const Complex(0.3, 300.0)))
          .equals(const Complex(0.0, -1.0));
      check(cotPiComplex(const Complex(0.3, -300.0)))
          .equals(const Complex(0.0, 1.0));
    });
  });
}
