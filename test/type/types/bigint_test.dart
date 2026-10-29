import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

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

    test('BigIntEquality isClose and BigIntField scale', () {
      final equality = type.equality;
      final bigA = BigInt.parse(
        '100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
      );
      final bigB = bigA + BigInt.one;
      check(equality.isClose(bigA, bigB, 2.0)).isTrue();
      check(equality.isClose(bigA, bigB, 0.5)).isFalse();
      check(equality.isClose(bigA, bigB, double.infinity)).isTrue();
      check(equality.isClose(bigA, bigB, double.nan)).isFalse();
      check(equality.isClose(bigA, bigB, -1.0)).isFalse();

      final field = type.field;
      check(field.scale(BigInt.from(10), double.nan)).equals(BigInt.zero);
      check(field.scale(BigInt.from(10), double.infinity)).equals(BigInt.zero);
    });

    test('BigIntField extended operations', () {
      final field = type.field;
      check(field.inv(BigInt.two)).equals(BigInt.zero);
      check(field.scale(BigInt.from(10), 0.5)).equals(BigInt.from(5));
      check(field.div(BigInt.from(10), BigInt.from(3))).equals(BigInt.from(3));
      check(field.mod(BigInt.from(10), BigInt.from(3))).equals(BigInt.one);
      check(field.division(BigInt.from(10), BigInt.from(3)))
          .equals(BigInt.from(3));
      check(field.remainder(BigInt.from(10), BigInt.from(3)))
          .equals(BigInt.one);
      check(field.pow(BigInt.two, BigInt.from(3))).equals(BigInt.from(8));
      check(field.modPow(BigInt.two, BigInt.from(3), BigInt.from(5)))
          .equals(BigInt.from(3));
      check(field.modInverse(BigInt.from(3), BigInt.from(11)))
          .equals(BigInt.from(4));
      check(field.gcd(BigInt.from(12), BigInt.from(18))).equals(BigInt.from(6));
      check(field.abs(BigInt.from(-7))).equals(BigInt.from(7));
      check(field.norm(BigInt.from(-7))).equals(7.0);
      check(field.sqrt(BigInt.from(16))).equals(BigInt.from(4));
      check(field.sqrt(BigInt.zero)).equals(BigInt.zero);
      check(field.sqrt(BigInt.one)).equals(BigInt.one);
      check(() => field.sqrt(BigInt.from(-1))).throws<ArgumentError>();
      check(field.exp(BigInt.zero)).equals(BigInt.one);
      check(field.log(BigInt.one)).equals(BigInt.zero);
      check(field.conjugate(BigInt.from(42))).equals(BigInt.from(42));
      check(() => field.nan).throws<UnsupportedError>();
      check(() => field.infinity).throws<UnsupportedError>();
      check(() => field.negativeInfinity).throws<UnsupportedError>();
    });
  });
}
