library data.type.impl.integer;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/src/shared/config.dart';
import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/system.dart';
import 'package:data/src/type/type.dart';
import 'package:more/number.dart' show Fraction;
import 'package:more/printer.dart' show Printer;

abstract class IntegerDataType extends DataType<int> {
  const IntegerDataType();

  /// Returns the size in bits of this integer.
  int get bits;

  /// Returns the true, if this integer is signed.
  bool get isSigned;

  /// Returns the minimum value of this integer.
  num get min => isSigned ? -math.pow(2, bits - 1) : 0;

  /// Returns the maximum value of this integer.
  num get max => isSigned ? math.pow(2, bits - 1) - 1 : math.pow(2, bits) - 1;

  /// Returns the safe bits of an integer value. In the Dart VM integer are
  /// represented using 63 bits, in JavaScript we only have 53.
  int get safeBits => math.min(bits, isJavaScript ? 53 : 63);

  /// Returns the minimum safe value of this integer.
  num get safeMin => isSigned ? -math.pow(2, safeBits - 1) : 0;

  /// Returns the maximum safe value of this integer.
  num get safeMax =>
      isSigned ? math.pow(2, safeBits - 1) - 1 : math.pow(2, safeBits) - 1;

  @override
  String get name => '${isSigned ? '' : 'u'}int$bits';

  @override
  bool get isNullable => false;

  @override
  int get nullValue => 0;

  @override
  System<int> get system => const IntegerSystem();

  @override
  Equality<int> get equality => const IntegerEquality();

  @override
  int convert(Object value) {
    if (value is num) {
      if (isSigned) {
        return value.toInt().toSigned(bits);
      } else {
        return value.toInt().toUnsigned(bits);
      }
    } else if (value is Fraction) {
      return convert(value.toInt());
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
  int get bits => 8;

  @override
  bool get isSigned => true;

  @override
  List<int> newList(int length) => Int8List(length);
}

class Uint8DataType extends IntegerDataType {
  const Uint8DataType();

  @override
  int get bits => 8;

  @override
  bool get isSigned => false;

  @override
  List<int> newList(int length) => Uint8List(length);
}

class Int16DataType extends IntegerDataType {
  const Int16DataType();

  @override
  int get bits => 16;

  @override
  bool get isSigned => true;

  @override
  List<int> newList(int length) => Int16List(length);
}

class Uint16DataType extends IntegerDataType {
  const Uint16DataType();

  @override
  int get bits => 16;

  @override
  bool get isSigned => false;

  @override
  List<int> newList(int length) => Uint16List(length);
}

class Int32DataType extends IntegerDataType {
  const Int32DataType();

  @override
  int get bits => 32;

  @override
  bool get isSigned => true;

  @override
  List<int> newList(int length) => Int32List(length);
}

class Uint32DataType extends IntegerDataType {
  const Uint32DataType();

  @override
  int get bits => 32;

  @override
  bool get isSigned => false;

  @override
  List<int> newList(int length) => Uint32List(length);
}

class Int64DataType extends IntegerDataType {
  const Int64DataType();

  @override
  int get bits => 64;

  @override
  bool get isSigned => true;

  @override
  List<int> newList(int length) => Int64List(length);
}

class Uint64DataType extends IntegerDataType {
  const Uint64DataType();

  @override
  int get bits => 64;

  @override
  bool get isSigned => false;

  @override
  List<int> newList(int length) => Uint64List(length);
}

class IntegerSystem extends System<int> {
  const IntegerSystem();

  @override
  int get additiveIdentity => 0;

  @override
  int neg(int a) => -a;

  @override
  int add(int a, int b) => a + b;

  @override
  int sub(int a, int b) => a - b;

  @override
  int get multiplicativeIdentity => 1;

  @override
  int inv(num a) => 1 ~/ a;

  @override
  int mul(int a, int b) => a * b;

  @override
  int scale(int a, num f) => (a * f).truncate();

  @override
  int div(int a, int b) => a ~/ b;

  @override
  int mod(int a, int b) => a % b;

  @override
  int pow(int a, int b) => math.pow(a, b).truncate();
}

class IntegerEquality extends Equality<int> {
  const IntegerEquality();

  @override
  bool isClose(int a, int b, double epsilon) => (a - b).abs() < epsilon;
}
