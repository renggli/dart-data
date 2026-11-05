import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Chebyshev polynomials of the first kind (chebyshevT)', () {
    test('constructs exact symbolic formulas for degrees 0 through 5', () {
      check(chebyshevT(0)).equals(IntegerNumber.one);
      check(chebyshevT(1)).equals(const Variable('x'));
      check(chebyshevT(2).toString()).equals('-1 + 2 * x ^ 2');
      check(chebyshevT(3).toString()).equals('-3 * x + 4 * x ^ 3');
      check(chebyshevT(4).toString()).equals('1 - 8 * x ^ 2 + 8 * x ^ 4');
      check(chebyshevT(5).toString()).equals('5 * x - 20 * x ^ 3 + 16 * x ^ 5');
    });

    test('supports custom variable expression', () {
      const y = Variable('y');
      check(chebyshevT(2, y).toString()).equals('-1 + 2 * y ^ 2');
    });

    test('validates negative degree argument', () {
      check(() => chebyshevT(-1)).throws<RangeError>();
    });

    test('satisfies trigonometric identity Tn(cos(theta)) = cos(n*theta)', () {
      for (var n = 0; n <= 6; n++) {
        final poly = chebyshevT(n);
        for (final theta in [0.2, 0.7, 1.3, 2.1]) {
          final xVal = math.cos(theta);
          final actual = poly.evaluate({'x': xVal});
          final expected = math.cos(n * theta);
          check(actual).isCloseTo(expected, 1e-12);
        }
      }
    });
  });

  group('Chebyshev polynomials of the second kind (chebyshevU)', () {
    test('constructs exact symbolic formulas for degrees 0 through 4', () {
      check(chebyshevU(0)).equals(IntegerNumber.one);
      check(chebyshevU(1).toString()).equals('2 * x');
      check(chebyshevU(2).toString()).equals('-1 + 4 * x ^ 2');
      check(chebyshevU(3).toString()).equals('-4 * x + 8 * x ^ 3');
      check(chebyshevU(4).toString()).equals('1 - 12 * x ^ 2 + 16 * x ^ 4');
    });

    test('supports custom variable expression', () {
      const y = Variable('y');
      check(chebyshevU(3, y).toString()).equals('-4 * y + 8 * y ^ 3');
    });

    test('validates negative degree argument', () {
      check(() => chebyshevU(-1)).throws<RangeError>();
    });

    test('satisfies trigonometric identity Un(cos(theta)) * sin(theta) = sin((n+1)*theta)', () {
      for (var n = 0; n <= 5; n++) {
        final poly = chebyshevU(n);
        for (final theta in [0.3, 0.8, 1.2, 2.4]) {
          final xVal = math.cos(theta);
          final actual = poly.evaluate({'x': xVal}) * math.sin(theta);
          final expected = math.sin((n + 1) * theta);
          check(actual).isCloseTo(expected, 1e-12);
        }
      }
    });
  });

  group('Legendre polynomials (legendreP)', () {
    test('constructs exact symbolic formulas for degrees 0 through 4', () {
      check(legendreP(0)).equals(IntegerNumber.one);
      check(legendreP(1)).equals(const Variable('x'));
      check(legendreP(2).toString()).equals('-1/2 + 3/2 * x ^ 2');
      check(legendreP(3).toString()).equals('-3/2 * x + 5/2 * x ^ 3');
      check(legendreP(4).toString())
          .equals('3/8 - 15/4 * x ^ 2 + 35/8 * x ^ 4');
    });

    test('supports custom variable expression', () {
      const z = Variable('z');
      check(legendreP(2, z).toString()).equals('-1/2 + 3/2 * z ^ 2');
    });

    test('validates negative degree argument', () {
      check(() => legendreP(-1)).throws<RangeError>();
    });

    test('satisfies Pn(1) = 1 and Pn(-1) = (-1)^n', () {
      for (var n = 0; n <= 6; n++) {
        final poly = legendreP(n);
        check(poly.evaluate({'x': 1.0})).isCloseTo(1.0, 1e-12);
        check(poly.evaluate({'x': -1.0}))
            .isCloseTo(n.isEven ? 1.0 : -1.0, 1e-12);
      }
    });
  });

  group('Physicists Hermite polynomials (hermiteH)', () {
    test('constructs exact symbolic formulas for degrees 0 through 4', () {
      check(hermiteH(0)).equals(IntegerNumber.one);
      check(hermiteH(1).toString()).equals('2 * x');
      check(hermiteH(2).toString()).equals('-2 + 4 * x ^ 2');
      check(hermiteH(3).toString()).equals('-12 * x + 8 * x ^ 3');
      check(hermiteH(4).toString()).equals('12 - 48 * x ^ 2 + 16 * x ^ 4');
    });

    test('supports custom variable expression', () {
      const t = Variable('t');
      check(hermiteH(2, t).toString()).equals('-2 + 4 * t ^ 2');
    });

    test('validates negative degree argument', () {
      check(() => hermiteH(-1)).throws<RangeError>();
    });

    test('satisfies derivative relation Hn\'(x) = 2n * H_{n-1}(x)', () {
      for (var n = 1; n <= 5; n++) {
        final dHn = hermiteH(n).derivative('x').simplify();
        final expected = (IntegerNumber.of(2 * n) * hermiteH(n - 1))
            .expand()
            .simplify();
        check(dHn).equals(expected);
      }
    });
  });

  group('Probabilists Hermite polynomials (hermiteHe)', () {
    test('constructs exact symbolic formulas for degrees 0 through 4', () {
      check(hermiteHe(0)).equals(IntegerNumber.one);
      check(hermiteHe(1)).equals(const Variable('x'));
      check(hermiteHe(2).toString()).equals('-1 + x ^ 2');
      check(hermiteHe(3).toString()).equals('-3 * x + x ^ 3');
      check(hermiteHe(4).toString()).equals('3 - 6 * x ^ 2 + x ^ 4');
    });

    test('supports custom variable expression', () {
      const t = Variable('t');
      check(hermiteHe(3, t).toString()).equals('-3 * t + t ^ 3');
    });

    test('validates negative degree argument', () {
      check(() => hermiteHe(-1)).throws<RangeError>();
    });

    test('satisfies derivative relation Hen\'(x) = n * He_{n-1}(x)', () {
      for (var n = 1; n <= 5; n++) {
        final dHen = hermiteHe(n).derivative('x').simplify();
        final expected = (IntegerNumber.of(n) * hermiteHe(n - 1))
            .expand()
            .simplify();
        check(dHen).equals(expected);
      }
    });
  });

  group('Laguerre polynomials (laguerreL)', () {
    test('constructs exact standard Laguerre polynomials (alpha = 0)', () {
      check(laguerreL(0)).equals(IntegerNumber.one);
      check(laguerreL(1).toString()).equals('1 - x');
      check(laguerreL(2).toString()).equals('1 - 2 * x + 1/2 * x ^ 2');
      check(laguerreL(3).toString())
          .equals('1 - 3 * x + 3/2 * x ^ 2 - 1/6 * x ^ 3');
    });

    test(
      'constructs generalized Laguerre polynomials with parameter alpha',
      () {
        check(laguerreL(1, const Variable('x'), IntegerNumber.two).toString())
            .equals('3 - x');
        check(laguerreL(2, const Variable('x'), IntegerNumber.one).toString())
            .equals('3 - 3 * x + 1/2 * x ^ 2');
      },
    );

    test('supports custom variable expression', () {
      const t = Variable('t');
      check(laguerreL(1, t).toString()).equals('1 - t');
    });

    test('validates negative degree argument', () {
      check(() => laguerreL(-1)).throws<RangeError>();
    });

    test('satisfies L_n(0) = 1 for standard Laguerre', () {
      for (var n = 0; n <= 5; n++) {
        final poly = laguerreL(n);
        check(poly.evaluate({'x': 0.0})).isCloseTo(1.0, 1e-12);
      }
    });
  });
}
