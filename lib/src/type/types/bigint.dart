import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import '../data_type.dart';
import '../models/equality.dart';
import '../models/field.dart';

class BigIntDataType extends DataType<BigInt> {
  const new();

  @override
  String get name => 'bigInt';

  @override
  BigInt get defaultValue => BigInt.zero;

  @override
  int comparator(BigInt a, BigInt b) => a.compareTo(b);

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
  Field<BigInt> get field => const BigIntField();
}

class BigIntEquality extends NaturalEquality<BigInt> {
  const new();

  @override
  bool isClose(BigInt a, BigInt b, double epsilon) =>
      (a - b).abs() < BigInt.from(epsilon.ceil());
}

class BigIntField extends ExtendedField<BigInt> {
  const new();

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
  BigInt scale(BigInt a, num f) {
    if (f is int) return a * BigInt.from(f);
    final frac = Fraction.fromDouble(f.toDouble());
    return (a * BigInt.from(frac.numerator)) ~/ BigInt.from(frac.denominator);
  }

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

  @override
  BigInt abs(BigInt a) => a.abs();

  @override
  double norm(BigInt a) => a.abs().toDouble();

  @override
  BigInt sqrt(BigInt a) {
    if (a < BigInt.zero) throw ArgumentError.value(a, 'a', 'Negative value');
    if (a == BigInt.zero) return BigInt.zero;
    var x0 = a >> 1;
    if (x0 > BigInt.zero) {
      var x1 = (x0 + a ~/ x0) >> 1;
      while (x1 < x0) {
        x0 = x1;
        x1 = (x0 + a ~/ x0) >> 1;
      }
      return x0;
    }
    return BigInt.one;
  }

  @override
  BigInt exp(BigInt a) => BigInt.from(math.exp(a.toDouble()).round());

  @override
  BigInt log(BigInt a) => BigInt.from(math.log(a.toDouble()).round());

  @override
  BigInt conjugate(BigInt a) => a;
}
