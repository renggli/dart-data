import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('factorial', () {
    test('evaluates exact integers and half-integers', () {
      check(factorial(0)).equals(1.0);
      check(factorial(-0.0)).equals(1.0);
      check(factorial(1)).equals(1.0);
      check(factorial(5)).equals(120.0);
      check(factorial(22)).equals(1124000727777607680000.0);
      check(factorial(0.5)).isCloseTo(0.5 * math.sqrt(math.pi), 1e-14);
    });

    test('handles poles, overflows, and non-finite inputs', () {
      check(factorial(-0.5)).isNaN;
      check(factorial(-1)).isNaN;
      check(factorial(-5)).isNaN;
      check(factorial(double.nan)).isNaN;
      check(factorial(double.negativeInfinity)).isNaN;
      check(factorial(double.infinity)).equals(double.infinity);
      check(factorial(171.0)).equals(double.infinity);
    });
  });

  group('factorialLn', () {
    test('evaluates positive real arguments', () {
      check(factorialLn(0)).equals(0.0);
      check(factorialLn(1)).equals(0.0);
      check(factorialLn(5)).isCloseTo(math.log(120.0), 1e-14);
      check(factorialLn(0.5))
          .isCloseTo(math.log(0.5 * math.sqrt(math.pi)), 1e-14);
    });

    test('handles out-of-domain and non-finite inputs', () {
      check(factorialLn(-1)).isNaN;
      check(factorialLn(-2.5)).isNaN;
      check(factorialLn(double.nan)).isNaN;
      check(factorialLn(double.infinity)).equals(double.infinity);
    });
  });

  group('factorialComplex', () {
    test('matches gammaComplex(z + 1) and handles boundaries', () {
      const z = Complex(1.5, 0.8);
      check((factorialComplex(z) - gammaComplex(z + Complex.one)).abs())
          .isLessThan(1e-13);
      check(factorialComplex(Complex.zero)).equals(Complex.one);
      check(factorialComplex(const Complex(5))).equals(const Complex(120.0));
      check(factorialComplex(const Complex(-1)).isNaN).isTrue;
      check(factorialComplex(Complex.nan).isNaN).isTrue;
    });
  });
}
