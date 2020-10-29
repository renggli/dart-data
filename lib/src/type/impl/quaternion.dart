import 'package:more/number.dart';

import '../models/equality.dart';
import '../models/field.dart';
import '../type.dart';

class QuaternionDataType extends DataType<Quaternion> {
  const QuaternionDataType();

  @override
  String get name => 'quaternion';

  @override
  Quaternion get defaultValue => Quaternion.zero;

  @override
  Quaternion cast(dynamic value) {
    if (value is Quaternion) {
      return value;
    } else if (value is num) {
      return Quaternion(value);
    } else if (value is BigInt) {
      return Quaternion(value.toDouble());
    } else if (value is Fraction) {
      return Quaternion(value.toDouble());
    } else if (value is Complex) {
      return Quaternion(value.a, value.b);
    } else if (value is String) {
      return Quaternion.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }

  @override
  Field<Quaternion> get field => const QuaternionField();

  @override
  Equality<Quaternion> get equality => const QuaternionEquality();
}

class QuaternionEquality extends Equality<Quaternion> {
  const QuaternionEquality();

  @override
  bool isClose(Quaternion a, Quaternion b, double epsilon) =>
      (a - b).abs() < epsilon;
}

class QuaternionField extends Field<Quaternion> {
  const QuaternionField();

  @override
  Quaternion get additiveIdentity => Quaternion.zero;

  @override
  Quaternion neg(Quaternion a) => -a;

  @override
  Quaternion add(Quaternion a, Quaternion b) => a + b;

  @override
  Quaternion sub(Quaternion a, Quaternion b) => a - b;

  @override
  Quaternion get multiplicativeIdentity => Quaternion.one;

  @override
  Quaternion inv(Quaternion a) => a.reciprocal();

  @override
  Quaternion mul(Quaternion a, Quaternion b) => a * b;

  @override
  Quaternion scale(Quaternion a, num f) => a * f;

  @override
  Quaternion div(Quaternion a, Quaternion b) => a / b;

  @override
  Quaternion mod(Quaternion a, Quaternion b) => unsupportedOperation('mod');

  @override
  Quaternion division(Quaternion a, Quaternion b) =>
      unsupportedOperation('division');

  @override
  Quaternion remainder(Quaternion a, Quaternion b) =>
      unsupportedOperation('remainder');

  @override
  Quaternion pow(Quaternion base, Quaternion exponent) => base.pow(exponent);

  @override
  Quaternion modPow(Quaternion base, Quaternion exponent, Quaternion modulus) =>
      unsupportedOperation('modPow');

  @override
  Quaternion modInverse(Quaternion base, Quaternion modulus) =>
      unsupportedOperation('modInverse');

  @override
  Quaternion gcd(Quaternion a, Quaternion b) => unsupportedOperation('gcd');
}
