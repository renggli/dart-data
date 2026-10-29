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
      body = '$absCoeff';
    } else if (exp == 1) {
      body = isOne ? 'x' : '${absCoeff}x';
    } else {
      body = isOne ? 'x^$exp' : '${absCoeff}x^$exp';
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
  if (val is Complex) return val.a.toDouble();
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
