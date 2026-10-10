import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('BooleanDataType', () {
    const type = DataType.boolean;

    test('attributes', () {
      check(type.name).equals('boolean');
      check(type.defaultValue).isFalse();
      check(type.isNullable).isFalse();
      check(type.isNative).isFalse();
      check(type.toString()).equals('DataType.boolean');
    });

    test('comparator throws', () {
      check(() => type.comparator(false, true)).throws<UnsupportedError>();
    });

    test('cast', () {
      check(type.cast(true)).isTrue();
      check(type.cast(false)).isFalse();
      check(type.cast(1)).isTrue();
      check(type.cast(0)).isFalse();
      check(type.cast('true')).isTrue();
      check(type.cast('false')).isFalse();
    });

    test('cast error', () {
      check(() => type.cast('foo')).throws<ArgumentError>();
      check(() => type.cast(null)).throws<ArgumentError>();
    });

    checkListOperations(type, <List<bool>>[
      [true, false],
      [false, true, true],
    ]);
  });
}
