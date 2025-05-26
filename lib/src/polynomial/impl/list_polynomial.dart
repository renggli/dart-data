import 'dart:math' show max;

import '../../../type.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../polynomial.dart';

/// Standard polynomial built around a managed list.
class ListPolynomial<T> with Polynomial<T> {
  ListPolynomial(this.dataType, int desiredDegree)
    : _coefficients = dataType.newList(
        max(initialListLength, desiredDegree + 1),
        fillValue: dataType.field.additiveIdentity,
      ),
      _degree = -1;

  // Coefficients in ascending order, where the index matches the exponent.
  List<T> _coefficients;

  // Cached degree, that is the highest non-zero coefficient.
  int _degree;

  @override
  final DataType<T> dataType;

  @override
  int get degree => _degree;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int exponent) => exponent < _coefficients.length
      ? _coefficients[exponent]
      : dataType.defaultValue;

  @override
  void setUnchecked(int exponent, T value) {
    if (value == dataType.defaultValue) {
      if (exponent <= _degree) {
        _coefficients[exponent] = dataType.defaultValue;
        if (exponent == _degree) {
          _updateDegree();
          _shrinkCoefficients();
        }
      }
    } else {
      _growCoefficients(exponent);
      _coefficients[exponent] = value;
      _degree = max(_degree, exponent);
    }
  }

  void _updateDegree() {
    for (var i = _degree - 1; i >= 0; i--) {
      if (_coefficients[i] != dataType.defaultValue) {
        _degree = i;
        return;
      }
    }
    _degree = -1;
  }

  void _shrinkCoefficients() {
    final newLength = max(initialListLength, _degree + 1);
    if (2 * newLength < _coefficients.length) {
      _coefficients = dataType.copyList(_coefficients, length: newLength);
    }
  }

  void _growCoefficients(int exponent) {
    if (exponent >= _coefficients.length) {
      final newLength = max(exponent + 1, 3 * _coefficients.length ~/ 2 + 1);
      _coefficients = dataType.copyList(_coefficients, length: newLength);
    }
  }
}
