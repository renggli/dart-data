import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('NullableDataType', () {
    final type = DataType.int32.nullable;

    test('attributes', () {
      check(type.name).equals('int32.nullable');
      check(type.defaultValue).isNull();
      check(type.isNullable).isTrue();
      check(type.nullable).identicalTo(type);
      check(type.toString()).equals('DataType.int32.nullable');
    });

    test('comparator default (nulls last)', () {
      check(type.comparator(null, 10)).isGreaterThan(0);
      check(type.comparator(10, null)).isLessThan(0);
      check(type.comparator(null, null)).equals(0);
      check(type.comparator(5, 10)).isLessThan(0);
    });

    test('comparator nullsFirst', () {
      final nullsFirst = NullableDataType(DataType.int32, nullsFirst: true);
      check(nullsFirst.comparator(null, 10)).isLessThan(0);
      check(nullsFirst.comparator(10, null)).isGreaterThan(0);
      check(nullsFirst.comparator(null, null)).equals(0);
    });

    test('cast', () {
      check(type.cast(null)).isNull();
      check(type.cast(42)).equals(42);
      check(type.cast('42')).equals(42);
    });

    test('cast error', () {
      check(() => type.cast('abc')).throws<ArgumentError>();
    });

    checkListOperations(type, <List<int?>>[
      [1, null, 2],
      [null, null, 10],
    ]);
  });
}
