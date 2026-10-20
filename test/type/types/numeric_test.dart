import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('NumericDataType', () {
    const type = DataType.numeric;

    test('attributes', () {
      check(type.name).equals('numeric');
      check(type.defaultValue).equals(0);
      check(type.isNullable).isFalse();
      check(type.isNumeric).isTrue();
      check(type.toString()).equals('DataType.numeric');
    });

    test('cast', () {
      check(type.cast(42)).equals(42);
      check(type.cast(3.14)).equals(3.14);
      check(type.cast(BigInt.from(123))).equals(123);
      check(type.cast('123')).equals(123);
      check(type.cast('3.14')).equals(3.14);
      check(type.cast(Fraction(1, 2))).equals(0.5);
    });

    test('field operations', () {
      final field = type.field;
      check(field.additiveIdentity).equals(0);
      check(field.multiplicativeIdentity).equals(1);
      check(field.neg(5)).equals(-5);
      check(field.add(2, 3)).equals(5);
      check(field.sub(7, 3)).equals(4);
      check(field.mul(4, 5)).equals(20);
      check(field.inv(2)).equals(0.5);
      check(field.scale(4, 2.5)).equals(10.0);
      check(field.div(10, 2)).equals(5.0);
      check(field.mod(7, 4)).equals(3);
      check(field.division(7, 4)).equals(1);
      check(field.remainder(7, 4)).equals(3);
      check(field.pow(2, 3)).equals(8);
      check(field.modPow(2, 3, 5)).equals(3);
      check(() => field.modInverse(2, 5)).throws<UnsupportedError>();
      check(() => field.gcd(4, 6)).throws<UnsupportedError>();
      check(field.abs(-4)).equals(4);
      check(field.norm(-4)).equals(4.0);
      check(field.sqrt(9)).equals(3.0);
      check(field.exp(0)).equals(1.0);
      check(field.log(1)).equals(0.0);
      check(field.conjugate(5)).equals(5);
    });

    test('cast error', () {
      check(() => type.cast('abc')).throws<ArgumentError>();
      check(() => type.cast(null)).throws<ArgumentError>();
    });

    checkListOperations(type, <List<num>>[
      [1, 2, 3],
      [-5.5, 0, 10.2],
    ]);

    checkFieldOperations(type, <num>[-2.5, 0.5, 3]);
  });
}
