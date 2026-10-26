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
        check(type.cast(Fraction(7, 2))).equals(3);
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
    testInteger(
      DataType.int64,
      isSigned: true,
      bits: 64,
      min: DataType.int64.min,
      max: DataType.int64.max,
    );
    testInteger(
      DataType.uint64,
      isSigned: false,
      bits: 64,
      min: 0,
      max: DataType.uint64.max,
    );

    test('safeBits, safeMin, safeMax, and string casting wrap', () {
      check(DataType.int64.safeBits).isGreaterThan(50);
      check(DataType.int64.safeMin).isLessThan(0);
      check(DataType.int64.safeMax).isGreaterThan(0);
      check(DataType.uint64.safeBits).isGreaterThan(50);
      check(DataType.uint64.safeMin).equals(0);
      check(DataType.uint64.safeMax).isGreaterThan(0);
      check(DataType.uint64.max).isGreaterThan(DataType.uint64.min);
      check(DataType.int8.cast('200')).equals(-56);
      check(DataType.uint8.cast('-1')).equals(255);
    });

    test('IntegerField extended operations', () {
      final field = DataType.int32.field;
      check(field.inv(2)).equals(0);
      check(field.scale(4, 2.5)).equals(10);
      check(field.div(10, 3)).equals(3);
      check(field.mod(10, 3)).equals(1);
      check(field.division(10, 3)).equals(3);
      check(field.remainder(10, 3)).equals(1);
      check(field.pow(2, 3)).equals(8);
      check(field.modPow(2, 3, 5)).equals(3);
      check(field.modInverse(3, 11)).equals(4);
      check(field.gcd(12, 18)).equals(6);
      check(field.abs(-5)).equals(5);
      check(field.norm(-5)).equals(5.0);
      check(field.sqrt(16)).equals(4);
      check(field.exp(2)).equals(7);
      check(field.log(10)).equals(2);
      check(field.conjugate(5)).equals(5);
      check(() => field.nan).throws<UnsupportedError>();
      check(() => field.infinity).throws<UnsupportedError>();
      check(() => field.negativeInfinity).throws<UnsupportedError>();
    });
  });
}
