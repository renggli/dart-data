import 'package:more/number.dart';

import '../data_type.dart';
import '../models/equality.dart';
import '../models/field.dart';

/// Data type descriptor for quaternions ([Quaternion]).
final class QuaternionDataType extends DataType<Quaternion> {
  /// Creates a new [QuaternionDataType] instance.
  const new();

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

/// Equality relation for [Quaternion] numbers with proximity testing.
final class QuaternionEquality extends NaturalEquality<Quaternion> {
  /// Creates a new [QuaternionEquality] instance.
  const new();

  @override
  bool isClose(Quaternion a, Quaternion b, double epsilon) =>
      a.closeTo(b, epsilon);
}

/// Algebraic field operations over [Quaternion] numbers.
final class QuaternionField implements Field<Quaternion> {
  /// Creates a new [QuaternionField] instance.
  const new();

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
  Quaternion scale(Quaternion a, num factor) => a * factor;

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

  @override
  Quaternion abs(Quaternion a) => Quaternion(a.abs());

  @override
  double norm(Quaternion a) => a.abs();

  @override
  Quaternion conjugate(Quaternion a) => a.conjugate();

  @override
  Quaternion sqrt(Quaternion a) => unsupportedOperation('sqrt');

  @override
  Quaternion exp(Quaternion a) => unsupportedOperation('exp');

  @override
  Quaternion log(Quaternion a) => unsupportedOperation('log');

  @override
  Quaternion get nan => unsupportedOperation('nan');

  @override
  Quaternion get infinity => unsupportedOperation('infinity');

  @override
  Quaternion get negativeInfinity => unsupportedOperation('negativeInfinity');
}
