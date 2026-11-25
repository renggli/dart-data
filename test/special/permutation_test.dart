import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/scaffolding.dart';

void main() {
  group('permutation', () {
    test('computes exact integer and large permutations', () {
      check(permutation(5, 2)).equals(20.0);
      check(permutation(10, 3)).equals(720.0);
      check(permutation(20, 3)).equals(6840.0);
      check(permutation(50, 10)).isCloseTo(3.7276043023296e16, 1e4);
      check(permutation(200, 2)).equals(39800.0);
      check(permutation(1e20, 2)).isCloseTo(1e40, 1e26);
    });

    test('handles boundaries and non-finite inputs', () {
      check(permutation(5, 0)).equals(1.0);
      check(permutation(5, 6)).equals(0.0);
      check(permutation(5, -1)).equals(0.0);
      check(permutation(double.nan, 2)).isNaN;
      check(permutation(5, double.nan)).isNaN;
      check(permutation(double.infinity, 2)).equals(double.infinity);
      check(permutation(double.infinity, double.infinity)).isNaN;
    });
  });

  group('permutationLn', () {
    test('avoids cancellation for small k and matches gammaLn', () {
      check(permutationLn(5, 2)).isCloseTo(math.log(20.0), 1e-14);
      check(permutationLn(1e10, 2))
          .isCloseTo(math.log(1e10) + math.log(1e10 - 1.0), 1e-14);
      check(permutationLn(100, 50))
          .isCloseTo(gammaLn(101) - gammaLn(51), 1e-13);
    });

    test('handles boundaries and non-finite inputs', () {
      check(permutationLn(5, 0)).equals(0.0);
      check(permutationLn(5, 6)).isNaN;
      check(permutationLn(double.infinity, 2)).equals(double.infinity);
      check(permutationLn(double.infinity, double.infinity)).isNaN;
      check(permutationLn(double.nan, 2)).isNaN;
    });
  });

  group('permutationComplex', () {
    test('evaluates falling factorials and complex arguments', () {
      check(permutationComplex(const Complex(5), const Complex(2)))
          .equals(const Complex(20));
      check(permutationComplex(const Complex(5), const Complex(6)))
          .equals(Complex.zero);
      check(permutationComplex(const Complex(5, 1), Complex.zero))
          .equals(Complex.one);
      check(permutationComplex(const Complex(5, 1), const Complex(-1)))
          .equals(Complex.zero);

      const n = Complex(4.5, 0.5);
      const k = Complex(1.5, -0.3);
      final expected = gammaComplex(n + 1) / gammaComplex(n - k + 1);
      check((permutationComplex(n, k) - expected).abs()).isLessThan(1e-12);
      check(permutationComplex(Complex.nan, k).isNaN).isTrue;
    });
  });
}
