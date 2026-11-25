import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

double _complexNorm(Complex c) {
  final ra = c.a.toDouble().abs();
  final ib = c.b.toDouble().abs();
  final m = ra > ib ? ra : ib;
  if (m == 0.0 || !m.isFinite) return m;
  final sr = ra / m;
  final si = ib / m;
  return m * math.sqrt(sr * sr + si * si);
}

void main() {
  const errorFunctionTuples = <(double, double)>[
    (double.negativeInfinity, -1.0),
    (-10.0, -1.0),
    (-3.0, -0.9999779095030014),
    (-2.0, -0.9953222650189527),
    (-1.0, -0.8427007929497149),
    (-0.5, -0.5204998778130465),
    (-0.1, -0.1124629160182849),
    (0.0, 0.0),
    (0.1, 0.1124629160182849),
    (0.5, 0.5204998778130465),
    (1.0, 0.8427007929497149),
    (2.0, 0.9953222650189527),
    (3.0, 0.9999779095030014),
    (10.0, 1.0),
    (double.infinity, 1.0),
  ];

  group('erf', () {
    test('matches reference values and boundaries', () {
      for (final (x, expected) in errorFunctionTuples) {
        check(because: 'erf($x)', erf(x)).isCloseTo(expected, 1e-14);
      }
      check(erf(double.nan)).isNaN;
    });
  });

  group('erfc', () {
    test('matches reference values and deep asymptotic tails', () {
      for (final (x, expected) in errorFunctionTuples) {
        check(because: 'erfc($x)', erfc(x)).isCloseTo(1.0 - expected, 1e-14);
      }
      check(erfc(10.0)).isCloseTo(2.0884875837625446e-45, 1e-55);
      check(erfc(-10.0)).equals(2.0);
      final logErfc27 = math.log(erfc(27.0));
      final logExpected = -729.0 - math.log(27.0 * math.sqrt(math.pi));
      check(logErfc27).isCloseTo(logExpected, 2e-3);
      check(erfc(double.nan)).isNaN;
    });
  });

  group('erfInv', () {
    test('inverts erf and handles boundaries', () {
      check(erfInv(0.0)).equals(0.0);
      check(erfInv(-1.0)).equals(double.negativeInfinity);
      check(erfInv(1.0)).equals(double.infinity);
      check(erfInv(2.0)).isNaN;
      check(erfInv(-2.0)).isNaN;
      check(erfInv(double.nan)).isNaN;
      for (final x in [-0.95, -0.75, 0.25, 0.5, 0.95]) {
        check(erfInv(erf(x))).isCloseTo(x, 1e-14);
      }
    });
  });

  group('erfcInv', () {
    test('inverts erfc across standard and deep tails', () {
      check(erfcInv(0.0)).equals(double.infinity);
      check(erfcInv(2.0)).equals(double.negativeInfinity);
      check(erfcInv(1.0)).equals(0.0);
      check(erfcInv(-0.1)).isNaN;
      check(erfcInv(2.1)).isNaN;
      check(erfcInv(double.nan)).isNaN;
      check(erfcInv(erfc(0.5))).isCloseTo(0.5, 1e-14);
      check(erfcInv(erfc(5.0))).isCloseTo(5.0, 1e-12);
      check(erfcInv(erfc(8.0))).isCloseTo(8.0, 1e-10);
      check(erfc(erfcInv(1e-50))).isCloseTo(1e-50, 1e-62);
    });
  });

  group('erfi', () {
    test('matches series and large-x asymptotics', () {
      check(erfi(0.0)).equals(0.0);
      check(erfi(1.0)).isCloseTo(1.6504257587975428, 1e-14);
      check(erfi(-1.0)).isCloseTo(-1.6504257587975428, 1e-14);
      check(erfi(2.0)).isCloseTo(18.564802414575553, 1e-13);
      check(erfi(10.0))
          .isCloseTo(1.5243074227086693e42, 1e-13 * 1.5243074227086693e42);
      check(
        math.log(erfi(26.69)),
      ).isCloseTo(26.69 * 26.69 - math.log(math.sqrt(math.pi) * 26.69), 2e-3);
      check(erfi(double.nan)).isNaN;
      check(erfi(double.infinity)).equals(double.infinity);
    });
  });

  group('erfComplex', () {
    test('matches real, imaginary, and small-Re Salzer regimes', () {
      check(erfComplex(const Complex(1.0)).a.toDouble())
          .isCloseTo(erf(1.0), 1e-14);
      check(erfComplex(const Complex(double.infinity))).equals(Complex.one);
      check(erfComplex(const Complex(double.negativeInfinity)))
          .equals(const Complex(-1.0));

      final erfImag = erfComplex(const Complex(0.0, 5.0));
      check(erfImag.a.toDouble()).equals(0.0);
      check(erfImag.b.toDouble()).isCloseTo(erfi(5.0), 1e-13 * erfi(5.0));

      // Small positive Re(z) < 1e-4 exercises small-x Salzer cancellation guard
      const zTinyRe = Complex(1e-6, 2.0);
      check((erfComplex(-zTinyRe) + erfComplex(zTinyRe)).abs())
          .isLessThan(1e-14);
      const h = 1e-6;
      final dfTiny =
          (erfComplex(zTinyRe + h) - erfComplex(zTinyRe - h)) / (2.0 * h);
      final expectedTiny =
          (-zTinyRe * zTinyRe).exp() * (2.0 / math.sqrt(math.pi));
      check(_complexNorm(dfTiny - expectedTiny) / _complexNorm(expectedTiny))
          .isLessThan(1e-9);
    });

    test('agrees with complex derivatives at large Im(z) and handles NaN', () {
      const h = 1e-6;
      for (final z in const [Complex(5.0, 11.0), Complex(0.5, 20.0)]) {
        final df = (erfComplex(z + h) - erfComplex(z - h)) / (2.0 * h);
        final expected = (-z * z).exp() * (2.0 / math.sqrt(math.pi));
        check(_complexNorm(df - expected) / _complexNorm(expected))
            .isLessThan(1e-9);
      }
      check(erfComplex(Complex.nan).isNaN).isTrue;
      check(erfComplex(const Complex(double.infinity, 1.0)).isNaN).isTrue;
    });
  });

  group('erfcComplex', () {
    test('satisfies erf + erfc == 1 and handles real/negative-Re branches', () {
      check(erfcComplex(const Complex(1.0)).a.toDouble())
          .isCloseTo(erfc(1.0), 1e-14);
      check(erfcComplex(const Complex(double.infinity))).equals(Complex.zero);
      check(erfcComplex(const Complex(double.negativeInfinity)))
          .equals(const Complex(2.0));

      for (final z in const [
        Complex(0.2, 5.0),
        Complex(5.0, 1.0),
        Complex(2.0, 3.0),
        Complex(-2.0, 1.0),
      ]) {
        final sum = erfComplex(z) + erfcComplex(z);
        check((sum - Complex.one).abs()).isLessThan(1e-12);
      }
      check(erfcComplex(Complex.nan).isNaN).isTrue;
      check(erfcComplex(const Complex(double.infinity, 1.0)).isNaN).isTrue;
    });
  });

  group('erfiComplex', () {
    test('matches real axis and complex derivative', () {
      final erfiReal = erfiComplex(const Complex(5.0, 0.0));
      check(erfiReal.a.toDouble()).isCloseTo(erfi(5.0), 1e-13 * erfi(5.0));
      check(erfiReal.b.toDouble()).equals(0.0);

      const z = Complex(1.2, 0.7);
      const h = 1e-6;
      final df = (erfiComplex(z + h) - erfiComplex(z - h)) / (2.0 * h);
      final expected = (z * z).exp() * (2.0 / math.sqrt(math.pi));
      check((df - expected).abs() / expected.abs()).isLessThan(1e-9);
    });
  });
}
