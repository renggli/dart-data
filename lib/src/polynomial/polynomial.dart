library data.polynomial.polynomial;

import 'dart:collection' show ListMixin;

import 'package:data/src/polynomial/builder.dart';
import 'package:data/src/polynomial/format.dart';
import 'package:data/tensor.dart' show Tensor;
import 'package:data/type.dart' show DataType;
import 'package:more/printer.dart' show Printer;

/// Abstract polynomial type.
abstract class Polynomial<T> extends Tensor<T> {
  /// Default builder for new polynomials.
  static Builder<Object> get builder =>
      Builder<Object>(Format.standard, DataType.object);

  /// Unnamed default constructor.
  Polynomial();

  /// Returns the shape of this polynomial.
  @override
  List<int> get shape => [degree];

  /// Returns a copy of this polynomial.
  @override
  Polynomial<T> copy();

  /// The degree this polynomial.
  int get degree;

  /// Returns the scalar at the provided [index].
  @override
  T operator [](int index) {
    RangeError.checkNotNegative(index, 'index');
    return getUnchecked(index);
  }

  /// Returns the scalar at the provided [index]. The behavior is undefined if
  /// [index] is outside of bounds.
  T getUnchecked(int index);

  /// Sets the scalar at the provided [index] to [value].
  void operator []=(int index, T value) {
    RangeError.checkNotNegative(index, 'index');
    setUnchecked(index, value);
  }

  /// Sets the scalar at the provided [index] to [value]. The behavior is
  /// undefined if [index] is outside of bounds.
  void setUnchecked(int index, T value);

  /// Returns a list iterable over the polynomial.
  List<T> get iterable => _PolynomialList<T>(this);

  /// Returns a human readable representation of the polynomial.
  @override
  String format({
    bool limit = true,
    int leadingItems = 3,
    int trailingItems = 3,
    Printer ellipsesPrinter,
    Printer paddingPrinter,
    Printer valuePrinter, // additional options
    String ellipses = '\u2026',
    String separator = ' + ',
    bool reversed = true,
    String variable = 'x',
  }) {
    final count = degree;
    final buffer = StringBuffer();
    valuePrinter ??= dataType.printer;
    paddingPrinter ??= Printer.standard();
    ellipsesPrinter ??= Printer.standard();

    String coefficient(int exponent, T value) {
      final buffer = StringBuffer();
      buffer.write(valuePrinter(value));
      if (variable != null && exponent > 0) {
        buffer.write(variable);
        if (exponent > 1) {
          buffer.write('^');
          buffer.write(exponent);
        }
      }
      return buffer.toString();
    }

    if (count < 0) {
      buffer.write(coefficient(0, dataType.nullValue));
    }

    // TODO: Only print non-null values.
    if (reversed) {
      for (var i = count; i >= 0; i--) {
        if (i < count) {
          buffer.write(separator);
        }
        if (limit && leadingItems <= i && i < count - trailingItems) {
          buffer.write(paddingPrinter(ellipsesPrinter(ellipses)));
          i = count - trailingItems - 1;
        } else {
          buffer.write(coefficient(i, getUnchecked(i)));
        }
      }
    } else {
      for (var i = 0; i < count; i++) {
        if (i > 0) {
          buffer.write(separator);
        }
        if (limit && leadingItems <= i && i < count - trailingItems) {
          buffer.write(paddingPrinter(ellipsesPrinter(ellipses)));
          i = count - trailingItems - 1;
        } else {
          buffer.write(coefficient(i, getUnchecked(i)));
        }
      }
    }
    return buffer.toString();
  }
}

class _PolynomialList<T> extends ListMixin<T> {
  final Polynomial<T> polynomial;

  _PolynomialList(this.polynomial) : length = polynomial.degree;

  @override
  final int length;

  @override
  set length(int newLength) =>
      throw UnsupportedError('Unable to change length of polynomial.');

  @override
  T operator [](int index) => polynomial[index];

  @override
  void operator []=(int index, T value) => polynomial[index] = value;
}
