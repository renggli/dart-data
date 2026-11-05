import 'package:more/number.dart' show Complex, Fraction;

import '../../type/data_type.dart';

/// Formats polynomial terms in descending degree order into a mathematical string.
String formatPolynomialTerms<T>(
  DataType<T> type,
  Iterable<({int exponent, T coefficient})> terms,
) {
  final termList = terms.toList();
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

/// Converts a coefficient value [val] to [double].
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

/// Converts a coefficient value [val] to [Complex].
Complex coeffToComplex(Object? val) {
  if (val is Complex) return val;
  if (val is num) return Complex(val.toDouble());
  if (val is BigInt) return Complex(val.toDouble());
  if (val is Fraction) return Complex(val.toDouble());
  throw UnsupportedError('Cannot convert coefficient $val to Complex.');
}

String _formatCoefficient(Object? coeff) {
  if (coeff is Complex) {
    if (coeff.b == 0.0) {
      return '${coeff.a}';
    } else if (coeff.a == 0.0) {
      return '${coeff.b}i';
    } else if (coeff.b < 0) {
      return '${coeff.a} - ${-coeff.b}i';
    } else {
      return '${coeff.a} + ${coeff.b}i';
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
  try {
    return type.comparator(value, type.field.additiveIdentity) < 0;
  } on UnsupportedError {
    return false;
  } on ArgumentError {
    return false;
  } on TypeError {
    return false;
  }
}
