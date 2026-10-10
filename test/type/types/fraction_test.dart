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
      check(type.cast('3/4')).equals(Fraction(3, 4));
    });

    test('cast error', () {
      check(() => type.cast('abc')).throws<ArgumentError>();
      check(() => type.cast(null)).throws<ArgumentError>();
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
  });
}
