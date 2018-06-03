library pandas.type.float;

import 'package:pandas/src/type.dart';

import 'dart:typed_data';

abstract class FloatDataType extends DataType<double> {
  const FloatDataType();

  @override
  bool get isNullable => false;

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
  String get name => 'FLOAT_32';

  @override
  List<double> newList(int length) => new Float32List(length);
}

class Float64DataType extends FloatDataType {
  const Float64DataType();

  @override
  String get name => 'FLOAT_64';

  @override
  List<double> newList(int length) => new Float64List(length);
}
