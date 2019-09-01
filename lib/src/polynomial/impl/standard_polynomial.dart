library data.polynomial.impl.standard;

import 'dart:math' show max;

import 'package:data/src/polynomial/polynomial.dart';
import 'package:data/src/shared/lists.dart';
import 'package:data/type.dart';

/// Standard polynomial.
class StandardPolynomial<T> extends Polynomial<T> {
  // Coefficients in ascending order, where the index matches the exponent.
  List<T> _coefficients;

  // Cached degree, that is the highest non-zero coefficient.
  int _degree;

  StandardPolynomial(DataType<T> dataType, [int desiredDegree = -1])
      : this._(
            dataType,
            dataType.newListFilled(max(initialListLength, desiredDegree + 1),
                dataType.field.additiveIdentity),
            -1);

  StandardPolynomial._(this.dataType, this._coefficients, this._degree);

  @override
  final DataType<T> dataType;

  @override
  int get degree => _degree;

  @override
  Polynomial<T> copy() => StandardPolynomial._(
      dataType,
      dataType.copyList(_coefficients,
          length: degree + 1, fillValue: zeroCoefficient),
      _degree);

  @override
  T getUnchecked(int exponent) => exponent < _coefficients.length
      ? _coefficients[exponent]
      : zeroCoefficient;

  @override
  void setUnchecked(int exponent, T value) {
    if (isZeroCoefficient(value)) {
      if (exponent <= _degree) {
        _coefficients[exponent] = zeroCoefficient;
        if (exponent == _degree) {
          for (var i = _degree - 1; i >= 0; i--) {
            if (_coefficients[i] != zeroCoefficient) {
              _degree = i;
              return;
            }
          }
          _degree = -1;
        }
      }
    } else {
      if (exponent >= _coefficients.length) {
        final newLength = max(exponent + 1, 3 * _coefficients.length ~/ 2 + 1);
        _coefficients = dataType.copyList(_coefficients,
            length: newLength, fillValue: zeroCoefficient);
      }
      _coefficients[exponent] = value;
      _degree = max(_degree, exponent);
    }
  }
}
