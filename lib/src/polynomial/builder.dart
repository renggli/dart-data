library data.polynomial.builder;

import 'package:more/collection.dart';

import '../../type.dart';
import '../../vector.dart' show Vector;
import 'format.dart';
import 'impl/keyed_polynomial.dart';
import 'impl/list_polynomial.dart';
import 'impl/standard_polynomial.dart';
import 'polynomial.dart';
import 'view/differentiate_polynomial.dart';
import 'view/generated_polynomial.dart';
import 'view/integrate_polynomial.dart';

/// Builds a polynomial of a custom type.
class Builder<T> {
  /// Constructors a builder with the provided storage [format] and data [type].
  Builder(this.format, this.type);

  /// Returns the storage format of the builder.
  final Format format;

  /// Returns the data type of the builder.
  final DataType<T> type;

  /// Returns a builder for standard polynomials.
  Builder<T> get standard => withFormat(Format.standard);

  /// Returns a builder for list polynomials.
  Builder<T> get list => withFormat(Format.list);

  /// Returns a builder for keyed polynomials.
  Builder<T> get keyed => withFormat(Format.keyed);

  /// Returns a builder with the provided storage [format].
  Builder<T> withFormat(Format format) =>
      this.format == format ? this : Builder<T>(format, type);

  /// Returns a builder with the provided data [type].
  Builder<S> withType<S>(DataType<S> type) =>
      // ignore: unrelated_type_equality_checks
      this.type == type ? this : Builder<S>(format, type);

  /// Builds a new polynomial of the desired degree of exponents.
  Polynomial<T> call([int degree = -1]) {
    if (degree < -1) {
      throw RangeError.value(degree, 'degree');
    }
    ArgumentError.checkNotNull(type, 'type');
    switch (format) {
      case Format.standard:
        return StandardPolynomial<T>(type, degree);
      case Format.list:
        return ListPolynomial<T>(type);
      case Format.keyed:
        return KeyedPolynomial<T>(type);
    }
    throw ArgumentError.value(format, 'format');
  }

  /// Builds a polynomial from calling a [callback] on every exponent.
  Polynomial<T> generate(int degree, T Function(int exponent) callback,
      {bool lazy = false}) {
    final result = GeneratedPolynomial<T>(type, degree, callback);
    return lazy ? result : fromPolynomial(result);
  }

  /// Builds a differentiate from another [polynomial].
  Polynomial<T> differentiate(Polynomial<T> polynomial,
      {int count = 1, bool lazy = false}) {
    RangeError.checkNotNegative(count, 'count');
    final result = IntegerRange(count).fold(
        polynomial, (previous, index) => DifferentiatePolynomial<T>(previous));
    return lazy ? result : fromPolynomial(result);
  }

  /// Builds a integrate from another [polynomial].
  Polynomial<T> integrate(Polynomial<T> polynomial,
      {T constant, int count = 1, bool lazy = false}) {
    RangeError.checkNotNegative(count, 'count');
    final result = IntegerRange(count).fold(polynomial,
        (previous, index) => IntegratePolynomial<T>(previous, constant));
    return lazy ? result : fromPolynomial(result);
  }

  /// Builds a polynomial from another polynomial.
  Polynomial<T> fromPolynomial(Polynomial<T> source) {
    final degree = source.degree;
    final result = this(degree);
    for (var i = degree; i >= 0; i--) {
      result.setUnchecked(i, source.getUnchecked(i));
    }
    return result;
  }

  /// Builds a polynomial from a vector.
  Polynomial<T> fromVector(Vector<T> source) {
    final result = this(source.count - 1);
    for (var i = 0; i < source.count; i++) {
      result.setUnchecked(i, source.getUnchecked(i));
    }
    return result;
  }

  /// Builds a polynomial from a list of roots.
  Polynomial<T> fromRoots(List<T> roots) {
    final result = this(roots.length);
    if (roots.isEmpty) {
      return result;
    }
    result.setUnchecked(0, type.field.neg(roots[0]));
    result.setUnchecked(1, type.field.multiplicativeIdentity);
    final sub = type.field.sub, mul = type.field.mul;
    for (var i = 1; i < roots.length; i++) {
      final root = roots[i];
      for (var j = i + 1; j >= 0; j--) {
        result.setUnchecked(
            j,
            sub(
                j > 0
                    ? result.getUnchecked(j - 1)
                    : type.field.additiveIdentity,
                mul(root, result.getUnchecked(j))));
      }
    }
    return result;
  }

  /// Builds a polynomial from a list of coefficients.
  Polynomial<T> fromCoefficients(List<T> source) {
    final result = this(source.length - 1);
    for (var i = 0; i < source.length; i++) {
      result.setUnchecked(i, source[source.length - i - 1]);
    }
    return result;
  }

  /// Builds a polynomial from a list of values.
  Polynomial<T> fromList(List<T> source) {
    final result = this(source.length - 1);
    for (var i = 0; i < source.length; i++) {
      result.setUnchecked(i, source[i]);
    }
    return result;
  }
}
