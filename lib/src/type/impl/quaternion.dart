library data.type.impl.quaternion;

import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/field.dart';
import 'package:data/src/type/type.dart';
import 'package:more/number.dart';

class QuaternionDataType extends DataType<Quaternion> {
  const QuaternionDataType();

  @override
  String get name => 'quaternion';

  @override
  bool get isNullable => true;

  @override
  Quaternion get nullValue => null;

  @override
  Quaternion convert(Object value) {
    if (value == null || value is Quaternion) {
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
      return Quaternion.tryParse(value) ?? super.convert(value);
    }
    return super.convert(value);
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
  Quaternion pow(Quaternion a, Quaternion b) => a.pow(b);
}
