import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('FractionDataType', () {
    const type = DataType.fraction;

    test('attributes', () {
      check(type.name).equals('fraction');
      check(type.defaultValue).equals(Fraction.zero);
      check(type.isNullable).isFalse();
      check(type.isNative).isFalse();
      check(type.toString()).equals('DataType.fraction');
    });

    test('comparator', () {
      check(type.comparator(Fraction(1, 3), Fraction(1, 2))).isLessThan(0);
      check(type.comparator(Fraction(1, 2), Fraction(1, 3))).isGreaterThan(0);
    });

    test('cast', () {
      check(type.cast(Fraction(1, 2))).equals(Fraction(1, 2));
      check(type.cast(2)).equals(Fraction(2));
      check(type.cast(0.5)).equals(Fraction(1, 2));
      check(type.cast(BigInt.from(5))).equals(Fraction(5));
      check(type.cast('3/4')).equals(Fraction(3, 4));
    });

    test('cast error', () {
      check(() => type.cast('abc')).throws<ArgumentError>();
      check(() => type.cast(null)).throws<ArgumentError>();
      check(
        () => type.cast(
          BigInt.parse('10000000000000000000000000000000000000000'),
        ),
      ).throws<ArgumentError>();
    });

    checkListOperations(type, <List<Fraction>>[
      [Fraction(1, 2), Fraction(3, 4)],
      [Fraction(-1, 3), Fraction.zero, Fraction(5, 2)],
    ]);

    checkFieldOperations(type, <Fraction>[
      Fraction(-1, 2),
      Fraction(1, 3),
      Fraction(2, 1),
    ]);

    test('FractionField extended operations', () {
      final field = type.field;
      check(field.inv(Fraction(2, 3))).equals(Fraction(3, 2));
      check(field.scale(Fraction(2, 3), 3)).equals(Fraction(2));
      check(field.div(Fraction(1, 2), Fraction(1, 4))).equals(Fraction(2));
      check(field.pow(Fraction(2, 3), Fraction(2))).equals(Fraction(4, 9));
      check(field.abs(Fraction(-2, 3))).equals(Fraction(2, 3));
      check(field.norm(Fraction(-2, 3))).isCloseTo(2 / 3, 1e-10);
      check(field.conjugate(Fraction(2, 3))).equals(Fraction(2, 3));
      check(field.sqrt(Fraction(4, 9))).equals(Fraction(2, 3));
      check(field.exp(Fraction.zero)).equals(Fraction.one);
      check(field.log(Fraction.one)).equals(Fraction.zero);
      check(() => field.nan).throws<UnsupportedError>();
      check(() => field.infinity).throws<UnsupportedError>();
      check(() => field.negativeInfinity).throws<UnsupportedError>();

      check(() => field.mod(Fraction(1), Fraction(2)))
          .throws<UnsupportedError>();
      check(() => field.division(Fraction(1), Fraction(2)))
          .throws<UnsupportedError>();
      check(() => field.remainder(Fraction(1), Fraction(2)))
          .throws<UnsupportedError>();
      check(() => field.modPow(Fraction(1), Fraction(2), Fraction(3)))
          .throws<UnsupportedError>();
      check(() => field.modInverse(Fraction(1), Fraction(2)))
          .throws<UnsupportedError>();
      check(() => field.gcd(Fraction(1), Fraction(2)))
          .throws<UnsupportedError>();
    });
  });
}
