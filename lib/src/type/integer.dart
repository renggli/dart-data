library pandas.type.integer;

import 'package:pandas/src/type.dart';

import 'dart:typed_data';

abstract class IntegerDataType extends DataType<int> {
  const IntegerDataType();

  int get min;

  int get max;

  int get bits;

  bool get isSigned => min < 0;

  @override
  bool get isNullable => false;

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
}

class Int8DataType extends IntegerDataType {
  const Int8DataType();

  @override
  String get name => 'INT_8';

  @override
  int get min => -128;

  @override
  int get max => 127;

  @override
  int get bits => 8;

  @override
  List<int> newList(int length) => new Int8List(length);
}

class Uint8DataType extends IntegerDataType {
  const Uint8DataType();

  @override
  String get name => 'UINT_8';

  @override
  int get min => 0;

  @override
  int get max => 255;

  @override
  int get bits => 8;

  @override
  List<int> newList(int length) => new Uint8List(length);
}

class Int16DataType extends IntegerDataType {
  const Int16DataType();

  @override
  String get name => 'INT_16';

  @override
  int get min => -32768;

  @override
  int get max => 32767;

  @override
  int get bits => 16;

  @override
  List<int> newList(int length) => new Int16List(length);
}

class Uint16DataType extends IntegerDataType {
  const Uint16DataType();

  @override
  String get name => 'UINT_16';

  @override
  int get min => 0;

  @override
  int get max => 65535;

  @override
  int get bits => 16;

  @override
  List<int> newList(int length) => new Uint16List(length);
}

class Int32DataType extends IntegerDataType {
  const Int32DataType();

  @override
  String get name => 'INT_32';

  @override
  int get min => -2147483648;

  @override
  int get max => 2147483647;

  @override
  int get bits => 32;

  @override
  List<int> newList(int length) => new Int32List(length);
}

class Uint32DataType extends IntegerDataType {
  const Uint32DataType();

  @override
  String get name => 'UINT_32';

  @override
  int get min => 0;

  @override
  int get max => 4294967295;

  @override
  int get bits => 32;

  @override
  List<int> newList(int length) => new Uint32List(length);
}

class Int64DataType extends IntegerDataType {
  const Int64DataType();

  @override
  String get name => 'INT_64';

  @override
  int get min => -9223372036854775808;

  @override
  int get max => 9223372036854775807;

  @override
  int get bits => 64;

  @override
  List<int> newList(int length) => new Int64List(length);
}

class Uint64DataType extends IntegerDataType {
  const Uint64DataType();

  @override
  String get name => 'UINT_64';

  @override
  int get min => 0;

  @override
  int get max => 18446744073709551615;

  @override
  int get bits => 64;

  @override
  List<int> newList(int length) => new Uint64List(length);
}
