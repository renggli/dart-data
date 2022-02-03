import 'dart:collection' show SplayTreeMap;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../polynomial.dart';

/// Sparse keyed polynomial.
class KeyedPolynomial<T> with Polynomial<T> {
  KeyedPolynomial(DataType<T> dataType) : this._(dataType, SplayTreeMap());

  KeyedPolynomial._(this.dataType, this._coefficients);

  final SplayTreeMap<int, T> _coefficients;

  @override
  final DataType<T> dataType;

  @override
  int get degree => _coefficients.isEmpty ? -1 : _coefficients.lastKey()!;

  @override
  Set<Storage> get storage => {this};

  @override
  Polynomial<T> copy() =>
      KeyedPolynomial._(dataType, SplayTreeMap.of(_coefficients));

  @override
  T getUnchecked(int exponent) =>
      _coefficients[exponent] ?? dataType.defaultValue;

  @override
  void setUnchecked(int exponent, T value) {
    if (value == dataType.defaultValue) {
      _coefficients.remove(exponent);
    } else {
      _coefficients[exponent] = value;
    }
  }

  @override
  void forEach(void Function(int exponent, T value) callback) {
    var exponent = _coefficients.lastKey();
    while (exponent != null) {
      final value = _coefficients[exponent];
      if (value != null) {
        callback(exponent, value);
      }
      exponent = _coefficients.lastKeyBefore(exponent);
    }
  }
}
