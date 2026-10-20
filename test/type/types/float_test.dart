import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('FloatDataType', () {
    group('float32', () {
      const type = DataType.float32;

      test('attributes', () {
        check(type.name).equals('float32');
        check(type.bits).equals(32);
        check(type.bytesPerElement).equals(4);
        check(type.isFloat).isTrue();
        check(type.isInteger).isFalse();
        check(type.isNumeric).isTrue();
        check(type.isNative).isTrue();
        check(type.defaultValue).equals(0.0);
        check(type.min).isLessThan(0.0);
        check(type.max).isGreaterThan(0.0);
        check(type.epsilon).isGreaterThan(0.0);
        check(type.minPositive).isGreaterThan(0.0);
      });

      test('cast', () {
        check(type.cast(0)).equals(0.0);
        check(type.cast(1.5)).equals(1.5);
        check(type.cast(BigInt.from(42))).equals(42.0);
        check(type.cast(Fraction(3, 2))).equals(1.5);
        check(type.cast('3.25')).equals(3.25);
      });

      checkListOperations(type, <List<double>>[
        [1.5, 0.375],
        [-0.75, 1.5, 0.375],
      ]);

      checkFieldOperations(type, <double>[-0.75, 0.375, 1.5]);
    });

    group('float64', () {
      const type = DataType.float64;

      test('attributes', () {
        check(type.name).equals('float64');
        check(type.bits).equals(64);
        check(type.bytesPerElement).equals(8);
        check(type.isFloat).isTrue();
        check(type.isInteger).isFalse();
        check(type.isNumeric).isTrue();
        check(type.isNative).isTrue();
        check(type.defaultValue).equals(0.0);
      });

      test('min, max, epsilon', () {
        check(type.min).isLessThan(0.0);
        check(type.max).isGreaterThan(0.0);
        check(type.epsilon).isGreaterThan(0.0);
        check(type.minPositive).isGreaterThan(0.0);
      });

      test('cast', () {
        check(type.cast(0)).equals(0.0);
        check(type.cast(1.5)).equals(1.5);
        check(type.cast('3.25')).equals(3.25);
      });

      checkListOperations(type, <List<double>>[
        [1.5, 0.375],
        [-0.75, 1.5, 0.375],
      ]);

      checkFieldOperations(type, <double>[-0.75, 0.375, 1.5]);
    });

    test('FloatField extended operations', () {
      final field = DataType.float64.field;
      check(field.inv(2.0)).equals(0.5);
      check(field.scale(2.5, 3)).equals(7.5);
      check(field.div(7.5, 2.5)).equals(3.0);
      check(field.mod(7.5, 2.0)).equals(1.5);
      check(field.division(7.5, 2.0)).equals(3.0);
      check(field.remainder(7.5, 2.0)).equals(1.5);
      check(field.pow(2.0, 3.0)).equals(8.0);
      check(field.modPow(2.0, 3.0, 5.0)).equals(3.0);
      check(field.abs(-3.5)).equals(3.5);
      check(field.norm(-3.5)).equals(3.5);
      check(field.sqrt(9.0)).equals(3.0);
      check(field.exp(0.0)).equals(1.0);
      check(field.log(1.0)).equals(0.0);
      check(field.conjugate(4.2)).equals(4.2);
      check(field.nan.isNaN).isTrue();
      check(field.infinity.isInfinite).isTrue();
      check(field.negativeInfinity.isInfinite).isTrue();
      check(() => field.modInverse(2.0, 5.0)).throws<UnsupportedError>();
      check(() => field.gcd(2.0, 5.0)).throws<UnsupportedError>();
    });
  });
}
