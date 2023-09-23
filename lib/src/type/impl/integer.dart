import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/feature.dart' show isJavaScript;
import 'package:more/number.dart' show Fraction;
import 'package:more/printer.dart' show FixedNumberPrinter, Printer;

import '../models/equality.dart';
import '../models/field.dart';
import 'typed.dart';

abstract class IntegerDataType<L extends List<int>>
    extends TypedDataType<int, L> {
  const IntegerDataType();

  /// Returns the true, if this integer is signed.
  bool get isSigned;

  /// Returns the safe bits of an integer value. In the Dart VM integer are
  /// represented using 63 bits and a sign, in JavaScript we only have 53.
  int get safeBits => bits;

  /// Returns the minimum safe value of this integer.
  int get safeMin => min;

  /// Returns the maximum safe value of this integer.
  int get safeMax => max;

  @override
  String get name => '${isSigned ? '' : 'u'}int$bits';

  @override
  int get defaultValue => 0;

  @override
  int comparator(int a, int b) => a.compareTo(b);

  @override
  Field<int> get field => const IntegerField();

  @override
  Equality<int> get equality => const IntegerEquality();

  @override
  int cast(dynamic value) {
    if (value is num) {
      if (isSigned) {
        return value.toInt().toSigned(bits);
      } else {
        return value.toInt().toUnsigned(bits);
      }
    } else if (value is BigInt) {
      if (isSigned) {
        return value.toSigned(bits).toInt();
      } else {
        return value.toUnsigned(bits).toInt();
      }
    } else if (value is Fraction) {
      return cast(value.toInt());
    } else if (value is String) {
      return int.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }

  @override
  Printer<int> get printer => FixedNumberPrinter<int>();
}

class Int8DataType extends IntegerDataType<Int8List> {
  const Int8DataType();

  @override
  int get bits => 8;

  @override
  int get min => -128;

  @override
  int get max => 127;

  @override
  bool get isSigned => true;

  @override
  Int8List emptyList(int length) => Int8List(length);

  @override
  Int8List readonlyList(Int8List list) => UnmodifiableInt8ListView(list);
}

class Uint8DataType extends IntegerDataType<Uint8List> {
  const Uint8DataType();

  @override
  int get bits => 8;

  @override
  int get min => 0;

  @override
  int get max => 255;

  @override
  bool get isSigned => false;

  @override
  Uint8List emptyList(int length) => Uint8List(length);

  @override
  Uint8List readonlyList(Uint8List list) => UnmodifiableUint8ListView(list);
}

class Int16DataType extends IntegerDataType<Int16List> {
  const Int16DataType();

  @override
  int get bits => 16;

  @override
  int get min => -32768;

  @override
  int get max => 32767;

  @override
  bool get isSigned => true;

  @override
  Int16List emptyList(int length) => Int16List(length);

  @override
  Int16List readonlyList(Int16List list) => UnmodifiableInt16ListView(list);
}

class Uint16DataType extends IntegerDataType<Uint16List> {
  const Uint16DataType();

  @override
  int get bits => 16;

  @override
  int get min => 0;

  @override
  int get max => 65535;

  @override
  bool get isSigned => false;

  @override
  Uint16List emptyList(int length) => Uint16List(length);

  @override
  Uint16List readonlyList(Uint16List list) => UnmodifiableUint16ListView(list);
}

class Int32DataType extends IntegerDataType<Int32List> {
  const Int32DataType();

  @override
  int get bits => 32;

  @override
  int get min => -2147483648;

  @override
  int get max => 2147483647;

  @override
  bool get isSigned => true;

  @override
  Int32List emptyList(int length) => Int32List(length);

  @override
  Int32List readonlyList(Int32List list) => UnmodifiableInt32ListView(list);
}

class Uint32DataType extends IntegerDataType<Uint32List> {
  const Uint32DataType();

  @override
  int get bits => 32;

  @override
  int get min => 0;

  @override
  int get max => 4294967295;

  @override
  bool get isSigned => false;

  @override
  Uint32List emptyList(int length) => Uint32List(length);

  @override
  Uint32List readonlyList(Uint32List list) => UnmodifiableUint32ListView(list);
}

class Int64DataType extends IntegerDataType<Int64List> {
  const Int64DataType();

  @override
  int get bits => 64;

  @override
  int get min => -4294967296 * 2147483648;

  @override
  int get max => 454279 * 649657 * 31252369;

  @override
  int get safeBits => isJavaScript ? 53 : 63;

  @override
  int get safeMin =>
      isJavaScript ? -4503599627370496 : -4294967296 * 1073741824;

  @override
  int get safeMax =>
      isJavaScript ? 4503599627370495 : 4294967296 * 1073741824 - 1;

  @override
  bool get isSigned => true;

  @override
  Int64List emptyList(int length) => Int64List(length);

  @override
  Int64List readonlyList(Int64List list) => UnmodifiableInt64ListView(list);
}

class Uint64DataType extends IntegerDataType<Uint64List> {
  const Uint64DataType();

  @override
  int get bits => 64;

  @override
  int get min => 0;

  @override
  int get max => 4294967296 * 4294967296 - 1;

  @override
  int get safeBits => isJavaScript ? 53 : 63;

  @override
  int get safeMin => 0;

  @override
  int get safeMax =>
      isJavaScript ? 9007199254740991 : 4294967296 * 2147483648 - 1;

  @override
  bool get isSigned => false;

  @override
  Uint64List emptyList(int length) => Uint64List(length);

  @override
  Uint64List readonlyList(Uint64List list) => UnmodifiableUint64ListView(list);
}

class IntegerField extends Field<int> {
  const IntegerField();

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
  int inv(int a) => 1 ~/ a;

  @override
  int mul(int a, int b) => a * b;

  @override
  int scale(int a, num f) => a * f.round();

  @override
  int div(int a, int b) => a ~/ b;

  @override
  int mod(int a, int b) => a % b;

  @override
  int division(int a, int b) => a ~/ b;

  @override
  int remainder(int a, int b) => a % b;

  @override
  int pow(int base, int exponent) => math.pow(base, exponent).truncate();

  @override
  int modPow(int base, int exponent, int modulus) =>
      base.modPow(exponent, modulus);

  @override
  int modInverse(int base, int modulus) => base.modInverse(modulus);

  @override
  int gcd(int a, int b) => a.gcd(b);
}

class IntegerEquality extends NaturalEquality<int> {
  const IntegerEquality();

  @override
  bool isClose(int a, int b, double epsilon) => (a - b).abs() < epsilon;
}
