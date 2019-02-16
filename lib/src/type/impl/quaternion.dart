library data.type.impl.quaternion;

import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/system.dart';
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
    } else if (value is Fraction) {
      return Quaternion(value.toDouble());
    } else if (value is Complex) {
      return Quaternion(value.a, value.b);
    }
    return super.convert(value);
  }

  @override
  System<Quaternion> get system => const QuaternionSystem();

  @override
  Equality<Quaternion> get equality => const QuaternionEquality();
}

class QuaternionEquality extends Equality<Quaternion> {
  const QuaternionEquality();

  @override
  bool isClose(Quaternion a, Quaternion b, double epsilon) =>
      (a - b).abs() < epsilon;
}

class QuaternionSystem extends System<Quaternion> {
  const QuaternionSystem();

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
  Quaternion scale(Quaternion a, num f) =>
      Quaternion(a.a * f, a.b * f, a.c * f, a.d * f);

  @override
  Quaternion div(Quaternion a, Quaternion b) => a / b;

  @override
  Quaternion mod(Quaternion a, Quaternion b) => unsupportedOperation('mod');

  @override
  Quaternion pow(Quaternion a, Quaternion b) => a.pow(b);
}
