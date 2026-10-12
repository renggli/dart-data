import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('Empirical Challenge 1: Degree 2 Polynomials', () {
    test('monic quadratics with distinct integer roots', () {
      // (x - 1)(x - 2)
      final p1 = x * x - const RationalNumber(3) * x + 2;
      check(p1.factor()).equals((x - 1) * (x - 2));
      check(p1.factor().expand()).equals(p1.expand());

      // (x + 3)(x - 5) = x^2 - 2x - 15
      final p2 = x * x - const RationalNumber(2) * x - 15;
      check(p2.factor()).equals((x + 3) * (x - 5));
      check(p2.factor().expand()).equals(p2.expand());

      // (x + 7)(x + 4) = x^2 + 11x + 28
      final p3 = x * x + const RationalNumber(11) * x + 28;
      check(p3.factor()).equals((x + 4) * (x + 7));
      check(p3.factor().expand()).equals(p3.expand());

      // x(x - 6) = x^2 - 6x
      final p4 = x * x - const RationalNumber(6) * x;
      check(p4.factor()).equals(x * (x - 6));
      check(p4.factor().expand()).equals(p4.expand());

      // x(x + 9) = x^2 + 9x
      final p5 = x * x + const RationalNumber(9) * x;
      check(p5.factor()).equals(x * (x + 9));
      check(p5.factor().expand()).equals(p5.expand());
    });

    test('monic quadratics with double roots (perfect squares)', () {
      // (x - 3)^2 = x^2 - 6x + 9
      final p1 = x * x - const RationalNumber(6) * x + 9;
      check(p1.factor()).equals(Pow(x - 3, const RationalNumber(2)));
      check(p1.factor().expand()).equals(p1.expand());

      // (x + 5)^2 = x^2 + 10x + 25
      final p2 = x * x + const RationalNumber(10) * x + 25;
      check(p2.factor()).equals(Pow(x + 5, const RationalNumber(2)));
      check(p2.factor().expand()).equals(p2.expand());

      // x^2
      final p3 = x * x;
      check(p3.factor()).equals(const Pow(x, RationalNumber(2)));
      check(p3.factor().expand()).equals(p3.expand());
    });

    test('monic difference of squares', () {
      // x^2 - 1 = (x - 1)(x + 1)
      final p1 = x * x - 1;
      check(p1.factor()).equals((x - 1) * (x + 1));
      check(p1.factor().expand()).equals(p1.expand());

      // x^2 - 64 = (x - 8)(x + 8)
      final p2 = x * x - 64;
      check(p2.factor()).equals((x - 8) * (x + 8));
      check(p2.factor().expand()).equals(p2.expand());

      // x^2 - 144 = (x - 12)(x + 12)
      final p3 = x * x - 144;
      check(p3.factor()).equals((x - 12) * (x + 12));
      check(p3.factor().expand()).equals(p3.expand());
    });

    test('non-monic quadratics with rational roots', () {
      // (2x - 1)(x - 3) = 2x^2 - 7x + 3
      final p1 =
          const RationalNumber(2) * x * x - const RationalNumber(7) * x + 3;
      check(p1.factor()).equals((const RationalNumber(2) * x - 1) * (x - 3));
      check(p1.factor().expand()).equals(p1.expand());

      // (3x + 2)(2x - 5) = 6x^2 - 11x - 10
      final p2 =
          const RationalNumber(6) * x * x - const RationalNumber(11) * x - 10;
      check(p2.factor()).equals(
        (const RationalNumber(3) * x + 2) * (const RationalNumber(2) * x - 5),
      );
      check(p2.factor().expand()).equals(p2.expand());

      // (5x - 4)(4x + 3) = 20x^2 - x - 12
      final p3 = const RationalNumber(20) * x * x - x - 12;
      check(p3.factor()).equals(
        (const RationalNumber(4) * x + 3) * (const RationalNumber(5) * x - 4),
      );
      check(p3.factor().expand()).equals(p3.expand());

      // (2x - 3)^2 = 4x^2 - 12x + 9
      final p4 =
          const RationalNumber(4) * x * x - const RationalNumber(12) * x + 9;
      check(
        p4.factor(),
      ).equals(Pow(const RationalNumber(2) * x - 3, const RationalNumber(2)));
      check(p4.factor().expand()).equals(p4.expand());

      // (3x + 1)^2 = 9x^2 + 6x + 1
      final p5 =
          const RationalNumber(9) * x * x + const RationalNumber(6) * x + 1;
      check(
        p5.factor(),
      ).equals(Pow(const RationalNumber(3) * x + 1, const RationalNumber(2)));
      check(p5.factor().expand()).equals(p5.expand());
    });

    test('non-monic difference of squares', () {
      // 4x^2 - 9 = (2x - 3)(2x + 3)
      final p1 = const RationalNumber(4) * x * x - 9;
      check(p1.factor()).equals(
        (const RationalNumber(2) * x - 3) * (const RationalNumber(2) * x + 3),
      );
      check(p1.factor().expand()).equals(p1.expand());

      // 25x^2 - 16 = (5x - 4)(5x + 4)
      final p2 = const RationalNumber(25) * x * x - 16;
      check(p2.factor()).equals(
        (const RationalNumber(5) * x - 4) * (const RationalNumber(5) * x + 4),
      );
      check(p2.factor().expand()).equals(p2.expand());

      // 49x^2 - 81 = (7x - 9)(7x + 9)
      final p3 = const RationalNumber(49) * x * x - 81;
      check(p3.factor()).equals(
        (const RationalNumber(7) * x - 9) * (const RationalNumber(7) * x + 9),
      );
      check(p3.factor().expand()).equals(p3.expand());
    });

    test('quadratics with common scalar factors and negative signs', () {
      // 6x^2 - 30x + 36 = 6(x - 2)(x - 3)
      final p1 =
          const RationalNumber(6) * x * x - const RationalNumber(30) * x + 36;
      check(p1.factor()).equals(const RationalNumber(6) * (x - 2) * (x - 3));
      check(p1.factor().expand()).equals(p1.expand());

      // -3x^2 + 15x - 18 = -3(x - 2)(x - 3)
      final p2 =
          const RationalNumber(-3) * x * x + const RationalNumber(15) * x - 18;
      check(p2.factor()).equals(const RationalNumber(-3) * (x - 2) * (x - 3));
      check(p2.factor().expand()).equals(p2.expand());

      // 12x^2 - 27 = 3(2x - 3)(2x + 3)
      final p3 = const RationalNumber(12) * x * x - 27;
      check(p3.factor()).equals(
        const RationalNumber(3) *
            (const RationalNumber(2) * x - 3) *
            (const RationalNumber(2) * x + 3),
      );
      check(p3.factor().expand()).equals(p3.expand());

      // -x^2 + 4 = -((x - 2)(x + 2))
      final p4 = -x * x + 4;
      check(p4.factor()).equals(-((x - 2) * (x + 2)));
      check(p4.factor().expand()).equals(p4.expand());

      // -4x^2 + 9 = -((2x - 3)(2x + 3))
      final p5 = const RationalNumber(-4) * x * x + 9;
      check(p5.factor()).equals(
        -((const RationalNumber(2) * x - 3) *
            (const RationalNumber(2) * x + 3)),
      );
      check(p5.factor().expand()).equals(p5.expand());

      // 8x^2 + 24x + 18 = 2(2x + 3)^2
      final p6 =
          const RationalNumber(8) * x * x + const RationalNumber(24) * x + 18;
      check(p6.factor()).equals(
        const RationalNumber(2) *
            Pow(const RationalNumber(2) * x + 3, const RationalNumber(2)),
      );
      check(p6.factor().expand()).equals(p6.expand());
    });

    test('quadratics with fractional coefficients', () {
      // (1/3)x^2 + (7/3)x + 2 = (1/3)(x + 1)(x + 6)? No: (1/3)(2x^2 + 7x + 6) is not that.
      // Let's do (1/3)(x - 1)(x - 4) = (1/3)x^2 - (5/3)x + 4/3
      final p1 =
          const RationalNumber(1, 3) * x * x -
          const RationalNumber(5, 3) * x +
          const RationalNumber(4, 3);
      check(p1.factor()).equals(const RationalNumber(1, 3) * (x - 1) * (x - 4));
      check(p1.factor().expand()).equals(p1.expand());

      // (1/4)x^2 - 9/4 = (1/4)(x - 3)(x + 3)
      final p2 =
          const RationalNumber(1, 4) * x * x - const RationalNumber(9, 4);
      check(p2.factor()).equals(const RationalNumber(1, 4) * (x - 3) * (x + 3));
      check(p2.factor().expand()).equals(p2.expand());
    });

    test('irreducible quadratics over Q[x]', () {
      final p1 = x.pow(2) + 1;
      check(p1.factor()).equals(p1);
      check(p1.factor().expand()).equals(p1.expand());

      final p2 = x.pow(2) + x + 1;
      check(p2.factor()).equals(p2);
      check(p2.factor().expand()).equals(p2.expand());

      final p3 =
          const RationalNumber(2) * x.pow(2) + const RationalNumber(3) * x + 5;
      check(p3.factor()).equals(p3);
      check(p3.factor().expand()).equals(p3.expand());

      final p4 = x.pow(2) - 2; // sqrt(2) is not rational
      check(p4.factor()).equals(p4);
      check(p4.factor().expand()).equals(p4.expand());
    });
  });

  group('Empirical Challenge 2: Degree 3 Polynomials', () {
    test('monic cubics with distinct rational roots', () {
      // (x - 1)(x - 2)(x - 3) = x^3 - 6x^2 + 11x - 6
      final p1 =
          x.pow(3) -
          const RationalNumber(6) * x.pow(2) +
          const RationalNumber(11) * x -
          6;
      check(p1.factor()).equals((x - 1) * (x - 2) * (x - 3));
      check(p1.factor().expand()).equals(p1.expand());

      // (x + 1)(x + 2)(x + 3) = x^3 + 6x^2 + 11x + 6
      final p2 =
          x.pow(3) +
          const RationalNumber(6) * x.pow(2) +
          const RationalNumber(11) * x +
          6;
      check(p2.factor()).equals((x + 1) * (x + 2) * (x + 3));
      check(p2.factor().expand()).equals(p2.expand());

      // (x - 5)(x + 2)(x - 1) = x^3 - 4x^2 - 7x + 10
      final p3 =
          x.pow(3) -
          const RationalNumber(4) * x.pow(2) -
          const RationalNumber(7) * x +
          10;
      check(p3.factor()).equals((x - 1) * (x + 2) * (x - 5));
      check(p3.factor().expand()).equals(p3.expand());

      // x(x - 3)(x + 3) = x^3 - 9x
      final p4 = x.pow(3) - const RationalNumber(9) * x;
      check(p4.factor()).equals(x * (x - 3) * (x + 3));
      check(p4.factor().expand()).equals(p4.expand());

      // x(x - 2)(x - 5) = x^3 - 7x^2 + 10x
      final p5 =
          x.pow(3) -
          const RationalNumber(7) * x.pow(2) +
          const RationalNumber(10) * x;
      check(p5.factor()).equals(x * (x - 2) * (x - 5));
      check(p5.factor().expand()).equals(p5.expand());
    });

    test('monic cubics with multiple roots', () {
      // (x - 2)^3 = x^3 - 6x^2 + 12x - 8
      final p1 =
          x.pow(3) -
          const RationalNumber(6) * x.pow(2) +
          const RationalNumber(12) * x -
          8;
      check(p1.factor()).equals(Pow(x - 2, const RationalNumber(3)));
      check(p1.factor().expand()).equals(p1.expand());

      // (x + 3)^3 = x^3 + 9x^2 + 27x + 27
      final p2 =
          x.pow(3) +
          const RationalNumber(9) * x.pow(2) +
          const RationalNumber(27) * x +
          27;
      check(p2.factor()).equals(Pow(x + 3, const RationalNumber(3)));
      check(p2.factor().expand()).equals(p2.expand());

      // (x - 1)^2(x + 2) = x^3 - 3x + 2
      final p3 = x.pow(3) - const RationalNumber(3) * x + 2;
      check(p3.factor()).equals(Pow(x - 1, const RationalNumber(2)) * (x + 2));
      check(p3.factor().expand()).equals(p3.expand());

      // (x + 3)^2(x - 2) = x^3 + 4x^2 - 3x - 18
      final p4 =
          x.pow(3) +
          const RationalNumber(4) * x.pow(2) -
          const RationalNumber(3) * x -
          18;
      check(p4.factor()).equals((x - 2) * Pow(x + 3, const RationalNumber(2)));
      check(p4.factor().expand()).equals(p4.expand());

      // x^2(x - 4) = x^3 - 4x^2
      final p5 = x.pow(3) - const RationalNumber(4) * x.pow(2);
      check(p5.factor()).equals(const Pow(x, RationalNumber(2)) * (x - 4));
      check(p5.factor().expand()).equals(p5.expand());

      // x^3
      final p6 = x.pow(3);
      check(p6.factor()).equals(const Pow(x, RationalNumber(3)));
      check(p6.factor().expand()).equals(p6.expand());
    });

    test('non-monic cubics with rational roots and multiplicities', () {
      // (2x - 1)(x - 2)(x + 3) = 2x^3 + x^2 - 13x + 6
      final p1 =
          const RationalNumber(2) * x.pow(3) +
          x.pow(2) -
          const RationalNumber(13) * x +
          6;
      check(p1.factor())
          .equals((const RationalNumber(2) * x - 1) * (x - 2) * (x + 3));
      check(p1.factor().expand()).equals(p1.expand());

      // (2x - 1)^2(x + 3) = 4x^3 + 8x^2 - 11x + 3
      final p2 =
          const RationalNumber(4) * x.pow(3) +
          const RationalNumber(8) * x.pow(2) -
          const RationalNumber(11) * x +
          3;
      check(p2.factor()).equals(
        Pow(const RationalNumber(2) * x - 1, const RationalNumber(2)) * (x + 3),
      );
      check(p2.factor().expand()).equals(p2.expand());

      // (2x - 1)^3 = 8x^3 - 12x^2 + 6x - 1
      final p3 =
          const RationalNumber(8) * x.pow(3) -
          const RationalNumber(12) * x.pow(2) +
          const RationalNumber(6) * x -
          1;
      check(
        p3.factor(),
      ).equals(Pow(const RationalNumber(2) * x - 1, const RationalNumber(3)));
      check(p3.factor().expand()).equals(p3.expand());

      // (3x + 2)^3 = 27x^3 + 54x^2 + 36x + 8
      final p4 =
          const RationalNumber(27) * x.pow(3) +
          const RationalNumber(54) * x.pow(2) +
          const RationalNumber(36) * x +
          8;
      check(
        p4.factor(),
      ).equals(Pow(const RationalNumber(3) * x + 2, const RationalNumber(3)));
      check(p4.factor().expand()).equals(p4.expand());

      // 2x(2x - 1)(3x + 1) = 12x^3 - 2x^2 - 2x
      final p5 =
          const RationalNumber(12) * x.pow(3) -
          const RationalNumber(2) * x.pow(2) -
          const RationalNumber(2) * x;
      check(p5.factor()).equals(
        const RationalNumber(2) *
            x *
            (const RationalNumber(3) * x + 1) *
            (const RationalNumber(2) * x - 1),
      );
      check(p5.factor().expand()).equals(p5.expand());
    });

    test('sum and difference of cubes', () {
      // x^3 - 1 = (x - 1)(x^2 + x + 1)
      final p1 = x.pow(3) - 1;
      check(p1.factor()).equals((x - 1) * (x.pow(2) + x + 1));
      check(p1.factor().expand()).equals(p1.expand());

      // x^3 + 1 = (x + 1)(x^2 - x + 1)
      final p2 = x.pow(3) + 1;
      check(p2.factor()).equals((x + 1) * (x.pow(2) - x + 1));
      check(p2.factor().expand()).equals(p2.expand());

      // x^3 - 27 = (x - 3)(x^2 + 3x + 9)
      final p3 = x.pow(3) - 27;
      check(p3.factor())
          .equals((x - 3) * (x.pow(2) + const RationalNumber(3) * x + 9));
      check(p3.factor().expand()).equals(p3.expand());

      // x^3 + 27 = (x + 3)(x^2 - 3x + 9)
      final p4 = x.pow(3) + 27;
      check(p4.factor())
          .equals((x + 3) * (x.pow(2) - const RationalNumber(3) * x + 9));
      check(p4.factor().expand()).equals(p4.expand());

      // 8x^3 - 27 = (2x - 3)(4x^2 + 6x + 9)
      final p5 = const RationalNumber(8) * x.pow(3) - 27;
      check(p5.factor()).equals(
        (const RationalNumber(2) * x - 3) *
            (const RationalNumber(4) * x.pow(2) +
                const RationalNumber(6) * x +
                9),
      );
      check(p5.factor().expand()).equals(p5.expand());

      // 27x^3 + 125 = (3x + 5)(9x^2 - 15x + 25)
      final p6 = const RationalNumber(27) * x.pow(3) + 125;
      check(p6.factor()).equals(
        (const RationalNumber(3) * x + 5) *
            (const RationalNumber(9) * x.pow(2) -
                const RationalNumber(15) * x +
                25),
      );
      check(p6.factor().expand()).equals(p6.expand());
    });

    test('cubics with one rational root and irreducible quadratic', () {
      // (x - 1)(x^2 + 1) = x^3 - x^2 + x - 1
      final p1 = x.pow(3) - x.pow(2) + x - 1;
      check(p1.factor()).equals((x - 1) * (x.pow(2) + 1));
      check(p1.factor().expand()).equals(p1.expand());

      // (x + 2)(x^2 + 3) = x^3 + 2x^2 + 3x + 6
      final p2 =
          x.pow(3) +
          const RationalNumber(2) * x.pow(2) +
          const RationalNumber(3) * x +
          6;
      check(p2.factor()).equals((x + 2) * (x.pow(2) + 3));
      check(p2.factor().expand()).equals(p2.expand());

      // (2x - 3)(x^2 + x + 1) = 2x^3 - x^2 - x - 3
      final p3 = const RationalNumber(2) * x.pow(3) - x.pow(2) - x - 3;
      check(p3.factor())
          .equals((const RationalNumber(2) * x - 3) * (x.pow(2) + x + 1));
      check(p3.factor().expand()).equals(p3.expand());
    });

    test('cubics with negative leading coefficients', () {
      // -(x - 1)(x - 2)(x - 3) = -x^3 + 6x^2 - 11x + 6
      final p1 =
          -x.pow(3) +
          const RationalNumber(6) * x.pow(2) -
          const RationalNumber(11) * x +
          6;
      check(p1.factor()).equals(-((x - 1) * (x - 2) * (x - 3)));
      check(p1.factor().expand()).equals(p1.expand());

      // -(2x - 1)^3 = -8x^3 + 12x^2 - 6x + 1
      final p2 =
          const RationalNumber(-8) * x.pow(3) +
          const RationalNumber(12) * x.pow(2) -
          const RationalNumber(6) * x +
          1;
      check(
        p2.factor(),
      ).equals(-Pow(const RationalNumber(2) * x - 1, const RationalNumber(3)));
      check(p2.factor().expand()).equals(p2.expand());
    });
  });

  group('Empirical Challenge 3: Degree 4 Polynomials', () {
    test('monic quartics with 4 distinct rational roots', () {
      // (x - 1)(x - 2)(x - 3)(x - 4) = x^4 - 10x^3 + 35x^2 - 50x + 24
      final p1 =
          x.pow(4) -
          const RationalNumber(10) * x.pow(3) +
          const RationalNumber(35) * x.pow(2) -
          const RationalNumber(50) * x +
          24;
      check(p1.factor()).equals((x - 1) * (x - 2) * (x - 3) * (x - 4));
      check(p1.factor().expand()).equals(p1.expand());

      // (x + 1)(x + 2)(x + 3)(x + 4) = x^4 + 10x^3 + 35x^2 + 50x + 24
      final p2 =
          x.pow(4) +
          const RationalNumber(10) * x.pow(3) +
          const RationalNumber(35) * x.pow(2) +
          const RationalNumber(50) * x +
          24;
      check(p2.factor()).equals((x + 1) * (x + 2) * (x + 3) * (x + 4));
      check(p2.factor().expand()).equals(p2.expand());

      // (x - 3)(x + 3)(x - 1)(x + 1) = x^4 - 10x^2 + 9
      final p3 = x.pow(4) - const RationalNumber(10) * x.pow(2) + 9;
      check(p3.factor()).equals((x - 1) * (x + 1) * (x - 3) * (x + 3));
      check(p3.factor().expand()).equals(p3.expand());
    });

    test('non-monic quartics with 4 rational roots', () {
      // (2x - 1)(x - 1)(x + 1)(x + 2) = 2x^4 + 3x^3 - 4x^2 - 3x + 2
      final p1 =
          const RationalNumber(2) * x.pow(4) +
          const RationalNumber(3) * x.pow(3) -
          const RationalNumber(4) * x.pow(2) -
          const RationalNumber(3) * x +
          2;
      check(
        p1.factor(),
      ).equals((const RationalNumber(2) * x - 1) * (x - 1) * (x + 1) * (x + 2));
      check(p1.factor().expand()).equals(p1.expand());

      // (2x - 1)(2x + 1)(3x - 1)(3x + 1) = (4x^2 - 1)(9x^2 - 1) = 36x^4 - 13x^2 + 1
      final p2 =
          const RationalNumber(36) * x.pow(4) -
          const RationalNumber(13) * x.pow(2) +
          1;
      check(p2.factor()).equals(
        (const RationalNumber(3) * x - 1) *
            (const RationalNumber(3) * x + 1) *
            (const RationalNumber(2) * x - 1) *
            (const RationalNumber(2) * x + 1),
      );
      check(p2.factor().expand()).equals(p2.expand());
    });

    test('quartics with multiple roots (quadruple, triple, double)', () {
      // (x - 1)^4 = x^4 - 4x^3 + 6x^2 - 4x + 1
      final p1 =
          x.pow(4) -
          const RationalNumber(4) * x.pow(3) +
          const RationalNumber(6) * x.pow(2) -
          const RationalNumber(4) * x +
          1;
      check(p1.factor()).equals(Pow(x - 1, const RationalNumber(4)));
      check(p1.factor().expand()).equals(p1.expand());

      // (2x - 1)^4 = 16x^4 - 32x^3 + 24x^2 - 8x + 1
      final p2 =
          const RationalNumber(16) * x.pow(4) -
          const RationalNumber(32) * x.pow(3) +
          const RationalNumber(24) * x.pow(2) -
          const RationalNumber(8) * x +
          1;
      check(
        p2.factor(),
      ).equals(Pow(const RationalNumber(2) * x - 1, const RationalNumber(4)));
      check(p2.factor().expand()).equals(p2.expand());

      // (x - 1)^3(x + 2) = x^4 - x^3 - 3x^2 + 5x - 2
      final p3 =
          x.pow(4) -
          x.pow(3) -
          const RationalNumber(3) * x.pow(2) +
          const RationalNumber(5) * x -
          2;
      check(p3.factor()).equals(Pow(x - 1, const RationalNumber(3)) * (x + 2));
      check(p3.factor().expand()).equals(p3.expand());

      // (x - 1)^2(x + 1)^2 = x^4 - 2x^2 + 1
      final p4 = x.pow(4) - const RationalNumber(2) * x.pow(2) + 1;
      check(p4.factor()).equals(
        Pow(x - 1, const RationalNumber(2)) *
            Pow(x + 1, const RationalNumber(2)),
      );
      check(p4.factor().expand()).equals(p4.expand());

      // (x - 2)^2(x + 2)^2 = x^4 - 8x^2 + 16
      final p5 = x.pow(4) - const RationalNumber(8) * x.pow(2) + 16;
      check(p5.factor()).equals(
        Pow(x - 2, const RationalNumber(2)) *
            Pow(x + 2, const RationalNumber(2)),
      );
      check(p5.factor().expand()).equals(p5.expand());

      // (x - 2)^2(x - 3)^2 = x^4 - 10x^3 + 37x^2 - 60x + 36
      final p6 =
          x.pow(4) -
          const RationalNumber(10) * x.pow(3) +
          const RationalNumber(37) * x.pow(2) -
          const RationalNumber(60) * x +
          36;
      check(p6.factor()).equals(
        Pow(x - 2, const RationalNumber(2)) *
            Pow(x - 3, const RationalNumber(2)),
      );
      check(p6.factor().expand()).equals(p6.expand());

      // (x - 1)^2(x - 2)(x - 3) = x^4 - 7x^3 + 17x^2 - 17x + 6
      final p7 =
          x.pow(4) -
          const RationalNumber(7) * x.pow(3) +
          const RationalNumber(17) * x.pow(2) -
          const RationalNumber(17) * x +
          6;
      check(p7.factor())
          .equals(Pow(x - 1, const RationalNumber(2)) * (x - 2) * (x - 3));
      check(p7.factor().expand()).equals(p7.expand());
    });

    test('quartics with zero roots (monomial extraction)', () {
      // x(x - 1)(x - 2)(x - 3) = x^4 - 6x^3 + 11x^2 - 6x
      final p1 =
          x.pow(4) -
          const RationalNumber(6) * x.pow(3) +
          const RationalNumber(11) * x.pow(2) -
          const RationalNumber(6) * x;
      check(p1.factor()).equals(x * (x - 1) * (x - 2) * (x - 3));
      check(p1.factor().expand()).equals(p1.expand());

      // x^2(x - 3)^2 = x^4 - 6x^3 + 9x^2
      final p2 =
          x.pow(4) -
          const RationalNumber(6) * x.pow(3) +
          const RationalNumber(9) * x.pow(2);
      check(p2.factor()).equals(
        const Pow(x, RationalNumber(2)) * Pow(x - 3, const RationalNumber(2)),
      );
      check(p2.factor().expand()).equals(p2.expand());

      // x^3(x - 5) = x^4 - 5x^3
      final p3 = x.pow(4) - const RationalNumber(5) * x.pow(3);
      check(p3.factor()).equals(const Pow(x, RationalNumber(3)) * (x - 5));
      check(p3.factor().expand()).equals(p3.expand());

      // x^4
      final p4 = x.pow(4);
      check(p4.factor()).equals(const Pow(x, RationalNumber(4)));
      check(p4.factor().expand()).equals(p4.expand());
    });

    test('biquadratic quartics and differences of squares of squares', () {
      // x^4 - 16 = (x - 2)(x + 2)(x^2 + 4)
      final p1 = x.pow(4) - 16;
      check(p1.factor()).equals((x - 2) * (x + 2) * (x.pow(2) + 4));
      check(p1.factor().expand()).equals(p1.expand());

      // x^4 - 81 = (x - 3)(x + 3)(x^2 + 9)
      final p2 = x.pow(4) - 81;
      check(p2.factor()).equals((x - 3) * (x + 3) * (x.pow(2) + 9));
      check(p2.factor().expand()).equals(p2.expand());

      // 16x^4 - 1 = (2x - 1)(2x + 1)(4x^2 + 1)
      final p3 = const RationalNumber(16) * x.pow(4) - 1;
      check(p3.factor()).equals(
        (const RationalNumber(2) * x - 1) *
            (const RationalNumber(2) * x + 1) *
            (const RationalNumber(4) * x.pow(2) + 1),
      );
      check(p3.factor().expand()).equals(p3.expand());

      // (x^2 + 1)(x^2 + 4) = x^4 + 5x^2 + 4
      final p4 = x.pow(4) + const RationalNumber(5) * x.pow(2) + 4;
      check(p4.factor()).equals((x.pow(2) + 1) * (x.pow(2) + 4));
      check(p4.factor().expand()).equals(p4.expand());

      // (x^2 - 2)(x^2 - 3) = x^4 - 5x^2 + 6
      final p5 = x.pow(4) - const RationalNumber(5) * x.pow(2) + 6;
      check(p5.factor()).equals((x.pow(2) - 2) * (x.pow(2) - 3));
      check(p5.factor().expand()).equals(p5.expand());
    });

    test('quartics with rational roots and irreducible quadratic', () {
      // (x - 1)(x - 2)(x^2 + 1) = x^4 - 3x^3 + 3x^2 - 3x + 2
      final p1 =
          x.pow(4) -
          const RationalNumber(3) * x.pow(3) +
          const RationalNumber(3) * x.pow(2) -
          const RationalNumber(3) * x +
          2;
      check(p1.factor()).equals((x - 1) * (x - 2) * (x.pow(2) + 1));
      check(p1.factor().expand()).equals(p1.expand());

      // (x + 1)^2(x^2 + 1) = x^4 + 2x^3 + 2x^2 + 2x + 1
      final p2 =
          x.pow(4) +
          const RationalNumber(2) * x.pow(3) +
          const RationalNumber(2) * x.pow(2) +
          const RationalNumber(2) * x +
          1;
      check(p2.factor())
          .equals(Pow(x + 1, const RationalNumber(2)) * (x.pow(2) + 1));
      check(p2.factor().expand()).equals(p2.expand());
    });

    test('quartics with negative leading coefficient', () {
      // -(x - 1)(x - 2)(x - 3)(x - 4) = -x^4 + 10x^3 - 35x^2 + 50x - 24
      final p1 =
          -x.pow(4) +
          const RationalNumber(10) * x.pow(3) -
          const RationalNumber(35) * x.pow(2) +
          const RationalNumber(50) * x -
          24;
      check(p1.factor()).equals(-((x - 1) * (x - 2) * (x - 3) * (x - 4)));
      check(p1.factor().expand()).equals(p1.expand());
    });
  });

  group(
    'Empirical Challenge 4: Multivariate and Grouping Round-Trip Invariants',
    () {
      final expressions = <Expr>[
        // Linear and constant edge cases
        const RationalNumber(0),
        const RationalNumber(42),
        const RationalNumber(-7, 3),
        x,
        -x,
        const RationalNumber(5) * x,
        const RationalNumber(-3) * x + 7,

        // Multivariate products
        (x - y) * (x + y),
        Pow(x + const RationalNumber(2) * y, const RationalNumber(2)),
        Pow(
          const RationalNumber(2) * x - const RationalNumber(3) * y,
          const RationalNumber(2),
        ),
        (x + y + 1) * (x + y),
        (x - y) * (x.pow(2) + x * y + y.pow(2)),
        (x + y) * (x.pow(2) - x * y + y.pow(2)),
        Pow(x.pow(2) + y.pow(2), const RationalNumber(2)),
        Pow(x.pow(2) - y.pow(2), const RationalNumber(2)),
        x.pow(2) * y.pow(2) - 1,

        // Multivariate grouping
        x * y + const RationalNumber(2) * x + const RationalNumber(3) * y + 6,
        const RationalNumber(3) * x * x * y +
            const RationalNumber(6) * x * y * y,
        const RationalNumber(4) * x * x - const RationalNumber(9) * y * y,
      ];

      for (final expr in expressions) {
        test(
          'round-trip invariant: factor().expand() == expand() for $expr',
          () {
            final factored = expr.factor();
            final roundTrip = factored.expand();
            final expected = expr.expand();
            check(roundTrip).equals(expected);
          },
        );
      }
    },
  );

  group('Empirical Challenge 5: Rational Function Invariants', () {
    test('cancelling common factors across numerators and denominators', () {
      // (x^2 - 1) / (x - 1) = x + 1
      final q1 = (x.pow(2) - 1) / (x - 1);
      check(q1.factor()).equals(x + 1);

      // (x^3 - 1) / (x - 1) = x^2 + x + 1
      final q2 = (x.pow(3) - 1) / (x - 1);
      check(q2.factor()).equals(x.pow(2) + x + 1);

      // (x^4 - 1) / (x^2 - 1) = x^2 + 1
      final q3 = (x.pow(4) - 1) / (x.pow(2) - 1);
      check(q3.factor()).equals(x.pow(2) + 1);

      // (x^2 - 2x + 1) / (x - 1)^2 = 1
      final q4 =
          (x.pow(2) - const RationalNumber(2) * x + 1) /
          Pow(x - 1, const RationalNumber(2));
      check(q4.factor()).equals(const RationalNumber(1));

      // (x^3 - 6x^2 + 11x - 6) / (x^2 - 3x + 2) = x - 3
      final q5 =
          (x.pow(3) -
              const RationalNumber(6) * x.pow(2) +
              const RationalNumber(11) * x -
              6) /
          (x.pow(2) - const RationalNumber(3) * x + 2);
      check(q5.factor()).equals(x - 3);
    });
  });

  group(
    'Empirical Challenge 6: Trivariate Grouping and Degree 5 Polynomials',
    () {
      test('trivariate grouping with common monomial GCD', () {
        const z = Variable('z');
        // x * (y + 3) * (z + 2) = x*y*z + 2*x*y + 3*x*z + 6*x
        final expr =
            x * y * z +
            const RationalNumber(2) * x * y +
            const RationalNumber(3) * x * z +
            const RationalNumber(6) * x;
        final factored = expr.factor();
        check(factored).equals(x * (y + 3) * (z + 2));
        check(factored.expand()).equals(expr.expand());
      });

      test('degree 5 polynomial with 5 rational roots', () {
        // (x - 1)(x - 2)(x - 3)(x - 4)(x - 5)
        // = x^5 - 15x^4 + 85x^3 - 225x^2 + 274x - 120
        final expr =
            x.pow(5) -
            const RationalNumber(15) * x.pow(4) +
            const RationalNumber(85) * x.pow(3) -
            const RationalNumber(225) * x.pow(2) +
            const RationalNumber(274) * x -
            120;
        final factored = expr.factor();
        check(factored).equals((x - 1) * (x - 2) * (x - 3) * (x - 4) * (x - 5));
        check(factored.expand()).equals(expr.expand());
      });

      test('transcendental difference of squares', () {
        // sin(x)^2 - 1 = (sin(x) - 1)(sin(x) + 1)
        const sinX = Sin(x);
        final expr = sinX.pow(2) - 1;
        final factored = expr.factor();
        check(factored).equals((sinX - 1) * (sinX + 1));
        check(factored.expand()).equals(expr.expand());
      });
    },
  );

  group('Empirical Challenge 7: Resolved Round-Trip Invariant on Multivariate Power Differences', () {
    test('Pow(x^2 - y^2, 2) satisfies factor().expand() == expand()', () {
      final expr = Pow(x.pow(2) - y.pow(2), const RationalNumber(2));
      final factored = expr.factor();
      check(factored).equals(
        Pow(x - y, const RationalNumber(2)) *
            Pow(x + y, const RationalNumber(2)),
      );

      final roundTrip = factored.expand();
      final expanded = expr.expand();

      check(roundTrip).equals(expanded);
      check(roundTrip.toString()).equals('x ^ 4 + y ^ 4 - 2 * x ^ 2 * y ^ 2');
      check(expanded.toString()).equals('x ^ 4 + y ^ 4 - 2 * x ^ 2 * y ^ 2');
    });
  });
}
