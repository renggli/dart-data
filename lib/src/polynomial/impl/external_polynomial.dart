import '../../../type.dart';
import '../../shared/storage.dart';
import '../polynomial.dart';

/// Polynomial built around an (externally managed) list of coefficients.
class ExternalPolynomial<T> with Polynomial<T> {
  ExternalPolynomial(DataType<T> dataType, int desiredDegree)
    : this.fromList(dataType, dataType.newList(desiredDegree + 1));

  ExternalPolynomial.fromList(this.dataType, this.coefficients);

  @override
  final DataType<T> dataType;

  /// Coefficients in ascending order, where the index matches the exponent.
  final List<T> coefficients;

  @override
  int get degree {
    // List might change externally, need to recompute the degree.
    for (var i = coefficients.length - 1; i >= 0; i--) {
      if (coefficients[i] != dataType.defaultValue) {
        return i;
      }
    }
    return -1;
  }

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int exponent) => exponent < coefficients.length
      ? coefficients[exponent]
      : dataType.defaultValue;

  @override
  void setUnchecked(int exponent, T value) {
    while (exponent >= coefficients.length) {
      coefficients.add(dataType.defaultValue);
    }
    coefficients[exponent] = value;
  }
}
