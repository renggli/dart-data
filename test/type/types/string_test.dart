import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

import '../test_utils.dart';

void main() {
  group('StringDataType', () {
    const type = DataType.string;

    test('attributes', () {
      check(type.name).equals('string');
      check(type.defaultValue).equals('');
      check(type.isNullable).isFalse();
      check(type.isNative).isFalse();
      check(type.toString()).equals('DataType.string');
    });

    test('comparator', () {
      check(type.comparator('apple', 'banana')).isLessThan(0);
      check(type.comparator('banana', 'apple')).isGreaterThan(0);
      check(type.comparator('apple', 'apple')).equals(0);
    });

    test('cast', () {
      check(type.cast('hello')).equals('hello');
      check(type.cast(123)).equals('123');
      check(type.cast(true)).equals('true');
      check(type.cast(null)).equals('null');
    });

    test('editDistance and isClose', () {
      check(editDistance('kitten', 'sitting')).equals(3);
      check(type.equality.isClose('kitten', 'sitting', 3.5)).isTrue();
      check(type.equality.isClose('kitten', 'sitting', 2.0)).isFalse();
    });

    checkListOperations(type, <List<String>>[
      ['apple', 'banana'],
      ['cat', 'dog', 'elephant'],
    ]);
  });
}
