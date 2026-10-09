import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Bessel functions', () {
    test('Bessel J0 and J1 exact and reference values', () {
      check(besselJ0(0)).equals(1.0);
      check(besselJ1(0)).equals(0.0);
      check(besselJ0(1.0)).isCloseTo(0.7651976865579666, 1e-6);
      check(besselJ0(5.0)).isCloseTo(-0.1775967713143383, 1e-6);
      check(besselJ0(10.0)).isCloseTo(-0.2459357644513483, 1e-6);
      check(besselJ1(1.0)).isCloseTo(0.4400505857449335, 1e-6);
      check(besselJ1(5.0)).isCloseTo(-0.327579137591465, 1e-6);
      check(besselJ1(10.0)).isCloseTo(0.0434727461688614, 1e-6);
      check(besselJ0(-1.0)).isCloseTo(besselJ0(1.0), 1e-9);
      check(besselJ1(-1.0)).isCloseTo(-besselJ1(1.0), 1e-9);
    });

    test('Bessel Y0 and Y1 boundary and reference values', () {
      check(besselY0(0)).isNaN();
      check(besselY0(-1)).isNaN();
      check(besselY1(0)).isNaN();
      check(besselY1(-1)).isNaN();
      check(besselY0(1.0)).isCloseTo(0.0882569642156765, 1e-6);
      check(besselY0(5.0)).isCloseTo(-0.308517623137123, 1e-6);
      check(besselY0(10.0)).isCloseTo(0.0556711672835994, 1e-6);
      check(besselY1(1.0)).isCloseTo(-0.7812128213002889, 1e-6);
      check(besselY1(5.0)).isCloseTo(0.147863143391227, 1e-6);
      check(besselY1(10.0)).isCloseTo(0.2490154242069538, 1e-6);
    });

    test('Modified Bessel I0 and I1 reference values', () {
      check(besselI0(0)).equals(1.0);
      check(besselI1(0)).equals(0.0);
      check(besselI0(1.0)).isCloseTo(1.2660658777520083, 1e-6);
      check(besselI0(5.0)).isCloseTo(27.23987182441066, 1e-4);
      check(besselI1(1.0)).isCloseTo(0.5651591039924850, 1e-6);
      check(besselI1(5.0)).isCloseTo(24.33564214245648, 1e-4);
      // Symmetry
      check(besselI0(-2.0)).isCloseTo(besselI0(2.0), 1e-9);
      check(besselI1(-2.0)).isCloseTo(-besselI1(2.0), 1e-9);
    });

    test('Modified Bessel K0 and K1 reference values', () {
      check(besselK0(0)).isNaN();
      check(besselK0(-1)).isNaN();
      check(besselK1(0)).isNaN();
      check(besselK1(-1)).isNaN();
      check(besselK0(1.0)).isCloseTo(0.4210244382407083, 1e-6);
      check(besselK0(5.0)).isCloseTo(0.00369110762356937, 1e-6);
      check(besselK1(1.0)).isCloseTo(0.6019072301972346, 1e-6);
      check(besselK1(5.0)).isCloseTo(0.00404457497148563, 1e-6);
    });
  });
}
