import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('Bessel functions', () {
    test('Bessel J0 and J1 exact and reference values', () {
      expect(besselJ0(0), 1.0);
      expect(besselJ1(0), 0.0);
      expect(besselJ0(1.0), closeTo(0.7651976865579666, 1e-6));
      expect(besselJ0(5.0), closeTo(-0.1775967713143383, 1e-6));
      expect(besselJ0(10.0), closeTo(-0.2459357644513483, 1e-6));
      expect(besselJ1(1.0), closeTo(0.4400505857449335, 1e-6));
      expect(besselJ1(5.0), closeTo(-0.327579137591465, 1e-6));
      expect(besselJ1(10.0), closeTo(0.0434727461688614, 1e-6));
      expect(besselJ0(-1.0), closeTo(besselJ0(1.0), 1e-9));
      expect(besselJ1(-1.0), closeTo(-besselJ1(1.0), 1e-9));
    });

    test('Bessel Y0 and Y1 boundary and reference values', () {
      expect(besselY0(0).isNaN, isTrue);
      expect(besselY0(-1).isNaN, isTrue);
      expect(besselY1(0).isNaN, isTrue);
      expect(besselY1(-1).isNaN, isTrue);
      expect(besselY0(1.0), closeTo(0.0882569642156765, 1e-6));
      expect(besselY0(5.0), closeTo(-0.308517623137123, 1e-6));
      expect(besselY1(1.0), closeTo(-0.7812128213002889, 1e-6));
      expect(besselY1(5.0), closeTo(0.147863143391227, 1e-6));
    });

    test('Modified Bessel I0 and I1 reference values', () {
      expect(besselI0(0), 1.0);
      expect(besselI1(0), 0.0);
      expect(besselI0(1.0), closeTo(1.2660658777520083, 1e-6));
      expect(besselI0(5.0), closeTo(27.23987182441066, 1e-4));
      expect(besselI1(1.0), closeTo(0.5651591039924850, 1e-6));
      expect(besselI1(5.0), closeTo(24.33564214245648, 1e-4));
      // Symmetry
      expect(besselI0(-2.0), closeTo(besselI0(2.0), 1e-9));
      expect(besselI1(-2.0), closeTo(-besselI1(2.0), 1e-9));
    });

    test('Modified Bessel K0 and K1 reference values', () {
      expect(besselK0(0).isNaN, isTrue);
      expect(besselK0(-1).isNaN, isTrue);
      expect(besselK1(0).isNaN, isTrue);
      expect(besselK1(-1).isNaN, isTrue);
      expect(besselK0(1.0), closeTo(0.4210244382407083, 1e-6));
      expect(besselK0(5.0), closeTo(0.00369110762356937, 1e-6));
      expect(besselK1(1.0), closeTo(0.6019072301972346, 1e-6));
      expect(besselK1(5.0), closeTo(0.00404457497148563, 1e-6));
    });
  });
}
