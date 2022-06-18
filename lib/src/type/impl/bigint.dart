import 'package:more/ordering.dart' show Ordering;

import '../models/equality.dart';
import '../models/field.dart';
import '../type.dart';

class BigIntDataType extends DataType<BigInt> {
  const BigIntDataType();

  @override
  String get name => 'bigInt';

  @override
  BigInt get defaultValue => BigInt.zero;

  @override
  BigInt cast(dynamic value) {
    if (value is BigInt) {
      return value;
    } else if (value is num) {
      return BigInt.from(value);
    } else if (value is String) {
      return BigInt.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }

  @override
  Equality<BigInt> get equality => const BigIntEquality();

  @override
  Ordering<BigInt> get ordering => Ordering.natural<BigInt>();

  @override
  Field<BigInt> get field => const BigIntField();
}

class BigIntEquality extends NaturalEquality<BigInt> {
  const BigIntEquality();

  @override
  bool isClose(BigInt a, BigInt b, double epsilon) =>
      (a - b).abs() < BigInt.from(epsilon.ceil());
}

class BigIntField extends Field<BigInt> {
  const BigIntField();

  @override
  BigInt get additiveIdentity => BigInt.zero;

  @override
  BigInt neg(BigInt a) => -a;

  @override
  BigInt add(BigInt a, BigInt b) => a + b;

  @override
  BigInt sub(BigInt a, BigInt b) => a - b;

  @override
  BigInt get multiplicativeIdentity => BigInt.one;

  @override
  BigInt inv(BigInt a) => BigInt.one ~/ a;

  @override
  BigInt mul(BigInt a, BigInt b) => a * b;

  @override
  BigInt scale(BigInt a, num f) => a * BigInt.from(f.round());

  @override
  BigInt div(BigInt a, BigInt b) => a ~/ b;

  @override
  BigInt mod(BigInt a, BigInt b) => a % b;

  @override
  BigInt division(BigInt a, BigInt b) => a ~/ b;

  @override
  BigInt remainder(BigInt a, BigInt b) => a.remainder(b);

  @override
  BigInt pow(BigInt base, BigInt exponent) => base.pow(exponent.toInt());

  @override
  BigInt modPow(BigInt base, BigInt exponent, BigInt modulus) =>
      base.modPow(exponent, modulus);

  @override
  BigInt modInverse(BigInt base, BigInt modulus) => base.modInverse(modulus);

  @override
  BigInt gcd(BigInt a, BigInt b) => a.gcd(b);
}
