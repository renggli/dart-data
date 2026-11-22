import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('factorial', () {
    test('factorial and factorialLn', () {
      check(factorial(0)).isCloseTo(1.0, 1e-8);
      check(factorial(5)).isCloseTo(120.0, 1e-8);
      check(factorial(-1)).isNaN;
      check(factorial(double.nan)).isNaN;
      check(factorialLn(5)).isCloseTo(math.log(120.0), 1e-6);
      check(factorialLn(double.nan)).isNaN;
    });

    test('factorialComplex', () {
      const z = Complex(1.5, 0.8);
      check((factorialComplex(z) - gammaComplex(z + Complex.one)).abs())
          .isLessThan(1e-12);
    });
  });
}
