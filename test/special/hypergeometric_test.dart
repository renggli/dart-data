import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/special.dart';
import 'package:test/test.dart';

void main() {
  group('Hypergeometric functions', () {
    test('confluent hypergeometric 1F1 standard cases', () {
      check(hypergeometric1F1(2, 2, 0.5)).isCloseTo(math.exp(0.5), 1e-12);
      check(hypergeometric1F1(5, 5, 1.2)).isCloseTo(math.exp(1.2), 1e-12);
      check(hypergeometric1F1(0, 3.5, 2.5)).equals(1.0);
      check(hypergeometric1F1(1, 0, 0.5)).isNaN();
      check(hypergeometric1F1(1, -2, 0.5)).isNaN();
    });

    test('Gauss hypergeometric 2F1 standard cases', () {
      check(hypergeometric2F1(1, 2, 2, 0.5)).isCloseTo(2.0, 1e-12);
      check(hypergeometric2F1(2, 3, 3, 0.5)).isCloseTo(4.0, 1e-12);
      check(hypergeometric2F1(3, 1.5, 1.5, 0.2))
          .isCloseTo(1.0 / (0.8 * 0.8 * 0.8), 1e-12);
      check(hypergeometric2F1(0, 2.5, 4.5, 0.7)).equals(1.0);
    });

    test('Gauss hypergeometric 2F1 transformations and boundaries', () {
      check(hypergeometric2F1(1, 2, 3, -2.0))
          .isCloseTo(0.45069385566594444, 1e-12);
      check(hypergeometric2F1(0.5, 0.5, 1.5, 0.95))
          .isCloseTo(1.3802311542699408, 1e-12);
      check(hypergeometric2F1(1.0, 1.0, 3.0, 1.0)).isCloseTo(2.0, 1e-12);
    });
  });
}
