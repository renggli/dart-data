import 'dart:math' as math;

import 'package:more/number.dart';

import '../data_type.dart';
import '../models/equality.dart';
import '../models/field.dart';

/// Data type descriptor for rational fractions ([Fraction]).
final class FractionDataType extends DataType<Fraction> {
  /// Creates a new [FractionDataType] instance.
  const new();

  @override
  String get name => 'fraction';

  @override
  Fraction get defaultValue => Fraction.zero;

  @override
  int comparator(Fraction a, Fraction b) => a.compareTo(b);

  @override
  Fraction cast(Object? value) {
    if (value is Fraction) {
      return value;
    } else if (value is num) {
      if (!value.isFinite) return super.cast(value);
      return value is int
          ? Fraction(value)
          : Fraction.fromDouble(value.toDouble());
    } else if (value is BigInt) {
      if (value.isValidInt) {
        return Fraction(value.toInt());
      }
      return super.cast(value);
    } else if (value is String) {
      return Fraction.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }

  @override
  Equality<Fraction> get equality => const FractionEquality();

  @override
  Field<Fraction> get field => const FractionField();
}

/// Equality relation for [Fraction] numbers with proximity testing.
final class FractionEquality extends NaturalEquality<Fraction> {
  /// Creates a new [FractionEquality] instance.
  const new();

  @override
  bool isClose(Fraction a, Fraction b, double epsilon) =>
      !epsilon.isNaN && epsilon >= 0 && a.closeTo(b, epsilon);
}

/// Algebraic field operations over [Fraction] numbers.
final class FractionField extends ExtendedField<Fraction> {
  /// Creates a new [FractionField] instance.
  const new();

  @override
  Fraction get additiveIdentity => Fraction.zero;

  @override
  Fraction neg(Fraction a) => -a;

  @override
  Fraction add(Fraction a, Fraction b) => a + b;

  @override
  Fraction sub(Fraction a, Fraction b) => a - b;

  @override
  Fraction get multiplicativeIdentity => Fraction.one;

  @override
  Fraction inv(Fraction a) => a.reciprocal();

  @override
  Fraction mul(Fraction a, Fraction b) => a * b;

  @override
  Fraction scale(Fraction a, num factor) {
    if (!factor.isFinite) {
      throw ArgumentError.value(factor, 'factor', 'Must be finite');
    }
    if (factor is int) return a * factor;
    return a * Fraction.fromDouble(factor.toDouble());
  }

  @override
  Fraction div(Fraction a, Fraction b) => a / b;

  @override
  Fraction pow(Fraction base, Fraction exponent) {
    if (exponent.denominator == 1) {
      if (base == Fraction.zero && exponent.numerator < 0) {
        throw ArgumentError.value(exponent, 'exponent', 'Division by zero');
      }
      return base.pow(exponent.numerator);
    }
    final result = math.pow(base.toDouble(), exponent.toDouble()).toDouble();
    if (!result.isFinite) {
      throw ArgumentError.value(base, 'base', 'Non-finite power result');
    }
    return Fraction.fromDouble(result);
  }

  @override
  Fraction abs(Fraction a) => a.abs();

  @override
  double norm(Fraction a) => a.abs().toDouble();

  @override
  Fraction sqrt(Fraction a) {
    if (a.isNegative) throw ArgumentError.value(a, 'a', 'Negative value');
    if (!a.isFinite) throw ArgumentError.value(a, 'a', 'Non-finite value');
    return Fraction.fromDouble(math.sqrt(a.toDouble()));
  }

  @override
  Fraction exp(Fraction a) {
    final result = math.exp(a.toDouble());
    if (!result.isFinite) {
      throw ArgumentError.value(a, 'a', 'Exponential overflow');
    }
    return Fraction.fromDouble(result);
  }

  @override
  Fraction log(Fraction a) {
    if (a <= Fraction.zero || !a.isFinite) {
      throw ArgumentError.value(a, 'a', 'Non-positive or non-finite value');
    }
    return Fraction.fromDouble(math.log(a.toDouble()));
  }
}
