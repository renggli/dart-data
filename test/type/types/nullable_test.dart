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

    test('equality', () {
      final floatNullable = DataType.float64.nullable;
      final equality = floatNullable.equality;
      check(equality.isEqual(null, null)).isTrue();
      check(equality.isEqual(1.0, null)).isFalse();
      check(equality.isEqual(null, 1.0)).isFalse();
      check(equality.isEqual(1.0, 1.0)).isTrue();
      check(equality.isClose(null, null, 1e-6)).isTrue();
      check(equality.isClose(1.0, null, 1e-6)).isFalse();
      check(equality.isClose(null, 1.0, 1e-6)).isFalse();
      check(equality.isClose(1.0, 1.0 + 1e-8, 1e-6)).isTrue();
      check(equality.isClose(1.0, 2.0, 1e-6)).isFalse();
      check(equality.hash(null)).equals(0);
      check(equality.hash(1.0)).equals(DataType.float64.equality.hash(1.0));
    });

    checkListOperations(type, <List<int?>>[
      [1, null, 2],
      [null, null, 10],
    ]);
  });
}
