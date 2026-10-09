import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

import '../test_utils.dart';

void main() {
  group('DynamicDataType', () {
    const type = DataType.dynamicType;

    test('attributes', () {
      check(type.name).equals('dynamic');
      check(type.defaultValue).isNull();
      check(type.isNullable).isTrue();
      check(type.isNative).isFalse();
      check(type.toString()).equals('DataType.dynamic');
    });

    test('cast', () {
      check(type.cast('hello')).equals('hello');
      check(type.cast(123)).equals(123);
      check(type.cast(null)).isNull();
    });

    checkListOperations(type, <List<dynamic>>[
      ['a', 1, true],
      [null, 'b', 2],
    ]);
  });
}
