import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  void testInteger<L extends List<int>>(
    IntegerDataType<L> type, {
    required bool isSigned,
    required int bits,
    required int min,
    required int max,
  }) {
    group(type.name, () {
      test('attributes', () {
        check(type.bits).equals(bits);
        check(type.isSigned).equals(isSigned);
        check(type.isInteger).isTrue();
        check(type.isFloat).isFalse();
        check(type.isNumeric).isTrue();
        check(type.isNative).isTrue();
        check(type.defaultValue).equals(0);
        check(type.min).equals(min);
        check(type.max).equals(max);
      });

      test('cast values', () {
        check(type.cast(0)).equals(0);
        check(type.cast(1)).equals(1);
        check(type.cast('42')).equals(42);
        check(type.cast(BigInt.from(10))).equals(10);
      });

      test('cast errors', () {
        check(() => type.cast('abc')).throws<ArgumentError>();
        check(() => type.cast(null)).throws<ArgumentError>();
      });

      checkListOperations(type, <List<int>>[
        [type.safeMin, 0, type.safeMax],
        [1, 2, 3],
      ]);

      checkFieldOperations(type, <int>[-2, 1, 5]);
    });
  }

  group('IntegerDataType', () {
    testInteger(DataType.int8, isSigned: true, bits: 8, min: -128, max: 127);
    testInteger(DataType.uint8, isSigned: false, bits: 8, min: 0, max: 255);
    testInteger(
      DataType.int16,
      isSigned: true,
      bits: 16,
      min: -32768,
      max: 32767,
    );
    testInteger(DataType.uint16, isSigned: false, bits: 16, min: 0, max: 65535);
    testInteger(
      DataType.int32,
      isSigned: true,
      bits: 32,
      min: -2147483648,
      max: 2147483647,
    );
    testInteger(
      DataType.uint32,
      isSigned: false,
      bits: 32,
      min: 0,
      max: 4294967295,
    );
  });
}
