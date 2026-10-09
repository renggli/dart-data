import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

import '../test_utils.dart';

void main() {
  group('BigIntDataType', () {
    const type = DataType.bigInt;

    test('attributes', () {
      check(type.name).equals('bigInt');
      check(type.defaultValue).equals(BigInt.zero);
      check(type.isNullable).isFalse();
      check(type.isNative).isFalse();
      check(type.toString()).equals('DataType.bigInt');
    });

    test('comparator', () {
      check(type.comparator(BigInt.from(1), BigInt.from(2))).isLessThan(0);
      check(type.comparator(BigInt.from(2), BigInt.from(1))).isGreaterThan(0);
      check(type.comparator(BigInt.from(3), BigInt.from(3))).equals(0);
    });

    test('cast', () {
      check(type.cast(BigInt.from(42))).equals(BigInt.from(42));
      check(type.cast(42)).equals(BigInt.from(42));
      check(type.cast('42')).equals(BigInt.from(42));
    });

    test('cast error', () {
      check(() => type.cast('abc')).throws<ArgumentError>();
      check(() => type.cast(null)).throws<ArgumentError>();
    });

    checkListOperations(type, <List<BigInt>>[
      [BigInt.from(1), BigInt.from(2)],
      [BigInt.from(-10), BigInt.zero, BigInt.from(100)],
    ]);

    checkFieldOperations(type, <BigInt>[
      BigInt.from(-5),
      BigInt.from(2),
      BigInt.from(10),
    ]);
  });
}
