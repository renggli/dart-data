import 'package:checks/checks.dart';
import 'package:data/src/polynomial/impl/formatting.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Polynomial formatting', () {
    test('empty terms formats to 0', () {
      final s = formatPolynomialTerms<int>(DataType.int32, []);
      check(s).equals('0');
    });

    test('positive terms in descending degrees', () {
      final s = formatPolynomialTerms<int>(DataType.int32, [
        (exponent: 3, coefficient: 2),
        (exponent: 1, coefficient: 1),
        (exponent: 0, coefficient: 5),
      ]);
      check(s).equals('2x^3 + x + 5');
    });

    test('negative leading and interior terms', () {
      final s = formatPolynomialTerms<double>(DataType.float64, [
        (exponent: 2, coefficient: -1.0),
        (exponent: 1, coefficient: -3.5),
        (exponent: 0, coefficient: 4.25),
      ]);
      check(s).equals('-x^2 - 3.5x + 4.25');
    });

    test('BigInt terms with negative coefficients', () {
      final s = formatPolynomialTerms<BigInt>(DataType.bigInt, [
        (exponent: 2, coefficient: BigInt.from(5)),
        (exponent: 0, coefficient: BigInt.from(-7)),
      ]);
      check(s).equals('5x^2 - 7');
    });
  });
}
