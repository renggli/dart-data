library data.type.impl.float;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/src/type/models/system.dart';
import 'package:data/src/type/type.dart';
import 'package:more/printer.dart' show Printer;

abstract class FloatDataType extends DataType<double> {
  const FloatDataType();

  @override
  bool get isNullable => false;

  @override
  double get nullValue => 0.0;

  @override
  System<double> get system => const FloatSystem();

  @override
  double convert(Object value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? super.convert(value);
    }
    return super.convert(value);
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

class FloatSystem extends System<double> {
  const FloatSystem();

  @override
  double get additiveIdentity => 0.0;

  @override
  double neg(double a) => -a;

  @override
  double add(double a, double b) => a + b;

  @override
  double sub(double a, double b) => a - b;

  @override
  double get multiplicativeIdentity => 1.0;

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
