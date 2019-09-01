library data.polynomial.impl.standard;

import 'dart:math' show max;

import 'package:data/src/polynomial/polynomial.dart';
import 'package:data/src/shared/lists.dart';
import 'package:data/type.dart';

/// Standard polynomial.
class StandardPolynomial<T> extends Polynomial<T> {
  // Coefficients in ascending order, where the index matches the exponent.
  List<T> _coefficients;

  StandardPolynomial(DataType<T> dataType, [int degree = -1])
      : this._(
            dataType,
            dataType.newListFilled(max(initialListSize, degree + 1),
                dataType.field.additiveIdentity));

  StandardPolynomial._(this.dataType, this._coefficients);

  @override
  final DataType<T> dataType;

  @override
  int get degree {
    for (var i = _coefficients.length - 1; i >= 0; i--) {
      if (!isZeroCoefficient(_coefficients[i])) {
        return i;
      }
    }
    return -1;
  }

  @override
  Polynomial<T> copy() => StandardPolynomial._(
      dataType,
      dataType.copyList(_coefficients,
          length: degree + 1, fillValue: zeroCoefficient));

  @override
  T getUnchecked(int exponent) => exponent < _coefficients.length
      ? _coefficients[exponent]
      : zeroCoefficient;

  @override
  void setUnchecked(int exponent, T value) {
    if (isZeroCoefficient(value)) {
      if (exponent < _coefficients.length) {
        _coefficients[exponent] = zeroCoefficient;
      }
    } else {
      if (exponent >= _coefficients.length) {
        final newLength = max(exponent + 1, 3 * _coefficients.length ~/ 2 + 1);
        _coefficients = dataType.copyList(_coefficients,
            length: newLength, fillValue: zeroCoefficient);
      }
      _coefficients[exponent] = value;
    }
  }
}
