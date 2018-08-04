library data.type.float;

import 'dart:typed_data';

import 'type.dart';

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
  List<double> newList(int length) => Float32List(length);
}

class Float64DataType extends FloatDataType {
  const Float64DataType();

  @override
  String get name => 'FLOAT_64';

  @override
  List<double> newList(int length) => Float64List(length);
}
