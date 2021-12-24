import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import '../models/equality.dart';
import '../models/field.dart';
import '../models/order.dart';
import '../type.dart';

class NumericDataType extends DataType<num> {
  const NumericDataType();

  @override
  String get name => 'numeric';

  @override
  num get defaultValue => 0;

  @override
  Equality<num> get equality => const NumericEquality();

  @override
  Order<num> get order => const NaturalOrder<num>();

  @override
  Field<num> get field => const NumericField();

  @override
  num cast(dynamic value) {
    if (value is num) {
      return value;
    } else if (value is BigInt) {
      return value.toInt();
    } else if (value is Fraction) {
      return value.toDouble();
    } else if (value is String) {
      return num.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }
}

class NumericField extends Field<num> {
  const NumericField();

  @override
  num get additiveIdentity => 0;

  @override
  num neg(num a) => -a;

  @override
  num add(num a, num b) => a + b;

  @override
  num sub(num a, num b) => a - b;

  @override
  num get multiplicativeIdentity => 1;

  @override
  num inv(num a) => 1 / a;

  @override
  num mul(num a, num b) => a * b;

  @override
  num scale(num a, num f) => a * f;

  @override
  num div(num a, num b) => a / b;

  @override
  num mod(num a, num b) => a % b;

  @override
  num division(num a, num b) => a ~/ b;

  @override
  num remainder(num a, num b) => a.remainder(b);

  @override
  num pow(num base, num exponent) => math.pow(base, exponent);

  @override
  num modPow(num base, num exponent, num modulus) =>
      mod(pow(base, exponent), modulus);

  @override
  num modInverse(num base, num modulus) => unsupportedOperation('modInverse');

  @override
  num gcd(num a, num b) => unsupportedOperation('gcd');
}

class NumericEquality extends NaturalEquality<num> {
  const NumericEquality();

  @override
  bool isClose(num a, num b, double epsilon) => (a - b).abs() < epsilon;
}
