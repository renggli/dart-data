import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Field', () {
    test('Float field operations', () {
      final field = DataType.float64.field;
      check(field.additiveIdentity).equals(0.0);
      check(field.multiplicativeIdentity).equals(1.0);
      check(field.add(2.0, 3.0)).equals(5.0);
      check(field.sub(5.0, 2.0)).equals(3.0);
      check(field.mul(2.0, 3.0)).equals(6.0);
      check(field.div(6.0, 2.0)).equals(3.0);
      check(field.neg(3.0)).equals(-3.0);
      check(field.inv(2.0)).equals(0.5);
      check(field.scale(4.0, 2.5)).equals(10.0);
      check(field.abs(-4.5)).equals(4.5);
      check(field.norm(-4.5)).equals(4.5);
      check(field.sqrt(9.0)).equals(3.0);
      check(field.conjugate(4.5)).equals(4.5);
    });

    test('Integer field operations', () {
      final field = DataType.int32.field;
      check(field.additiveIdentity).equals(0);
      check(field.multiplicativeIdentity).equals(1);
      check(field.add(10, 20)).equals(30);
      check(field.sub(30, 10)).equals(20);
      check(field.mul(4, 5)).equals(20);
      check(field.div(20, 4)).equals(5);
      check(field.neg(7)).equals(-7);
      check(field.scale(10, 0.5)).equals(5);
      check(field.scale(7, 1.5)).equals(11);
      check(field.remainder(-5, 3)).equals(-2);
      check(field.modInverse(3, 11)).equals(4);
      check(field.gcd(12, 18)).equals(6);
      check(field.abs(-10)).equals(10);
      check(field.norm(-10)).equals(10.0);
      check(field.conjugate(10)).equals(10);
    });
  });
}
