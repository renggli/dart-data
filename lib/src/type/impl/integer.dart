import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/feature.dart' show isJavaScript;
import 'package:more/number.dart' show Fraction;
import 'package:more/printer.dart' show Printer, FixedNumberPrinter;

import '../models/equality.dart';
import '../models/field.dart';
import '../type.dart';

abstract class IntegerDataType extends DataType<int> {
  const IntegerDataType();

  /// Returns the size in bits of this integer.
  int get bits;

  /// Returns the true, if this integer is signed.
  bool get isSigned;

  /// Returns the minimum value of this integer.
  int get min;

  /// Returns the maximum value of this integer.
  int get max;

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
  List<int> newList(int length, {int? fillValue}) {
    final result = _newList(length);
    if (fillValue != null && fillValue != defaultValue) {
      result.fillRange(0, length, fillValue);
    }
    return result;
  }

  /// Internal helper returning a typed list.
  List<int> _newList(int length);

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

class Int8DataType extends IntegerDataType {
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
  List<int> _newList(int length) => Int8List(length);
}

class Uint8DataType extends IntegerDataType {
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
  List<int> _newList(int length) => Uint8List(length);
}

class Int16DataType extends IntegerDataType {
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
  List<int> _newList(int length) => Int16List(length);
}

class Uint16DataType extends IntegerDataType {
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
  List<int> _newList(int length) => Uint16List(length);
}

class Int32DataType extends IntegerDataType {
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
  List<int> _newList(int length) => Int32List(length);
}

class Uint32DataType extends IntegerDataType {
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
  List<int> _newList(int length) => Uint32List(length);
}

class Int64DataType extends IntegerDataType {
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
  List<int> _newList(int length) => Int64List(length);
}

class Uint64DataType extends IntegerDataType {
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
  List<int> _newList(int length) => Uint64List(length);
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
