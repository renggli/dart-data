import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('NumericDataType', () {
    const type = DataType.numeric;

    test('attributes', () {
      check(type.name).equals('numeric');
      check(type.defaultValue).equals(0);
      check(type.isNullable).isFalse();
      check(type.isNumeric).isTrue();
      check(type.toString()).equals('DataType.numeric');
    });

    test('cast', () {
      check(type.cast(42)).equals(42);
      check(type.cast(3.14)).equals(3.14);
      check(type.cast('123')).equals(123);
      check(type.cast('3.14')).equals(3.14);
      check(type.cast(Fraction(1, 2))).equals(0.5);
    });

    test('cast error', () {
      check(() => type.cast('abc')).throws<ArgumentError>();
      check(() => type.cast(null)).throws<ArgumentError>();
    });

    checkListOperations(type, <List<num>>[
      [1, 2, 3],
      [-5.5, 0, 10.2],
    ]);

    checkFieldOperations(type, <num>[-2.5, 0.5, 3]);
  });
}
