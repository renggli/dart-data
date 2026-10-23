import '../../../type.dart';

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
