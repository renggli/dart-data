library data.type.impl.float;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/field.dart';
import 'package:data/src/type/models/order.dart';
import 'package:data/src/type/type.dart';
import 'package:more/number.dart' show Fraction;
import 'package:more/printer.dart' show Printer;

abstract class FloatDataType extends DataType<double> {
  const FloatDataType();

  @override
  bool get isNullable => false;

  @override
  double get nullValue => 0;

  @override
  Field<double> get field => const FloatField();

  @override
  Order<double> get order => const NaturalOrder<double>();

  @override
  Equality<double> get equality => const FloatEquality();

  @override
  double cast(Object value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is BigInt) {
      return value.toDouble();
    } else if (value is Fraction) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }
}

class Float32DataType extends FloatDataType {
  const Float32DataType();

  @override
  String get name => 'float32';

  @override
  List<double> newList(int length) => Float32List(length);

  @override
  Printer get printer => Printer.scientific(
        exponentPadding: 3,
        exponentSign: Printer.negativeAndPositiveSign(),
        precision: 3,
      );
}

class Float64DataType extends FloatDataType {
  const Float64DataType();

  @override
  String get name => 'float64';

  @override
  List<double> newList(int length) => Float64List(length);

  @override
  Printer get printer => Printer.scientific(
        exponentPadding: 3,
        exponentSign: Printer.negativeAndPositiveSign(),
        precision: 6,
      );
}

class FloatField extends Field<double> {
  const FloatField();

  @override
  double get additiveIdentity => 0;

  @override
  double neg(double a) => -a;

  @override
  double add(double a, double b) => a + b;

  @override
  double sub(double a, double b) => a - b;

  @override
  double get multiplicativeIdentity => 1;

  @override
  double inv(double a) => 1.0 / a;

  @override
  double mul(double a, double b) => a * b;

  @override
  double scale(double a, num f) => a * f;

  @override
  double div(double a, double b) => a / b;

  @override
  double mod(double a, double b) => a % b;

  @override
  double pow(double a, double b) => math.pow(a, b);
}

class FloatEquality extends Equality<double> {
  const FloatEquality();

  @override
  bool isClose(double a, double b, double epsilon) => (a - b).abs() < epsilon;
}
