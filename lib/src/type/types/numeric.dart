import 'dart:math' as math;

import 'package:more/number.dart' show CloseToNumExtension, Fraction;

import '../data_type.dart';
import '../models/equality.dart';
import '../models/field.dart';

/// Data type descriptor for generic numeric values ([num]).
final class NumericDataType extends DataType<num> {
  /// Creates a new [NumericDataType] instance.
  const new();

  @override
  String get name => 'numeric';

  @override
  num get defaultValue => 0;

  @override
  bool get isNumeric => true;

  @override
  Equality<num> get equality => const NumericEquality();

  @override
  Field<num> get field => const NumericField();

  @override
  int comparator(num a, num b) => a.compareTo(b);

  @override
  num cast(Object? value) {
    if (value is num) {
      return value;
    } else if (value is BigInt) {
      return value.toInt();
    } else if (value is Fraction) {
      return value.toDouble();
    } else if (value is String) {
      return num.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }
}

/// Algebraic field operations over generic numeric values ([num]).
final class NumericField implements ExtendedField<num> {
  /// Creates a new [NumericField] instance.
  const new();

  @override
  num get additiveIdentity => 0;

  @override
  num neg(num a) => -a;

  @override
  num add(num a, num b) => a + b;

  @override
  num sub(num a, num b) => a - b;

  @override
  num get multiplicativeIdentity => 1;

  @override
  num inv(num a) => 1 / a;

  @override
  num mul(num a, num b) => a * b;

  @override
  num scale(num a, num factor) => a * factor;

  @override
  num div(num a, num b) => a / b;

  @override
  num mod(num a, num b) => a % b;

  @override
  num division(num a, num b) => a ~/ b;

  @override
  num remainder(num a, num b) => a.remainder(b);

  @override
  num pow(num base, num exponent) => math.pow(base, exponent);

  @override
  num modPow(num base, num exponent, num modulus) =>
      mod(pow(base, exponent), modulus);

  @override
  num modInverse(num base, num modulus) => unsupportedOperation('modInverse');

  @override
  num gcd(num a, num b) => unsupportedOperation('gcd');

  @override
  num abs(num a) => a.abs();

  @override
  double norm(num a) => a.abs().toDouble();

  @override
  num sqrt(num a) => math.sqrt(a);

  @override
  num exp(num a) => math.exp(a);

  @override
  num log(num a) => math.log(a);

  @override
  num conjugate(num a) => a;

  @override
  num get nan => double.nan;

  @override
  num get infinity => double.infinity;

  @override
  num get negativeInfinity => double.negativeInfinity;
}

/// Equality relation for [num] values with proximity testing.
final class NumericEquality extends NaturalEquality<num> {
  /// Creates a new [NumericEquality] instance.
  const new();

  @override
  bool isClose(num a, num b, double epsilon) => a.closeTo(b, epsilon);
}
