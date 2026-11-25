import 'package:more/number.dart' show Complex, Fraction;

import '../../type/data_type.dart';

/// Validates that [left] and [right] have identical [DataType]s.
void checkSamePolynomialType<T>(DataType<T> left, DataType<T> right) {
  if (left != right) {
    throw ArgumentError(
      'Polynomials must have the same DataType: $left != $right.',
    );
  }
}

/// Returns `true` when [type] is an IEEE-754 floating-point type (`float32` or
/// `float64`).
///
/// Checking [DataType] identity rather than `defaultValue is double` is
/// required for consistent behavior on JavaScript targets where integer and
/// double runtime types overlap.
bool isFloatPolynomialType(DataType<Object?> type) =>
    type == DataType.float32 || type == DataType.float64;

/// Canonicalizes a coefficient [value] against [zero] so that negative zeros
/// (`-0.0` or `Complex(-0.0, -0.0)`) are normalized to positive zero.
T normalizeCoefficient<T>(T value, T zero) {
  if (value == zero) return zero;
  if (value is Complex && (value.a == 0.0 || value.b == 0.0)) {
    return Complex(
      value.a == 0.0 ? 0.0 : value.a,
      value.b == 0.0 ? 0.0 : value.b,
    ) as T;
  }
  return value;
}

/// Formats polynomial [terms] in descending degree order into a readable
/// algebraic string.
String formatPolynomialTerms<T>(
  DataType<T> type,
  Iterable<({int exponent, T coefficient})> terms,
) {
  final termList = terms.toList(growable: false);
  if (termList.isEmpty) return '0';

  final buffer = StringBuffer();
  for (var i = 0; i < termList.length; i++) {
    final term = termList[i];
    final exp = term.exponent;
    final coeff = term.coefficient;

    final isNegative = _isNegativeCoefficient(type, coeff);
    final absCoeff = isNegative ? type.field.neg(coeff) : coeff;
    final isOne = absCoeff == type.field.multiplicativeIdentity;

    final String body;
    if (exp == 0) {
      body = _formatCoefficient(absCoeff);
    } else {
      final coeffStr = _formatCoefficient(absCoeff);
      final isMultiTerm = _isMultiTerm(coeffStr);
      final formattedCoeff = isMultiTerm ? '($coeffStr)' : coeffStr;
      if (exp == 1) {
        body = isOne ? 'x' : '${formattedCoeff}x';
      } else {
        body = isOne ? 'x^$exp' : '${formattedCoeff}x^$exp';
      }
    }

    if (i == 0) {
      if (isNegative) buffer.write('-');
      buffer.write(body);
    } else {
      buffer.write(isNegative ? ' - ' : ' + ');
      buffer.write(body);
    }
  }
  return buffer.toString();
}

/// Converts a numeric coefficient [val] to [double].
///
/// Throws an [UnsupportedError] for non-real complex numbers or non-numeric
/// coefficients.
double coeffToDouble(Object? val) {
  if (val is num) return val.toDouble();
  if (val is BigInt) return val.toDouble();
  if (val is Fraction) return val.toDouble();
  if (val is Complex) {
    if (val.b != 0.0) {
      throw UnsupportedError(
        'Cannot convert complex number with non-zero imaginary part ($val) to double.',
      );
    }
    return val.a.toDouble();
  }
  throw UnsupportedError('Cannot convert coefficient $val to double.');
}

/// Converts a numeric or complex coefficient [val] to [Complex].
///
/// Throws an [UnsupportedError] for non-numeric coefficients.
Complex coeffToComplex(Object? val) {
  if (val is Complex) return val;
  if (val is num) return Complex(val.toDouble());
  if (val is BigInt) return Complex(val.toDouble());
  if (val is Fraction) return Complex(val.toDouble());
  throw UnsupportedError('Cannot convert coefficient $val to Complex.');
}

String _formatCoefficient(Object? coeff) {
  if (coeff is Complex) {
    final a = coeff.a == 0.0 ? 0.0 : coeff.a;
    final b = coeff.b == 0.0 ? 0.0 : coeff.b;
    if (b == 0.0) {
      return '$a';
    } else if (a == 0.0) {
      return '${b}i';
    } else if (b < 0.0) {
      return '$a - ${-b}i';
    } else {
      return '$a + ${b}i';
    }
  }
  return '$coeff';
}

bool _isMultiTerm(String s) {
  if (s.isEmpty) return false;
  if (s.startsWith('(') && s.endsWith(')')) return false;
  for (var i = 1; i < s.length; i++) {
    final char = s[i];
    if (char == '+' || char == '-') {
      final prev = s[i - 1];
      if (prev != 'e' && prev != 'E') {
        return true;
      }
    }
  }
  return false;
}

bool _isNegativeCoefficient<T>(DataType<T> type, T value) {
  if (value is num) return value < 0;
  if (value is BigInt) return value.isNegative;
  if (value is Fraction) return value < Fraction.zero;
  if (value is Complex) {
    return (value.b == 0.0 && value.a < 0.0) ||
        (value.a == 0.0 && value.b < 0.0);
  }
  if (value is Comparable) {
    return type.comparator(value, type.field.additiveIdentity) < 0;
  }
  return false;
}
