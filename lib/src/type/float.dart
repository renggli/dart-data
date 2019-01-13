library data.type.float;

import 'dart:typed_data';

import 'package:more/printer.dart' show Printer;

import 'type.dart';

abstract class FloatDataType extends DataType<double> {
  const FloatDataType();

  @override
  bool get isNullable => false;

  @override
  double get nullValue => 0.0;

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
