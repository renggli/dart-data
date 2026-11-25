import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('fresnelS', () {
    test('evaluates small, asymptotic, and large arguments', () {
      check(fresnelS(0.0)).equals(0.0);
      check(fresnelS(0.5)).isCloseTo(0.0647324328599993, 1e-14);
      check(fresnelS(1.0)).isCloseTo(0.43825914739035476, 1e-14);
      check(fresnelS(2.0)).isCloseTo(0.34341567836369824, 1e-14);
      check(fresnelS(-1.0)).isCloseTo(-0.43825914739035476, 1e-14);

      const xLarge = 100000.0;
      check(fresnelS(xLarge)).isCloseTo(0.5 - 1.0 / (math.pi * xLarge), 1e-10);
    });

    test('handles infinities and NaN', () {
      check(fresnelS(double.infinity)).equals(0.5);
      check(fresnelS(double.negativeInfinity)).equals(-0.5);
      check(fresnelS(double.nan)).isNaN;
    });
  });

  group('fresnelC', () {
    test('evaluates small, asymptotic, and large arguments', () {
      check(fresnelC(0.0)).equals(0.0);
      check(fresnelC(0.5)).isCloseTo(0.4923442258714464, 1e-14);
      check(fresnelC(1.0)).isCloseTo(0.7798934003768228, 1e-14);
      check(fresnelC(2.0)).isCloseTo(0.48825340607534073, 1e-14);
      check(fresnelC(-1.0)).isCloseTo(-0.7798934003768228, 1e-14);

      const xLarge = 100000.0;
      check(fresnelC(xLarge)).isCloseTo(0.5, 1e-10);
    });

    test('handles infinities and NaN', () {
      check(fresnelC(double.infinity)).equals(0.5);
      check(fresnelC(double.negativeInfinity)).equals(-0.5);
      check(fresnelC(double.nan)).isNaN;
    });
  });

  group('fresnelSComplex', () {
    test('matches real values, odd symmetry, and complex derivatives', () {
      check(fresnelSComplex(Complex.zero)).equals(Complex.zero);
      check(fresnelSComplex(Complex.nan).isNaN).isTrue;
      check(fresnelSComplex(const Complex(1.0)).a.toDouble())
          .isCloseTo(fresnelS(1.0), 1e-14);
      check(fresnelSComplex(const Complex(3.0)).a.toDouble())
          .isCloseTo(fresnelS(3.0), 1e-14);

      const h = 1e-6;
      for (final z in const [Complex(0.8, 0.5), Complex(3.0, 0.4)]) {
        check((fresnelSComplex(-z) + fresnelSComplex(z)).abs())
            .isLessThan(1e-13);
        final df =
            (fresnelSComplex(z + h) - fresnelSComplex(z - h)) / (2.0 * h);
        final expected = (const Complex(0.5 * math.pi) * z * z).sin();
        check((df - expected).abs() / expected.abs()).isLessThan(1e-8);
      }
    });
  });

  group('fresnelCComplex', () {
    test('matches real values, odd symmetry, and complex derivatives', () {
      check(fresnelCComplex(Complex.zero)).equals(Complex.zero);
      check(fresnelCComplex(Complex.nan).isNaN).isTrue;
      check(fresnelCComplex(const Complex(1.0)).a.toDouble())
          .isCloseTo(fresnelC(1.0), 1e-14);
      check(fresnelCComplex(const Complex(3.0)).a.toDouble())
          .isCloseTo(fresnelC(3.0), 1e-14);

      const h = 1e-6;
      for (final z in const [Complex(0.8, 0.5), Complex(3.0, 0.4)]) {
        check((fresnelCComplex(-z) + fresnelCComplex(z)).abs())
            .isLessThan(1e-13);
        final df =
            (fresnelCComplex(z + h) - fresnelCComplex(z - h)) / (2.0 * h);
        final expected = (const Complex(0.5 * math.pi) * z * z).cos();
        check((df - expected).abs() / expected.abs()).isLessThan(1e-8);
      }
    });
  });
}
