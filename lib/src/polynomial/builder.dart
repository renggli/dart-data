library data.polynomial.builder;

import 'package:data/src/polynomial/format.dart';
import 'package:data/src/polynomial/impl/keyed_polynomial.dart';
import 'package:data/src/polynomial/impl/list_polynomial.dart';
import 'package:data/src/polynomial/impl/standard_polynomial.dart';
import 'package:data/src/polynomial/polynomial.dart';
import 'package:data/type.dart';

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

  /// Builds a new polynomial of the configured format.
  Polynomial<T> call() {
    ArgumentError.checkNotNull(type, 'type');
    switch (format) {
      case Format.standard:
        return StandardPolynomial<T>(type);
      case Format.list:
        return ListPolynomial<T>(type);
      case Format.keyed:
        return KeyedPolynomial<T>(type);
    }
    throw ArgumentError.value(format, 'format');
  }
}
