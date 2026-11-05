import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

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

    test('isClose', () {
      check(type.equality.isClose('kitten', 'sitting', 3.0)).isTrue();
      check(type.equality.isClose('kitten', 'sitting', 3.5)).isTrue();
      check(type.equality.isClose('kitten', 'sitting', 2.0)).isFalse();

      final eq = type.equality;
      check(eq.isClose('hello', 'hello', 0.0)).isTrue();
      check(eq.isClose('hello', 'hello', 1.0)).isTrue();
      check(eq.isClose('hello', 'hello', -0.5)).isFalse();
      check(eq.isClose('hello', 'hello', double.nan)).isFalse();

      check(eq.isClose('a', 'b', double.nan)).isFalse();
      check(eq.isClose('a', 'b', -1.0)).isFalse();
      check(eq.isClose('a', 'b', 0.5)).isFalse();
      check(eq.isClose('a', 'b', double.infinity)).isTrue();
      check(eq.isClose('short', 'very long string with length diff > 2', 2.0))
          .isFalse();
      check(eq.isClose('a', 'abcde', 2.0)).isFalse();
      check(eq.isClose('abcde', 'a', 2.0)).isFalse();
    });

    checkListOperations(type, <List<String>>[
      ['apple', 'banana'],
      ['cat', 'dog', 'elephant'],
    ]);
  });
}
