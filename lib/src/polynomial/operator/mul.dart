import '../../../type.dart';
import '../../numeric/fft.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';
import 'utils.dart';

extension MulPolynomialExtension<T> on Polynomial<T> {
  /// Multiplies this [Polynomial] with [other].
  Polynomial<T> mul(
    /* Polynomial<T>|T */ Object other, {
    DataType<T>? dataType,
    PolynomialFormat? format,
    bool? fftMultiply,
  }) {
    if (other is Polynomial<T>) {
      return mulPolynomial(other,
          dataType: dataType, format: format, fftMultiply: fftMultiply);
    } else if (other is T) {
      return mulScalar(other as T, dataType: dataType, format: format);
    } else {
      throw ArgumentError.value(other, 'other', 'Invalid multiplication.');
    }
  }

  /// Multiplies this [Polynomial] with [other].
  Polynomial<T> operator *(/* Polynomial<T>|T */ Object other) => mul(other);

  /// Multiplies this [Polynomial] with a [Polynomial].
  Polynomial<T> mulPolynomial(
    Polynomial<T> other, {
    DataType<T>? dataType,
    PolynomialFormat? format,
    bool? fftMultiply,
  }) {
    if (degree < 0 || other.degree < 0) {
      // One of the polynomials has zero coefficients.
      return createPolynomial<T>(this, 0, dataType, format);
    }
    final result =
        createPolynomial<T>(this, degree + other.degree, dataType, format);
    final add = result.dataType.field.add, mul = result.dataType.field.mul;
    if (degree == 0) {
      // First polynomial is constant.
      final factor = getUnchecked(0);
      for (var i = other.degree; i >= 0; i--) {
        result.setUnchecked(i, mul(factor, other.getUnchecked(i)));
      }
    } else if (other.degree == 0) {
      // Second polynomial is constant.
      final factor = other.getUnchecked(0);
      for (var i = degree; i >= 0; i--) {
        result.setUnchecked(i, mul(getUnchecked(i), factor));
      }
    } else if (fftMultiply == true ||
        (fftMultiply != false && degree * other.degree > 1600)) {
      // Perform fourier multiplication when this is a large polynomial, or
      // when the user desires to use it. Experimentally FFT multiplication
      // starts to become more performant if the multiplied degrees exceed 1600.
      _fftMulPolynomial(result, this, other);
    } else {
      // Churn through full multiplication.
      for (var a = degree; a >= 0; a--) {
        for (var b = other.degree; b >= 0; b--) {
          result.setUnchecked(
              a + b,
              add(result.getUnchecked(a + b),
                  mul(getUnchecked(a), other.getUnchecked(b))));
        }
      }
    }
    return result;
  }

  /// Multiplies this [Polynomial] with a scalar.
  Polynomial<T> mulScalar(T other,
      {DataType<T>? dataType, PolynomialFormat? format}) {
    final result = createPolynomial<T>(this, degree, dataType, format);
    final mul = result.dataType.field.mul;
    unaryOperator<T>(result, this, (a) => mul(a, other));
    return result;
  }

  /// In-place multiplies this [Polynomial] with a scalar.
  Polynomial<T> mulScalarEq(T other) {
    final mul = dataType.field.mul;
    unaryOperator<T>(this, this, (a) => mul(a, other));
    return this;
  }
}

/// Helper to perform polynomial multiplication using fast fourier transform.
void _fftMulPolynomial<T>(
    Polynomial<T> result, Polynomial<T> a, Polynomial<T> b) {
  final va = a.iterable.map(DataType.complex.cast).toList();
  final vb = b.iterable.map(DataType.complex.cast).toList();
  var n = 1;
  while (n < va.length + vb.length) {
    n <<= 1;
  }
  while (va.length < n) {
    va.add(Complex.zero);
  }
  while (vb.length < n) {
    vb.add(Complex.zero);
  }
  fft(va, inverse: false);
  fft(vb, inverse: false);
  for (var i = 0; i < n; i++) {
    va[i] *= vb[i];
  }
  fft(va, inverse: true);
  final cast = result.dataType is DataType<int>
      ? (Complex c) => c.real.round() as T
      : result.dataType is DataType<num>
          ? (Complex c) => c.real as T
          : result.dataType.cast;
  for (var i = a.degree + b.degree; i >= 0; i--) {
    result.setUnchecked(i, cast(va[i]));
  }
}
