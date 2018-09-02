library data.type.integer;

import 'dart:typed_data';

import 'package:more/printer.dart' show Printer;

import 'type.dart';

abstract class IntegerDataType extends DataType<int> {
  const IntegerDataType();

  int get min;

  int get max;

  int get bits;

  bool get isSigned => min < 0;

  @override
  bool get isNullable => false;

  @override
  int get nullValue => 0;

  @override
  int convert(Object value) {
    if (value is num) {
      if (isSigned) {
        return value.toInt().toSigned(bits);
      } else {
        return value.toInt().toUnsigned(bits);
      }
    } else if (value is String) {
      return int.tryParse(value) ?? super.convert(value);
    }
    return super.convert(value);
  }

  @override
  Printer get printer => Printer.fixed();
}

class Int8DataType extends IntegerDataType {
  const Int8DataType();

  @override
  String get name => 'int8';

  @override
  int get min => -128;

  @override
  int get max => 127;

  @override
  int get bits => 8;

  @override
  List<int> newList(int length) => Int8List(length);
}

class Uint8DataType extends IntegerDataType {
  const Uint8DataType();

  @override
  String get name => 'uint8';

  @override
  int get min => 0;

  @override
  int get max => 255;

  @override
  int get bits => 8;

  @override
  List<int> newList(int length) => Uint8List(length);
}

class Int16DataType extends IntegerDataType {
  const Int16DataType();

  @override
  String get name => 'int16';

  @override
  int get min => -32768;

  @override
  int get max => 32767;

  @override
  int get bits => 16;

  @override
  List<int> newList(int length) => Int16List(length);
}

class Uint16DataType extends IntegerDataType {
  const Uint16DataType();

  @override
  String get name => 'uint16';

  @override
  int get min => 0;

  @override
  int get max => 65535;

  @override
  int get bits => 16;

  @override
  List<int> newList(int length) => Uint16List(length);
}

class Int32DataType extends IntegerDataType {
  const Int32DataType();

  @override
  String get name => 'int32';

  @override
  int get min => -2147483648;

  @override
  int get max => 2147483647;

  @override
  int get bits => 32;

  @override
  List<int> newList(int length) => Int32List(length);
}

class Uint32DataType extends IntegerDataType {
  const Uint32DataType();

  @override
  String get name => 'uint32';

  @override
  int get min => 0;

  @override
  int get max => 4294967295;

  @override
  int get bits => 32;

  @override
  List<int> newList(int length) => Uint32List(length);
}

class Int64DataType extends IntegerDataType {
  const Int64DataType();

  @override
  String get name => 'int64';

  @override
  int get min => -9223372036854775808;

  @override
  int get max => 9223372036854775807;

  @override
  int get bits => 64;

  @override
  List<int> newList(int length) => Int64List(length);
}

class Uint64DataType extends IntegerDataType {
  const Uint64DataType();

  @override
  String get name => 'uint64';

  @override
  int get min => 0;

  @override
  int get max => 9223372036854775807; // 18446744073709551615

  @override
  int get bits => 64;

  @override
  List<int> newList(int length) => Uint64List(length);
}
