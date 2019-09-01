library data.polynomial.impl.list;

import 'package:data/src/polynomial/polynomial.dart';
import 'package:data/src/shared/config.dart';
import 'package:data/src/shared/lists.dart';
import 'package:data/type.dart';

/// Sparse compressed polynomial.
class ListPolynomial<T> extends Polynomial<T> {
  List<int> _exponents;
  List<T> _coefficients;
  int _length;

  ListPolynomial(DataType<T> dataType)
      : this._(dataType, indexDataType.newList(initialListSize),
            dataType.newList(initialListSize), 0);

  ListPolynomial._(
      this.dataType, this._exponents, this._coefficients, this._length);

  @override
  final DataType<T> dataType;

  @override
  int get degree => _length > 0 ? _exponents[_length - 1] : -1;

  @override
  Polynomial<T> copy() => ListPolynomial._(
      dataType,
      indexDataType.copyList(_exponents),
      dataType.copyList(_coefficients),
      _length);

  @override
  T getUnchecked(int exponent) {
    final pos = binarySearch(_exponents, 0, _length, exponent);
    return pos < 0 ? zeroCoefficient : _coefficients[pos];
  }

  @override
  void setUnchecked(int exponent, T value) {
    final pos = binarySearch(_exponents, 0, _length, exponent);
    if (pos < 0) {
      if (!isZeroCoefficient(value)) {
        _exponents =
            insertAt(indexDataType, _exponents, _length, -pos - 1, exponent);
        _coefficients =
            insertAt(dataType, _coefficients, _length, -pos - 1, value);
        _length++;
      }
    } else {
      if (isZeroCoefficient(value)) {
        _exponents = removeAt(indexDataType, _exponents, _length, pos);
        _coefficients = removeAt(dataType, _coefficients, _length, pos);
        _length--;
      } else {
        _coefficients[pos] = value;
      }
    }
  }
}
