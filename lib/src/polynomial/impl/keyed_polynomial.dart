library data.polynomial.impl.keyed;

import 'dart:collection' show SplayTreeMap;

import 'package:data/src/polynomial/polynomial.dart';
import 'package:data/type.dart';

/// Sparse keyed polynomial.
class KeyedPolynomial<T> extends Polynomial<T> {
  final SplayTreeMap<int, T> _coefficients;

  KeyedPolynomial(DataType<T> dataType) : this._(dataType, SplayTreeMap());

  KeyedPolynomial._(this.dataType, this._coefficients);

  @override
  final DataType<T> dataType;

  @override
  int get degree => _coefficients.isEmpty ? -1 : _coefficients.lastKey();

  @override
  Polynomial<T> copy() =>
      KeyedPolynomial._(dataType, SplayTreeMap.of(_coefficients));

  @override
  T getUnchecked(int exponent) => _coefficients[exponent] ?? dataType.nullValue;

  @override
  void setUnchecked(int exponent, T value) {
    if (value == dataType.nullValue) {
      _coefficients.remove(exponent);
    } else {
      _coefficients[exponent] = value;
    }
  }
}
