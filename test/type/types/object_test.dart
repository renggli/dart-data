import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

import '../test_utils.dart';

void main() {
  group('ObjectDataType', () {
    const type = DataType.object;

    test('attributes', () {
      check(type.name).equals('object');
      check(type.defaultValue).isNull();
      check(type.isNullable).isTrue();
      check(type.isNative).isFalse();
      check(type.toString()).equals('DataType.object');
    });

    test('createObject custom default', () {
      final custom = DataType.createObject<int>(42);
      check(custom.defaultValue).equals(42);
      check(custom.isNullable).isFalse();
    });

    test('nullableObject', () {
      final nullable = DataType.nullableObject<String>();
      check(nullable.defaultValue).isNull();
      check(nullable.isNullable).isTrue();
    });

    test('cast', () {
      check(type.cast('hello')).equals('hello');
      check(type.cast(123)).equals(123);
      check(type.cast(null)).isNull();
    });

    checkListOperations(type, <List<Object?>>[
      ['a', 1, true],
      [null, 'b', 2],
    ]);
  });
}
