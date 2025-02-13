import 'dart:math' as math;
import 'dart:typed_data';

import 'package:more/number.dart' show CloseToNumExtension, Fraction;
import 'package:more/printer.dart'
    show Printer, ScientificNumberPrinter, SignNumberPrinter;

import '../models/equality.dart';
import '../models/field.dart';
import 'typed.dart';

abstract class FloatDataType<L extends List<double>>
    extends TypedDataType<double, L> {
  const FloatDataType();

  /// Returns the smallest positive value larger than zero.
  double get minPositive;

  /// Returns the machine epsilon, that is the difference between 1 and the
  /// next larger floating point number.
  double get epsilon;

  @override
  double get defaultValue => 0.0;

  @override
  String get name => 'float$bits';

  @override
  int comparator(double a, double b) => a.compareTo(b);

  @override
  Field<double> get field => const FloatField();

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

class Float32DataType extends FloatDataType<Float32List> {
  const Float32DataType();

  @override
  int get bits => 32;

  @override
  double get min => -3.4028234663852886e+38;

  @override
  double get minPositive => 1.401298464324817e-45;

  @override
  double get max => 3.4028234663852886e+38;

  @override
  double get epsilon => 1.1920928955078125e-7;

  @override
  Float32List emptyList(int length) => Float32List(length);

  @override
  Float32List readonlyList(Float32List list) => list.asUnmodifiableView();

  @override
  Printer<double> get printer => ScientificNumberPrinter<double>(
    exponentPadding: 3,
    exponentSign: const SignNumberPrinter<int>.negativeAndPositiveSign(),
  );
}

class Float64DataType extends FloatDataType<Float64List> {
  const Float64DataType();

  @override
  int get bits => 64;

  @override
  double get min => -1.79769313486231570815e+308;

  @override
  double get minPositive => 4.94065645841246544177e-324;

  @override
  double get max => 1.79769313486231570815e+308;

  @override
  double get epsilon => 2.22044604925031308085e-16;

  @override
  Float64List emptyList(int length) => Float64List(length);

  @override
  Float64List readonlyList(Float64List list) => list.asUnmodifiableView();

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
