import '../../../type.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../polynomial.dart';

/// Sparse compressed polynomial.
class CompressedPolynomial<T> with Polynomial<T> {
  CompressedPolynomial(this.dataType)
      : _exponents = DataType.indexDataType.newList(initialListLength),
        _coefficients = dataType.newList(initialListLength,
            fillValue: dataType.field.additiveIdentity),
        _length = 0;

  List<int> _exponents;
  List<T> _coefficients;
  int _length;

  @override
  final DataType<T> dataType;

  @override
  int get degree => _length > 0 ? _exponents[_length - 1] : -1;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int exponent) {
    final pos = binarySearch<num>(_exponents, 0, _length, exponent);
    return pos < 0 ? dataType.defaultValue : _coefficients[pos];
  }

  @override
  void setUnchecked(int exponent, T value) {
    final pos = binarySearch<num>(_exponents, 0, _length, exponent);
    if (pos < 0) {
      if (value != dataType.defaultValue) {
        _exponents = insertAt(
            DataType.indexDataType, _exponents, _length, -pos - 1, exponent);
        _coefficients = insertAt(
            dataType, _coefficients, _length, -pos - 1, value,
            fillValue: dataType.defaultValue);
        _length++;
      }
    } else {
      if (value == dataType.defaultValue) {
        _exponents = removeAt(DataType.indexDataType, _exponents, _length, pos);
        _coefficients = removeAt(dataType, _coefficients, _length, pos,
            fillValue: dataType.defaultValue);
        _length--;
      } else {
        _coefficients[pos] = value;
      }
    }
  }

  @override
  void forEach(void Function(int exponent, T value) callback) {
    for (var i = _length - 1; i >= 0; i--) {
      callback(_exponents[i], _coefficients[i]);
    }
  }
}
