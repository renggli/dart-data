import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show Fraction, CloseToNumExtension;
import 'package:more/ordering.dart' show Ordering;
import 'package:more/printer.dart'
    show Printer, ScientificNumberPrinter, SignNumberPrinter;

import '../models/equality.dart';
import '../models/field.dart';
import '../type.dart';

abstract class FloatDataType extends DataType<double> {
  const FloatDataType();

  @override
  double get defaultValue => 0.0;

  @override
  List<double> newList(int length, [double? fillValue]) {
    final result = _newList(length);
    if (fillValue != null && fillValue != defaultValue) {
      result.fillRange(0, length, fillValue);
    }
    return result;
  }

  /// Internal helper returning a typed list.
  List<double> _newList(int length);

  @override
  Field<double> get field => const FloatField();

  @override
  Ordering<double> get ordering => Ordering.natural<double>();

  @override
  Equality<double> get equality => const FloatEquality();

  @override
  double cast(dynamic value) {
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
  List<double> _newList(int length) => Float32List(length);

  @override
  Printer<double> get printer => ScientificNumberPrinter<double>(
        exponentPadding: 3,
        exponentSign: const SignNumberPrinter<int>.negativeAndPositiveSign(),
      );
}

class Float64DataType extends FloatDataType {
  const Float64DataType();

  @override
  String get name => 'float64';

  @override
  List<double> _newList(int length) => Float64List(length);

  @override
  Printer<double> get printer => ScientificNumberPrinter<double>(
        exponentPadding: 3,
        exponentSign: const SignNumberPrinter<int>.negativeAndPositiveSign(),
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
  double division(double a, double b) => (a ~/ b).roundToDouble();

  @override
  double remainder(double a, double b) => a.remainder(b);

  @override
  double pow(double base, double exponent) =>
      math.pow(base, exponent).toDouble();

  @override
  double modPow(double base, double exponent, double modulus) =>
      mod(pow(base, exponent), modulus);

  @override
  double modInverse(double base, double modulus) =>
      unsupportedOperation('modInverse');

  @override
  double gcd(double a, double b) => unsupportedOperation('gcd');
}

class FloatEquality extends NaturalEquality<double> {
  const FloatEquality();

  @override
  bool isClose(double a, double b, double epsilon) => a.closeTo(b, epsilon);
}
